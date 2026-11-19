/**
 * Calcula `entitlements/{uid}` de todos los que hoy tienen premium por su
 * gimnasio: dueños, entrenadores de planta y atletas con premium activado.
 * Hace falta una sola vez al desplegar el premium (después lo mantienen los
 * triggers de `functions/premium.js`), y sirve para reparar si algo quedó
 * desincronizado. Es idempotente.
 *
 * Uso (desde scripts/):
 *   node backfill_entitlements.js            → dry-run: muestra a quién tocaría
 *   node backfill_entitlements.js --commit   → escribe
 *
 * Usa el firebase-admin de functions/ (el mismo que premium.js).
 * Autenticación: Application Default Credentials
 *   gcloud auth application-default login
 */

const path = require('path');

const FUNCTIONS_DIR = path.join(__dirname, '..', 'functions');
const fromFunctions = m => require(require.resolve(m, { paths: [FUNCTIONS_DIR] }));
const { initializeApp, applicationDefault } = fromFunctions('firebase-admin/app');
const { getFirestore } = fromFunctions('firebase-admin/firestore');
const premium = require(path.join(FUNCTIONS_DIR, 'premium.js'));

const PROJECT_ID  = 'trainapp-prod';
const DATABASE_ID = 'trainapp';
const dryRun = !process.argv.includes('--commit');

(async () => {
  const app = initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
  const db = getFirestore(app, DATABASE_ID);

  const [gyms, members] = await Promise.all([
    db.collection('gyms').get(),
    db.collection('gym_members').get(),
  ]);
  const uids = new Set([
    ...gyms.docs.map(d => d.data().ownerUid).filter(Boolean),
    ...members.docs.map(d => d.id),
  ]);

  console.log(`${gyms.size} gimnasios, ${members.size} miembros → ${uids.size} usuarios`);
  if (dryRun) {
    console.log('Dry-run: no se escribe nada. Usa --commit para aplicar.');
    process.exit(0);
  }

  let changed = 0, premiumCount = 0;
  for (const uid of uids) {
    const r = await premium.recomputeEntitlement(db, uid);
    if (r.changed) changed++;
    if (r.premium) premiumCount++;
  }
  console.log(`Listo: ${premiumCount} con premium, ${changed} docs escritos.`);
  process.exit(0);
})().catch(e => { console.error(e); process.exit(1); });
