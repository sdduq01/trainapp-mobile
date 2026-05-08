/**
 * Borra TODOS los usuarios de Firebase Authentication y limpia sus datos en
 * Firestore (perfiles, rutinas, sesiones, progresiones, PRs y apuntes).
 *
 * Uso:
 *   node cleanup_users.js            → dry-run (lista qué borraría, no escribe)
 *   node cleanup_users.js --commit   → borra en serio
 *
 * NO toca colecciones globales (`exercises`, `routine_templates`).
 *
 * Autenticación: Application Default Credentials
 *   gcloud auth application-default login
 */

const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getAuth }                            = require('firebase-admin/auth');
const { getFirestore }                       = require('firebase-admin/firestore');

const PROJECT_ID  = 'trainapp-prod';
const DATABASE_ID = 'trainapp';

// Doc raíz por usuario en cada colección.
const USER_DOC_COLLECTIONS = ['profiles', 'routines'];

// Subcolección bajo {col}/{uid}/{sub} cuyo contenido debe borrarse.
const USER_SUBCOLLECTIONS = [
  { col: 'sessions',       sub: 'logs' },
  { col: 'progressions',   sub: 'logs' },
  { col: 'exercise_prs',   sub: 'items' },
  { col: 'exercise_notes', sub: 'items' },
];

const dryRun = !process.argv.includes('--commit');

// ── helpers ──────────────────────────────────────────────────────────────────

async function listAllUsers(auth) {
  const all = [];
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    all.push(...page.users);
    pageToken = page.pageToken;
  } while (pageToken);
  return all;
}

async function deleteCollectionDocs(db, ref, label) {
  // Pagina y borra en batches de 400 docs.
  let total = 0;
  while (true) {
    const snap = await ref.limit(400).get();
    if (snap.empty) break;
    if (dryRun) {
      total += snap.size;
      break; // Solo cuenta una página para estimar.
    }
    const batch = db.batch();
    snap.docs.forEach(d => batch.delete(d.ref));
    await batch.commit();
    total += snap.size;
    if (snap.size < 400) break;
  }
  if (total > 0) console.log(`     · ${label}: ${total}${dryRun ? ' (estimado)' : ''}`);
  return total;
}

async function deleteDocIfExists(db, ref, label) {
  const snap = await ref.get();
  if (!snap.exists) return false;
  if (!dryRun) await ref.delete();
  console.log(`     · ${label}: 1`);
  return true;
}

async function cleanUserData(db, uid) {
  console.log(`   → Firestore (${uid})`);

  for (const col of USER_DOC_COLLECTIONS) {
    await deleteDocIfExists(db, db.collection(col).doc(uid), `${col}/${uid}`);
  }

  for (const { col, sub } of USER_SUBCOLLECTIONS) {
    const subRef = db.collection(col).doc(uid).collection(sub);
    await deleteCollectionDocs(db, subRef, `${col}/${uid}/${sub}/*`);
    // El doc padre suele no existir (solo es un path), pero lo intentamos.
    await deleteDocIfExists(db, db.collection(col).doc(uid), `${col}/${uid} (padre)`);
  }
}

async function deleteAuthUsers(auth, uids) {
  if (dryRun || uids.length === 0) return;
  // deleteUsers acepta hasta 1000 uids por llamada.
  for (let i = 0; i < uids.length; i += 1000) {
    const slice = uids.slice(i, i + 1000);
    const result = await auth.deleteUsers(slice);
    console.log(
      `   ✓ Auth borrados: ${result.successCount} · fallos: ${result.failureCount}`
    );
    result.errors.forEach(e =>
      console.error(`     ! ${e.index} ${slice[e.index]}: ${e.error.message}`)
    );
  }
}

// ── main ─────────────────────────────────────────────────────────────────────

(async () => {
  console.log(`\n🧨 cleanup_users — modo: ${dryRun ? 'DRY RUN' : 'COMMIT'}\n`);

  const app  = initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
  const db   = getFirestore(app, DATABASE_ID);
  const auth = getAuth(app);

  const users = await listAllUsers(auth);
  console.log(`Usuarios en Auth: ${users.length}\n`);

  if (users.length === 0) {
    console.log('Nada que borrar.');
    process.exit(0);
  }

  for (const u of users) {
    console.log(`▸ ${u.email ?? '(sin email)'} · ${u.uid}`);
    await cleanUserData(db, u.uid);
  }

  await deleteAuthUsers(auth, users.map(u => u.uid));

  console.log(
    `\n${dryRun
      ? '🔎 Dry run terminado. Para borrar de verdad: node cleanup_users.js --commit'
      : '✅ Limpieza completada.'}\n`
  );
  process.exit(0);
})().catch(err => {
  console.error('\n❌ Error:', err);
  process.exit(1);
});
