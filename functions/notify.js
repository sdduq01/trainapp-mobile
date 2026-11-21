/**
 * Notificaciones push (FCM).
 *
 * Tokens: `push_tokens/{uid}/tokens/{token}` (los registra la app).
 * Preferencias: `profiles/{uid}.notificationPrefs[category] === false` apaga
 * una categoría. Las categorías coinciden con `NotifCategory` de la app
 * (`lib/notifications/notification_prefs.dart`) y con sus canales de Android.
 *
 * Cada `on*` recibe el antes/después del documento y decide a quién avisar;
 * `index.js` solo los conecta a los triggers. `send` se puede reemplazar en
 * pruebas.
 */

const { Timestamp, FieldValue } = require('firebase-admin/firestore');
const logger = require('firebase-functions/logger');

const CATEGORY = {
  classes: 'classes',
  gymNews: 'gym_news',
  invites: 'invites',
  trainer: 'trainer',
  premium: 'premium',
};

const ROUTE = { home: 'home', profile: 'profile', gymClasses: 'gym_classes' };

const ROUTINE_EDIT_THROTTLE_MS = 3 * 3600 * 1000;
const INVALID_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

// ── Envío ────────────────────────────────────────────────────────────────

/**
 * Manda un push a todos los dispositivos de [uid]. Con `silent` va solo con
 * datos (la app lo procesa sin mostrar nada) y no mira las preferencias.
 * Nunca lanza: un aviso que falla no debe romper el trigger.
 */
async function sendToUser(db, messaging, uid, msg) {
  try {
    const { category, title, body, route = ROUTE.home, tag, data = {}, silent = false } = msg;
    if (!silent) {
      const profile = await db.doc(`profiles/${uid}`).get();
      const prefs = profile.exists ? profile.data().notificationPrefs : null;
      if (prefs && prefs[category] === false) return { uid, sent: 0, reason: 'prefs' };
    }
    const tokensSnap = await db.collection(`push_tokens/${uid}/tokens`).get();
    if (tokensSnap.empty) return { uid, sent: 0, reason: 'no_tokens' };
    const tokens = tokensSnap.docs.map(d => d.id);

    const payload = {
      tokens,
      data: Object.fromEntries(Object.entries({ ...data, category, route, ...(tag ? { tag } : {}) })
        .map(([k, v]) => [k, String(v)])),
      android: { priority: 'high' },
    };
    if (!silent) {
      payload.notification = { title, body };
      payload.android.notification = {
        channelId: category,
        icon: 'ic_notification',
        color: '#1565C0',
        ...(tag ? { tag } : {}),
      };
    }

    const res = await messaging.sendEachForMulticast(payload);
    const stale = res.responses
      .map((r, i) => (!r.success && INVALID_TOKEN_CODES.has(r.error?.code) ? tokensSnap.docs[i].ref : null))
      .filter(Boolean);
    await Promise.all(stale.map(ref => ref.delete()));
    return { uid, sent: res.successCount, stale: stale.length };
  } catch (err) {
    logger.error('Push no enviado', { uid, err: err.message });
    return { uid, sent: 0, reason: 'error' };
  }
}

async function sendToUsers(db, messaging, uids, msg) {
  const unique = [...new Set(uids.filter(Boolean))];
  const results = [];
  for (let i = 0; i < unique.length; i += 20) {
    results.push(...await Promise.all(
      unique.slice(i, i + 20).map(uid => sendToUser(db, messaging, uid, msg))));
  }
  return results;
}

/**
 * true (y registra el envío) si no se avisó [key] a [uid] en los últimos
 * [ms]. `notification_state/{uid}` lo escriben solo las Functions.
 */
async function throttle(db, uid, key, ms, now = new Date()) {
  const ref = db.doc(`notification_state/${uid}`);
  return db.runTransaction(async tx => {
    const snap = await tx.get(ref);
    const last = snap.exists ? snap.data()[key] : null;
    if (last && now.getTime() - last.toMillis() < ms) return false;
    tx.set(ref, { [key]: Timestamp.fromDate(now) }, { merge: true });
    return true;
  });
}

// ── Formato (hora de Bogotá) ─────────────────────────────────────────────

// Colombia no tiene horario de verano: Bogotá = UTC-5 siempre (igual que
// `classes.js` y `BogotaTime` en la app). Formato manual para no depender de
// la versión de ICU del runtime.
const BOGOTA_OFFSET_MS = 5 * 3600 * 1000;
const DAY_NAMES = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];
const MONTHS = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

const bogota = date => new Date(date.getTime() - BOGOTA_OFFSET_MS);

function hhmm(date) {
  const b = bogota(date);
  return `${String(b.getUTCHours()).padStart(2, '0')}:${String(b.getUTCMinutes()).padStart(2, '0')}`;
}

/** "el viernes 20 nov a las 18:00". */
function dayAndTime(date) {
  const b = bogota(date);
  return `el ${DAY_NAMES[b.getUTCDay()]} ${b.getUTCDate()} ${MONTHS[b.getUTCMonth()]} a las ${hhmm(date)}`;
}

const WEEKDAYS = ['', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];

function weekdaysLabel(weekdays) {
  const days = [...(weekdays || [])].sort((a, b) => a - b).map(d => WEEKDAYS[d]).filter(Boolean);
  if (days.length <= 1) return days.join('');
  return `${days.slice(0, -1).join(', ')} y ${days[days.length - 1]}`;
}

// ── Lecturas comunes ─────────────────────────────────────────────────────

async function gymName(db, gymId) {
  const snap = await db.doc(`gyms/${gymId}`).get();
  return snap.exists ? (snap.data().name || 'Tu gimnasio') : 'Tu gimnasio';
}

async function gymAthletes(db, gymId) {
  const snap = await db.collection('gym_members').where('gymId', '==', gymId).get();
  return snap.docs
    .filter(d => d.data().role === 'athlete' && d.data().status === 'accepted')
    .map(d => d.id);
}

async function enrolledUids(db, gymId, classId) {
  const snap = await db.collection(`gyms/${gymId}/classes/${classId}/enrollments`).get();
  return snap.docs.map(d => d.id);
}

const isActiveSchedule = s => !!s && s.active === true;
const millis = t => (t && typeof t.toMillis === 'function' ? t.toMillis() : null);

// ── Disparadores ─────────────────────────────────────────────────────────

/** Horario creado o reactivado: aviso a los atletas del gimnasio. */
async function onScheduleWrite(ctx, { gymId, scheduleId }, before, after) {
  if (!isActiveSchedule(after) || isActiveSchedule(before)) return [];
  const [name, uids] = await Promise.all([gymName(ctx.db, gymId), gymAthletes(ctx.db, gymId)]);
  return sendToUsers(ctx.db, ctx.messaging, uids, {
    category: CATEGORY.gymNews,
    title: `Nueva clase en ${name}: ${after.name}`,
    body: `Los ${weekdaysLabel(after.weekdays)} a las ${after.startTime}. Inscríbete desde la app.`,
    route: ROUTE.gymClasses,
    tag: `gym_news_${gymId}`,
    data: { type: 'new_schedule', gymId, scheduleId },
  });
}

/**
 * Clase suelta creada → atletas del gimnasio. Cancelada o con hora nueva →
 * inscritos (y en el cambio de hora se actualiza `startsAt` de cada
 * inscripción, que usa "Mis clases").
 */
async function onClassWrite(ctx, { gymId, classId }, before, after, now = new Date()) {
  if (!after) return [];
  const { db, messaging } = ctx;
  const startsAt = after.startsAt?.toDate?.();
  if (!startsAt || startsAt <= now) return [];

  if (!before) {
    if (after.scheduleId != null || after.status !== 'scheduled') return [];
    const [name, uids] = await Promise.all([gymName(db, gymId), gymAthletes(db, gymId)]);
    return sendToUsers(db, messaging, uids, {
      category: CATEGORY.gymNews,
      title: `Nueva clase en ${name}: ${after.name}`,
      body: `${capitalize(dayAndTime(startsAt).replace(/^el /, ''))}. Inscríbete desde la app.`,
      route: ROUTE.gymClasses,
      tag: `gym_news_${gymId}`,
      data: { type: 'new_class', gymId, classId },
    });
  }

  if (before.status !== 'cancelled' && after.status === 'cancelled') {
    const [name, uids] = await Promise.all([gymName(db, gymId), enrolledUids(db, gymId, classId)]);
    return sendToUsers(db, messaging, uids, {
      category: CATEGORY.classes,
      title: `Clase cancelada: ${after.name}`,
      body: `${name} canceló la clase de ${after.name} ${dayAndTime(startsAt)}.`,
      route: ROUTE.gymClasses,
      tag: `class_${classId}`,
      data: { type: 'class_cancelled', gymId, classId },
    });
  }

  if (after.status === 'scheduled' && millis(before.startsAt) !== millis(after.startsAt)) {
    const enrollments = await db.collection(`gyms/${gymId}/classes/${classId}/enrollments`).get();
    if (enrollments.empty) return [];
    const batch = db.batch();
    enrollments.docs.forEach(d => batch.update(d.ref, { startsAt: after.startsAt }));
    await batch.commit();
    return sendToUsers(db, messaging, enrollments.docs.map(d => d.id), {
      category: CATEGORY.classes,
      title: `Cambio de hora: ${after.name}`,
      body: `Ahora es ${dayAndTime(startsAt)}. Si ya no puedes ir, cancela tu inscripción para liberar el cupo.`,
      route: ROUTE.gymClasses,
      tag: `class_${classId}`,
      data: { type: 'class_moved', gymId, classId },
    });
  }
  return [];
}

/** Inscripción borrada (por el atleta o el staff): borra el recordatorio local. */
async function onEnrollmentDelete(ctx, { gymId, classId, uid }) {
  return [await sendToUser(ctx.db, ctx.messaging, uid, {
    category: CATEGORY.classes,
    silent: true,
    data: { type: 'enrollment_removed', gymId, classId },
  })];
}

/** Invitación del gimnasio → invitado; aceptada → dueño del gimnasio. */
async function onGymMemberWrite(ctx, { uid }, before, after) {
  if (!after) return [];
  const { db, messaging } = ctx;
  const roleLabel = after.role === 'trainer' ? 'entrenador' : 'atleta';

  if (after.status === 'pending' && (!before || before.status !== 'pending' || before.gymId !== after.gymId)) {
    return [await sendToUser(db, messaging, uid, {
      category: CATEGORY.invites,
      title: `Invitación de ${after.gymName || 'un gimnasio'}`,
      body: `Te invitaron a unirte como ${roleLabel}. Acéptala desde tu perfil.`,
      route: ROUTE.profile,
      tag: 'invite_gym',
      data: { type: 'gym_invite', gymId: after.gymId },
    })];
  }

  if (before?.status === 'pending' && after.status === 'accepted') {
    const gym = await db.doc(`gyms/${after.gymId}`).get();
    const ownerUid = gym.exists ? gym.data().ownerUid : null;
    if (!ownerUid) return [];
    return [await sendToUser(db, messaging, ownerUid, {
      category: CATEGORY.invites,
      title: `${after.email || 'Un usuario'} aceptó tu invitación`,
      body: `Ya es ${roleLabel} de ${after.gymName || 'tu gimnasio'}.`,
      route: ROUTE.home,
      data: { type: 'gym_invite_accepted', gymId: after.gymId },
    })];
  }
  return [];
}

/** Solicitud de entrenador → atleta; aceptada → entrenador. */
async function onTrainerLinkWrite(ctx, { athleteUid }, before, after) {
  if (!after) return [];
  const { db, messaging } = ctx;

  if (after.status === 'pending' && (!before || before.trainerUid !== after.trainerUid)) {
    return [await sendToUser(db, messaging, athleteUid, {
      category: CATEGORY.invites,
      title: `${after.trainerEmail || 'Un entrenador'} quiere ser tu entrenador`,
      body: 'Acepta o rechaza la solicitud desde tu perfil.',
      route: ROUTE.profile,
      tag: 'invite_trainer',
      data: { type: 'trainer_invite' },
    })];
  }

  if (before?.status === 'pending' && after.status === 'accepted') {
    return [await sendToUser(db, messaging, after.trainerUid, {
      category: CATEGORY.invites,
      title: `${after.athleteEmail || 'Tu atleta'} aceptó tu solicitud`,
      body: 'Ya puedes ver y editar su rutina desde Mis atletas.',
      route: ROUTE.home,
      data: { type: 'trainer_invite_accepted' },
    })];
  }
  return [];
}

/** El entrenador editó la rutina del atleta (máx. un aviso cada 3 h). */
async function onRoutineWrite(ctx, { uid }, before, after, now = new Date()) {
  const edited = millis(after?.trainerEditedAt);
  if (!edited || edited === millis(before?.trainerEditedAt)) return [];
  if (after.trainerEditedBy === uid) return [];
  if (!await throttle(ctx.db, uid, 'routineEdit', ROUTINE_EDIT_THROTTLE_MS, now)) return [];
  return [await sendToUser(ctx.db, ctx.messaging, uid, {
    category: CATEGORY.trainer,
    title: 'Tu entrenador actualizó tu rutina',
    body: 'Revisa los cambios antes de tu próxima sesión.',
    route: ROUTE.home,
    tag: 'routine_edit',
    data: { type: 'routine_edit' },
  })];
}

/** Premium del gimnasio activado o terminado; prueba gratis terminada. */
async function onEntitlementWrite(ctx, { uid }, before, after) {
  if (!after) return []; // cuenta borrada
  const { db, messaging } = ctx;
  const wasGym = before?.premium === true && before.source === 'gym_athlete';
  const isGym = after.premium === true && after.source === 'gym_athlete';
  const wasTrial = before?.premium === true && before.source === 'trial';

  if (isGym && !wasGym) {
    const name = await gymName(db, after.gymId);
    return [await sendToUser(db, messaging, uid, {
      category: CATEGORY.premium,
      title: `¡${name} te activó el premium!`,
      body: 'Ya tienes todas las rutinas, tu racha, el progreso semanal y más.',
      route: ROUTE.home,
      tag: 'premium',
      data: { type: 'premium_on' },
    })];
  }
  if (wasGym && !after.premium) {
    const name = await gymName(db, before.gymId);
    return [await sendToUser(db, messaging, uid, {
      category: CATEGORY.premium,
      title: 'Tu premium terminó',
      body: `${name} desactivó tu premium. Sigues entrenando con las rutinas Recomendadas.`,
      route: ROUTE.home,
      tag: 'premium',
      data: { type: 'premium_off' },
    })];
  }
  if (wasTrial && !after.premium) {
    return [await sendToUser(db, messaging, uid, {
      category: CATEGORY.premium,
      title: 'Tu prueba premium terminó',
      body: 'Para seguir con el premium, pídele a tu gimnasio que te lo active desde su panel de TrainApp.',
      route: ROUTE.home,
      tag: 'premium',
      data: { type: 'trial_ended' },
    })];
  }
  return [];
}

/**
 * Diaria a las 10:00: avisa a las pruebas que terminan entre 12 y 36 h
 * después (cada una cae en exactamente una corrida; nunca de madrugada).
 */
async function remindTrialsEnding(ctx, now = new Date()) {
  const { db, messaging } = ctx;
  const from = Timestamp.fromMillis(now.getTime() + 12 * 3600 * 1000);
  const to = Timestamp.fromMillis(now.getTime() + 36 * 3600 * 1000);
  const snap = await db.collection('trial_requests')
    .where('endsAt', '>', from).where('endsAt', '<=', to).get();
  const results = [];
  for (const d of snap.docs) {
    const t = d.data();
    if (t.status !== 'active' || t.endReminderSent) continue;
    await d.ref.update({ endReminderSent: FieldValue.serverTimestamp() });
    results.push(await sendToUser(db, messaging, d.id, {
      category: CATEGORY.premium,
      title: 'Tu prueba premium termina pronto',
      body: `Termina ${dayAndTime(t.endsAt.toDate())}. Para seguir con el premium, pídele a tu gimnasio que te lo active.`,
      route: ROUTE.home,
      tag: 'premium',
      data: { type: 'trial_ending' },
    }));
  }
  return results;
}

function capitalize(s) {
  return s ? s[0].toUpperCase() + s.slice(1) : s;
}

module.exports = {
  CATEGORY,
  sendToUser,
  sendToUsers,
  throttle,
  dayAndTime,
  weekdaysLabel,
  onScheduleWrite,
  onClassWrite,
  onEnrollmentDelete,
  onGymMemberWrite,
  onTrainerLinkWrite,
  onRoutineWrite,
  onEntitlementWrite,
  remindTrialsEnding,
};
