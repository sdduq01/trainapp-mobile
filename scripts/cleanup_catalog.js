/**
 * Borra los catálogos globales de la app:
 *   - routine_templates/*  (plantillas del catálogo: Recomendadas, Deportes, Macro, Limited, Top Secret)
 *   - exercises/*          (catálogo de ejercicios)
 *
 * NO toca datos de usuario (perfiles, rutinas activas, sesiones, PRs, notas).
 * Para eso usar cleanup_users.js.
 *
 * Uso:
 *   node cleanup_catalog.js            → dry-run (cuenta qué borraría)
 *   node cleanup_catalog.js --commit   → borra de verdad
 *
 * Autenticación: Application Default Credentials
 *   gcloud auth application-default login
 */

const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore }                       = require('firebase-admin/firestore');

const PROJECT_ID  = 'trainapp-prod';
const DATABASE_ID = 'trainapp';

const COLLECTIONS = ['routine_templates', 'exercises'];

const dryRun = !process.argv.includes('--commit');

async function wipeCollection(db, name) {
  const ref = db.collection(name);
  let total = 0;

  while (true) {
    const snap = await ref.limit(400).get();
    if (snap.empty) break;
    if (dryRun) {
      total += snap.size;
      // En dry-run muestra los primeros nombres para que el usuario revise.
      const sample = snap.docs.slice(0, 5).map(d => d.id).join(', ');
      console.log(`   · ${snap.size} docs (sample: ${sample}${snap.size > 5 ? ', …' : ''})`);
      if (snap.size < 400) break;
      continue;
    }
    const batch = db.batch();
    snap.docs.forEach(d => batch.delete(d.ref));
    await batch.commit();
    total += snap.size;
    if (snap.size < 400) break;
  }

  return total;
}

(async () => {
  console.log(`\n🧨 cleanup_catalog — modo: ${dryRun ? 'DRY RUN' : 'COMMIT'}\n`);

  const app = initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
  const db  = getFirestore(app, DATABASE_ID);

  for (const col of COLLECTIONS) {
    console.log(`▸ ${col}`);
    const n = await wipeCollection(db, col);
    console.log(`   ${dryRun ? '↳ borrarían' : '✓ borrados'}: ${n}\n`);
  }

  console.log(
    dryRun
      ? '🔎 Dry run terminado. Para borrar de verdad: node cleanup_catalog.js --commit'
      : '✅ Limpieza completada.'
  );
  process.exit(0);
})().catch(err => {
  console.error('\n❌ Error:', err);
  process.exit(1);
});
