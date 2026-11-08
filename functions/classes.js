/**
 * Clases grupales: genera las clases de los próximos 14 días a partir de los
 * horarios semanales de cada gimnasio (`gyms/{gymId}/schedules/{id}`).
 *
 * Una clase de horario tiene id `${scheduleId}_${yyyyMMdd}`, así que generar
 * dos veces el mismo día no duplica nada. Las clases que el staff editó a
 * mano (`edited: true`) y las sueltas (`scheduleId: null`) no se tocan.
 *
 * Colombia no tiene horario de verano: hora de Bogotá = UTC-5 siempre.
 */

const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const logger = require('firebase-functions/logger');

const DAYS_AHEAD = 14;
const BOGOTA_OFFSET_HOURS = 5;
const DAY_MS = 24 * 60 * 60 * 1000;

/** Clases que debería tener [schedule] desde hoy (hora Bogotá) por 14 días. */
function desiredClasses(scheduleId, schedule, now = new Date()) {
  const result = new Map();
  if (!schedule || schedule.active !== true) return result;

  const [hh, mm] = String(schedule.startTime).split(':').map(Number);
  // "Hoy" en Bogotá, como fecha UTC a medianoche.
  const local = new Date(now.getTime() - BOGOTA_OFFSET_HOURS * 3600 * 1000);
  const today = Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate());

  for (let i = 0; i < DAYS_AHEAD; i++) {
    const day = new Date(today + i * DAY_MS);
    const isoWeekday = ((day.getUTCDay() + 6) % 7) + 1; // lunes = 1
    if (!schedule.weekdays.includes(isoWeekday)) continue;

    const startsAt = new Date(Date.UTC(
      day.getUTCFullYear(), day.getUTCMonth(), day.getUTCDate(),
      hh + BOGOTA_OFFSET_HOURS, mm,
    ));
    if (startsAt <= now) continue;

    const ymd = day.toISOString().slice(0, 10).replace(/-/g, '');
    result.set(`${scheduleId}_${ymd}`, {
      name: schedule.name,
      description: schedule.description ?? '',
      instructor: schedule.instructor ?? '',
      startsAt: Timestamp.fromDate(startsAt),
      durationMin: schedule.durationMin,
      capacity: schedule.capacity,
    });
  }
  return result;
}

/**
 * Deja las clases futuras de un horario como dicta el horario actual
 * ([schedule] null = borrado):
 * - crea las que faltan;
 * - actualiza las existentes no editadas (el cupo nunca baja de los inscritos);
 * - las que ya no corresponden se borran si no tienen inscritos, o se
 *   cancelan si los tienen.
 * Las escrituras usan la versión leída como precondición: si un atleta se
 * inscribe justo en medio, esa clase se deja como está hasta la próxima corrida.
 */
async function syncSchedule(db, gymId, scheduleId, schedule, now = new Date()) {
  const classes = db.collection('gyms').doc(gymId).collection('classes');
  const desired = desiredClasses(scheduleId, schedule, now);

  const existing = await classes.where('scheduleId', '==', scheduleId).get();
  const counts = { created: 0, updated: 0, deleted: 0, cancelled: 0, skipped: 0 };
  const ops = [];

  const seen = new Set();
  for (const snap of existing.docs) {
    const c = snap.data();
    seen.add(snap.id);
    if (c.startsAt.toDate() <= now || c.edited === true) continue;

    const precondition = { lastUpdateTime: snap.updateTime };
    const want = desired.get(snap.id);
    if (want) {
      const patch = {
        ...want,
        capacity: Math.max(want.capacity, c.enrolledCount ?? 0),
        status: 'scheduled',
      };
      const changed = Object.entries(patch).some(([k, v]) =>
        v instanceof Timestamp ? !v.isEqual(c[k]) : v !== c[k]);
      if (!changed) continue;
      ops.push(snap.ref.update(patch, precondition).then(() => counts.updated++));
    } else if ((c.enrolledCount ?? 0) === 0) {
      ops.push(snap.ref.delete(precondition).then(() => counts.deleted++));
    } else if (c.status !== 'cancelled') {
      ops.push(snap.ref.update({ status: 'cancelled' }, precondition)
        .then(() => counts.cancelled++));
    }
  }

  for (const [id, want] of desired) {
    if (seen.has(id)) continue;
    ops.push(classes.doc(id).create({
      ...want,
      enrolledCount: 0,
      status: 'scheduled',
      scheduleId,
      edited: false,
    }).then(() => counts.created++));
  }

  const results = await Promise.allSettled(ops);
  for (const r of results) {
    if (r.status === 'rejected') {
      counts.skipped++;
      logger.warn('Clase no sincronizada', { gymId, scheduleId, err: r.reason?.message });
    }
  }
  return counts;
}

/** Recorre todos los horarios de todos los gimnasios activos. */
async function syncAllSchedules(db, now = new Date()) {
  const gyms = await db.collection('gyms').get();
  let total = 0;
  for (const gym of gyms.docs) {
    if ((gym.data().status ?? 'active') !== 'active') continue;
    const schedules = await gym.ref.collection('schedules').get();
    for (const s of schedules.docs) {
      const counts = await syncSchedule(db, gym.id, s.id, s.data(), now);
      total += counts.created;
    }
  }
  return total;
}

module.exports = { desiredClasses, syncSchedule, syncAllSchedules, getFirestore };
