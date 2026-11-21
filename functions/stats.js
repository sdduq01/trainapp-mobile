/**
 * Resumen semanal de entrenamiento por usuario en `session_stats/{uid}`:
 *
 *   weeks:        { 'YYYY-MM-DD' (lunes): { done, planned|null } }
 *   progressions: { 'YYYY-MM-DD' (lunes): suma de exerciseCount }
 *   version:      1 cuando ya incluye todo el historial
 *
 * Con esto la gráfica y la racha leen un solo documento en vez de todo el
 * historial de sesiones en cada apertura. La app lee aparte la semana en
 * curso (para no esperar a esta función) y usa el historial completo como
 * respaldo mientras el doc no tenga `version`.
 *
 * Las fechas de sesiones y progresiones se guardan como ISO 8601 local del
 * teléfono sin zona ("2026-11-21T16:04:55.123"): el día y el lunes se leen
 * directo del texto, igual que hace la app.
 */

const { FieldValue } = require('firebase-admin/firestore');

const STATS_VERSION = 1;

/** Lunes ('YYYY-MM-DD') de la semana de una fecha ISO local. */
function mondayKey(isoDate) {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(isoDate || ''));
  if (!m) return null;
  const d = new Date(Date.UTC(+m[1], +m[2] - 1, +m[3]));
  d.setUTCDate(d.getUTCDate() - ((d.getUTCDay() + 6) % 7));
  return d.toISOString().slice(0, 10);
}

function nextMondayKey(key) {
  const d = new Date(`${key}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + 7);
  return d.toISOString().slice(0, 10);
}

/** Semana a partir de sus sesiones: cuántas y el objetivo de la primera que lo guarde. */
function summarizeWeek(sessions) {
  const stamped = sessions
    .filter(s => Number.isInteger(s.plannedDays))
    .sort((a, b) => String(a.date).localeCompare(String(b.date)));
  return { done: sessions.length, planned: stamped.length ? stamped[0].plannedDays : null };
}

function groupByWeek(docs) {
  const byWeek = new Map();
  for (const d of docs) {
    const key = mondayKey(d.date);
    if (!key) continue;
    if (!byWeek.has(key)) byWeek.set(key, []);
    byWeek.get(key).push(d);
  }
  return byWeek;
}

function fullStats(sessions, progressions) {
  const weeks = {};
  for (const [key, list] of groupByWeek(sessions)) weeks[key] = summarizeWeek(list);
  const prog = {};
  for (const [key, list] of groupByWeek(progressions)) {
    prog[key] = list.reduce((n, p) => n + (Number(p.exerciseCount) || 0), 0);
  }
  return { weeks, progressions: prog };
}

async function weekDocs(tx, db, col, key) {
  const snap = await tx.get(db.collection(col)
    .where('date', '>=', key)
    .where('date', '<', nextMondayKey(key)));
  return snap.docs.map(d => d.data());
}

/**
 * Recalcula las semanas que tocó un cambio en `sessions/{uid}/logs` o
 * `progressions/{uid}/logs` ([kind] = 'sessions' | 'progressions'). Si el
 * resumen aún no incluye el historial completo, lo reconstruye entero (una
 * vez por usuario). Sin datos, borra el doc (p. ej. al reiniciar o borrar la
 * cuenta). En transacción: la sesión y su progresión llegan casi a la vez y
 * no deben pisarse.
 */
async function updateStats(db, uid, kind, dates) {
  const ref = db.doc(`session_stats/${uid}`);
  const sessionsCol = `sessions/${uid}/logs`;
  const progressionsCol = `progressions/${uid}/logs`;

  return db.runTransaction(async tx => {
    const snap = await tx.get(ref);
    const current = snap.exists ? snap.data() : null;

    let weeks, progressions;
    if (!current || current.version !== STATS_VERSION) {
      const [s, p] = await Promise.all([
        tx.get(db.collection(sessionsCol)),
        tx.get(db.collection(progressionsCol)),
      ]);
      ({ weeks, progressions } = fullStats(s.docs.map(d => d.data()), p.docs.map(d => d.data())));
    } else {
      weeks = { ...(current.weeks || {}) };
      progressions = { ...(current.progressions || {}) };
      const keys = [...new Set(dates.map(mondayKey).filter(Boolean))];
      for (const key of keys) {
        if (kind === 'sessions') {
          const list = await weekDocs(tx, db, sessionsCol, key);
          if (list.length) weeks[key] = summarizeWeek(list);
          else delete weeks[key];
        } else {
          const list = await weekDocs(tx, db, progressionsCol, key);
          if (list.length) {
            progressions[key] = list.reduce((n, p) => n + (Number(p.exerciseCount) || 0), 0);
          } else {
            delete progressions[key];
          }
        }
      }
    }

    if (!Object.keys(weeks).length && !Object.keys(progressions).length) {
      if (snap.exists) tx.delete(ref);
      return { uid, deleted: snap.exists };
    }
    // set completo (no merge): las semanas borradas desaparecen del mapa.
    tx.set(ref, {
      weeks,
      progressions,
      version: STATS_VERSION,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { uid, weeks: Object.keys(weeks).length };
  });
}

module.exports = { STATS_VERSION, mondayKey, nextMondayKey, summarizeWeek, fullStats, updateStats };
