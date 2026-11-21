/**
 * Premium otorgado por gimnasios y facturación mensual.
 *
 * - `entitlements/{uid}` es la única fuente de verdad de si un usuario es
 *   premium. Solo lo escribe esta función (las reglas lo dejan en solo
 *   lectura), a partir de:
 *     · dueño de un gimnasio activo           → premium (staff, no se factura)
 *     · entrenador de planta aceptado          → premium (staff, no se factura)
 *     · atleta aceptado con `premium: true`    → premium (se factura al gimnasio)
 *   Un gimnasio con `status: 'suspended'` no da premium a nadie.
 *
 * - `gyms/{gymId}/billing_athletes/{uid}` guarda, por atleta, los periodos en
 *   que tuvo premium facturable y su primer día de premium en ese gimnasio
 *   (`firstPremiumAt`, nunca se reinicia: el mes gratis es uno solo aunque el
 *   gimnasio lo desactive y lo vuelva a activar).
 *
 * - Regla de cobro: desde `freeFrom` (el día 1 del mes siguiente a su primera
 *   activación) se cobran $4.000 por mes, proporcionales a los días del mes
 *   en que tuvo premium (cuenta el día completo aunque lo tuviera solo unas
 *   horas). Mes completo = $4.000; retirado el 8 de febrero = 8/28.
 *
 * - El día 1 de cada mes se genera la factura del mes anterior
 *   (`gyms/{gymId}/invoices/{yyyyMM}`), que vence el día 5. Los gimnasios
 *   con `billingExempt: true` (solo lo pone un admin) no se facturan.
 *
 * - Prueba gratis: 7 días de premium, una sola vez por email. La app crea
 *   `trial_requests/{uid}`; `startTrial` la activa (status 'active', endsAt)
 *   o la rechaza (status 'rejected', reason 'used') si el email ya la usó
 *   (`trial_emails/{sha256(email)}`, que se conserva aunque se borre la
 *   cuenta). El premium del gimnasio tiene prioridad sobre la prueba. Con
 *   prueba, `entitlements` lleva `expiresAt` y reglas y app lo respetan;
 *   `expireTrials` lo limpia cada hora.
 *
 * Colombia no tiene horario de verano: hora de Bogotá = UTC-5 siempre.
 */

const crypto = require('crypto');
const { Timestamp } = require('firebase-admin/firestore');

const TRIAL_DAYS = 7;

const PRICE_PER_ATHLETE = 4000; // COP por atleta premium al mes
const DUE_DAY = 5;              // la factura vence al terminar este día
const BOGOTA_OFFSET_HOURS = 5;

// ── Fechas (meses en hora de Bogotá) ─────────────────────────────────────

/** Instante en que empieza el mes [month0] (0 = enero) de [year] en Bogotá. */
function monthStart(year, month0) {
  return new Date(Date.UTC(year, month0, 1, BOGOTA_OFFSET_HOURS));
}

/** {year, month0} del mes (en Bogotá) que contiene [date]. */
function bogotaMonthOf(date) {
  const local = new Date(date.getTime() - BOGOTA_OFFSET_HOURS * 3600 * 1000);
  return { year: local.getUTCFullYear(), month0: local.getUTCMonth() };
}

/** Día 1 del mes siguiente al que contiene [date] (en Bogotá). */
function nextMonthStart(date) {
  const { year, month0 } = bogotaMonthOf(date);
  return monthStart(year, month0 + 1);
}

/** Id de la factura del mes: 'yyyyMM'. */
function monthId(year, month0) {
  return `${year}${String(month0 + 1).padStart(2, '0')}`;
}

/** Fin del plazo de pago de la factura del mes [month0]: día 5 del siguiente, 23:59:59. */
function dueDateFor(year, month0) {
  const nextStart = monthStart(year, month0 + 1);
  return new Date(nextStart.getTime() + DUE_DAY * 24 * 3600 * 1000 - 1000);
}

const toDate = v => (v == null ? null : v instanceof Date ? v : v.toDate());

const DAY_MS = 24 * 3600 * 1000;

/** Días que tiene el mes [month0] de [year]. */
function daysInMonth(year, month0) {
  return new Date(Date.UTC(year, month0 + 1, 0)).getUTCDate();
}

/**
 * Días (de Bogotá) del mes [year]/[month0] que se le cobran a este atleta:
 * los días en que tuvo premium, si el mes ya pasó su mes gratis. Un periodo
 * abierto cuenta hasta fin de mes. [billing] es el doc de `billing_athletes`.
 */
function billableDaysInMonth(billing, year, month0) {
  const start = monthStart(year, month0);
  const freeFrom = toDate(billing.freeFrom);
  if (!freeFrom || freeFrom > start) return 0;
  const periods = (billing.periods || []).map(p => [toDate(p.start), toDate(p.end)]);
  let days = 0;
  for (let d = 0; d < daysInMonth(year, month0); d++) {
    const dayStart = new Date(start.getTime() + d * DAY_MS);
    const dayEnd = new Date(dayStart.getTime() + DAY_MS);
    if (periods.some(([ps, pe]) => ps < dayEnd && (pe == null || pe > dayStart))) days++;
  }
  return days;
}

/** Valor a cobrar por [days] días del mes: proporcional, redondeado al peso. */
function amountForDays(days, year, month0) {
  return Math.round(PRICE_PER_ATHLETE * days / daysInMonth(year, month0));
}

/** ¿Se le cobra algo del mes [year]/[month0] a este atleta? */
function isBillableInMonth(billing, year, month0) {
  return billableDaysInMonth(billing, year, month0) > 0;
}

// ── Cálculo del premium ──────────────────────────────────────────────────

/** Qué debería tener [uid] según su gimnasio o su prueba. Lee dentro de [tx]. */
async function desiredEntitlement(tx, db, uid, now = new Date()) {
  const [memberSnap, ownedSnap, trialSnap] = await Promise.all([
    tx.get(db.doc(`gym_members/${uid}`)),
    tx.get(db.collection('gyms').where('ownerUid', '==', uid).limit(1)),
    tx.get(db.doc(`trial_requests/${uid}`)),
  ]);

  let result = { premium: false, source: null, gymId: null, billable: false, expiresAt: null };

  if (!ownedSnap.empty) {
    const gym = ownedSnap.docs[0];
    if (gym.data().status !== 'suspended') {
      result = { premium: true, source: 'gym_owner', gymId: gym.id, billable: false, expiresAt: null };
    }
  }

  if (memberSnap.exists) {
    const m = memberSnap.data();
    if (m.status === 'accepted') {
      const gymSnap = await tx.get(db.doc(`gyms/${m.gymId}`));
      const active = gymSnap.exists && gymSnap.data().status !== 'suspended';
      if (active && m.role === 'trainer' && !result.premium) {
        result = { premium: true, source: 'gym_trainer', gymId: m.gymId, billable: false, expiresAt: null };
      } else if (active && m.role === 'athlete' && m.premium === true) {
        result = {
          premium: true, source: 'gym_athlete', gymId: m.gymId, billable: true,
          email: m.email || '', expiresAt: null,
        };
      }
    }
  }

  if (!result.premium && trialSnap.exists) {
    const t = trialSnap.data();
    if (t.status === 'active' && t.endsAt && t.endsAt.toMillis() > now.getTime()) {
      result = {
        premium: true, source: 'trial', gymId: null, billable: false,
        expiresAt: t.endsAt,
      };
    }
  }
  return result;
}

/**
 * Recalcula `entitlements/{uid}` y abre/cierra el periodo facturable en el
 * gimnasio que corresponda. Idempotente: se puede llamar cuantas veces sea.
 */
async function recomputeEntitlement(db, uid, now = new Date()) {
  return db.runTransaction(async tx => {
    const entRef = db.doc(`entitlements/${uid}`);
    const entSnap = await tx.get(entRef);
    const prev = entSnap.exists ? entSnap.data() : null;
    const want = await desiredEntitlement(tx, db, uid, now);

    const prevBillingGym = prev?.billingGymId ?? null;
    const newBillingGym = want.billable ? want.gymId : null;

    // Lecturas de facturación antes de cualquier escritura (regla de las
    // transacciones de Firestore).
    const closeRef = prevBillingGym && prevBillingGym !== newBillingGym
      ? db.doc(`gyms/${prevBillingGym}/billing_athletes/${uid}`) : null;
    const openRef = newBillingGym
      ? db.doc(`gyms/${newBillingGym}/billing_athletes/${uid}`) : null;
    const closeSnap = closeRef ? await tx.get(closeRef) : null;
    const openSnap = openRef ? await tx.get(openRef) : null;

    const nowTs = Timestamp.fromDate(now);

    if (closeSnap?.exists) {
      const periods = (closeSnap.data().periods || []).map(p =>
        p.end == null ? { ...p, end: nowTs } : p);
      tx.update(closeRef, { periods, active: false, updatedAt: nowTs });
    }

    if (openRef) {
      const data = openSnap.exists ? openSnap.data() : null;
      const periods = data?.periods || [];
      const hasOpen = periods.some(p => p.end == null);
      if (!data) {
        tx.set(openRef, {
          uid,
          email: want.email,
          firstPremiumAt: nowTs,
          freeFrom: Timestamp.fromDate(nextMonthStart(now)),
          periods: [{ start: nowTs, end: null }],
          active: true,
          updatedAt: nowTs,
        });
      } else if (!hasOpen) {
        tx.update(openRef, {
          email: want.email || data.email || '',
          periods: [...periods, { start: nowTs, end: null }],
          active: true,
          updatedAt: nowTs,
        });
      }
    }

    // Un usuario sin doc que tampoco debe ser premium no necesita uno (p. ej.
    // tras borrar su cuenta).
    const changed = !prev ||
      prev.premium !== want.premium ||
      (prev.source ?? null) !== want.source ||
      (prev.gymId ?? null) !== want.gymId ||
      prevBillingGym !== newBillingGym ||
      (prev.expiresAt?.toMillis?.() ?? null) !== (want.expiresAt?.toMillis?.() ?? null);
    if (!changed || (!prev && !want.premium)) {
      return { uid, premium: want.premium, changed: false };
    }

    tx.set(entRef, {
      premium: want.premium,
      source: want.source,
      gymId: want.gymId,
      billingGymId: newBillingGym,
      expiresAt: want.expiresAt ?? null,
      updatedAt: nowTs,
    });
    return { uid, premium: want.premium, changed: true };
  });
}

/** Recalcula al dueño y a todos los miembros de [gymId] (p. ej. al suspenderlo). */
async function recomputeGym(db, gymId, ownerUids, now = new Date()) {
  const members = await db.collection('gym_members').where('gymId', '==', gymId).get();
  const uids = new Set([...ownerUids.filter(Boolean), ...members.docs.map(d => d.id)]);
  const results = [];
  for (const uid of uids) results.push(await recomputeEntitlement(db, uid, now));
  return results;
}

// ── Prueba gratis ────────────────────────────────────────────────────────

const emailHash = email =>
  crypto.createHash('sha256').update(String(email).trim().toLowerCase()).digest('hex');

/**
 * Procesa `trial_requests/{uid}` recién creado: lo activa por TRIAL_DAYS o lo
 * rechaza si el email ya usó su prueba (o no hay email). Idempotente: solo
 * actúa sobre solicitudes sin `status`.
 */
async function startTrial(db, uid, email, now = new Date()) {
  const reqRef = db.doc(`trial_requests/${uid}`);
  const result = await db.runTransaction(async tx => {
    const reqSnap = await tx.get(reqRef);
    if (!reqSnap.exists || reqSnap.data().status) return { uid, status: 'skipped' };
    const nowTs = Timestamp.fromDate(now);
    if (!email) {
      tx.update(reqRef, { status: 'rejected', reason: 'no_email', processedAt: nowTs });
      return { uid, status: 'rejected' };
    }
    const emailRef = db.doc(`trial_emails/${emailHash(email)}`);
    const emailSnap = await tx.get(emailRef);
    if (emailSnap.exists) {
      tx.update(reqRef, { status: 'rejected', reason: 'used', processedAt: nowTs });
      return { uid, status: 'rejected' };
    }
    const endsAt = Timestamp.fromMillis(now.getTime() + TRIAL_DAYS * 24 * 3600 * 1000);
    tx.set(emailRef, { usedAt: nowTs });
    tx.update(reqRef, { status: 'active', startedAt: nowTs, endsAt, processedAt: nowTs });
    return { uid, status: 'active' };
  });
  if (result.status === 'active') await recomputeEntitlement(db, uid, now);
  return result;
}

/** Marca como vencidas las pruebas terminadas y recalcula su premium. */
async function expireTrials(db, now = new Date()) {
  // Solo las activas: sin el filtro, cada hora se leían todas las pruebas
  // vencidas de la historia (índice compuesto status + endsAt).
  const snap = await db.collection('trial_requests')
    .where('status', '==', 'active')
    .where('endsAt', '<=', Timestamp.fromDate(now)).get();
  let expired = 0;
  for (const d of snap.docs) {
    await d.ref.update({ status: 'expired' });
    await recomputeEntitlement(db, d.id, now);
    expired++;
  }
  return expired;
}

// ── Facturación ──────────────────────────────────────────────────────────

/**
 * Crea la factura del mes [year]/[month0] de cada gimnasio que tenga atletas
 * cobrables. No toca facturas ya existentes (se puede re-ejecutar).
 */
async function generateInvoices(db, year, month0, now = new Date()) {
  const id = monthId(year, month0);
  const gyms = await db.collection('gyms').get();
  let created = 0;

  for (const gym of gyms.docs) {
    // Exentos (aliados, pruebas gratuitas): sus periodos se registran, pero no
    // se factura. Si pierden la exención, se cobra desde ese mes.
    if (gym.data().billingExempt === true) continue;
    const invoiceRef = gym.ref.collection('invoices').doc(id);
    if ((await invoiceRef.get()).exists) continue;

    const billing = await gym.ref.collection('billing_athletes').get();
    const lines = billing.docs
      .map(d => {
        const days = billableDaysInMonth(d.data(), year, month0);
        return {
          uid: d.id,
          email: d.data().email || '',
          days,
          amount: amountForDays(days, year, month0),
        };
      })
      .filter(l => l.days > 0)
      .sort((a, b) => a.email.localeCompare(b.email));
    if (lines.length === 0) continue;

    await invoiceRef.set({
      gymId: gym.id,
      gymName: gym.data().name || '',
      month: id,
      unitPrice: PRICE_PER_ATHLETE,
      daysInMonth: daysInMonth(year, month0),
      count: lines.length,
      total: lines.reduce((sum, l) => sum + l.amount, 0),
      lines,
      status: 'pending',
      issuedAt: Timestamp.fromDate(now),
      dueAt: Timestamp.fromDate(dueDateFor(year, month0)),
      paidAt: null,
      paidNote: '',
    });
    created++;
  }
  return created;
}

/** Mes (en Bogotá) anterior al que contiene [date]. */
function previousMonth(date) {
  const { year, month0 } = bogotaMonthOf(date);
  return month0 === 0 ? { year: year - 1, month0: 11 } : { year, month0: month0 - 1 };
}

module.exports = {
  PRICE_PER_ATHLETE,
  monthStart,
  nextMonthStart,
  monthId,
  dueDateFor,
  isBillableInMonth,
  billableDaysInMonth,
  amountForDays,
  daysInMonth,
  previousMonth,
  recomputeEntitlement,
  recomputeGym,
  generateInvoices,
  TRIAL_DAYS,
  emailHash,
  startTrial,
  expireTrials,
};
