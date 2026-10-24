/**
 * Migra `user_directory` al formato nuevo: doc id = SHA-256 del email en
 * minúsculas, contenido `{ uid }`. Crea la entrada de cada usuario de Auth
 * y borra las del formato anterior (doc id = uid, contenido `{ email }`).
 *
 * Uso:
 *   node migrate_user_directory.js            → dry-run (no escribe)
 *   node migrate_user_directory.js --commit   → migra en serio
 *
 * Idempotente: se puede correr varias veces.
 *
 * Autenticación: Application Default Credentials
 *   gcloud auth application-default login
 */

const { createHash }                         = require('crypto');
const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getAuth }                            = require('firebase-admin/auth');
const { getFirestore }                       = require('firebase-admin/firestore');

const PROJECT_ID  = 'trainapp-prod';
const DATABASE_ID = 'trainapp';

const dryRun = !process.argv.includes('--commit');

const emailHash = email =>
  createHash('sha256').update(email.trim().toLowerCase(), 'utf8').digest('hex');

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

(async () => {
  console.log(`\n📇 migrate_user_directory — modo: ${dryRun ? 'DRY RUN' : 'COMMIT'}\n`);

  const app  = initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
  const db   = getFirestore(app, DATABASE_ID);
  const auth = getAuth(app);
  const col  = db.collection('user_directory');

  const users = (await listAllUsers(auth)).filter(u => u.email);
  console.log(`Usuarios con email en Auth: ${users.length}`);
  for (const u of users) {
    if (!dryRun) await col.doc(emailHash(u.email)).set({ uid: u.uid });
  }
  console.log(`   ✓ Entradas nuevas: ${users.length}`);

  // Formato anterior: cualquier doc que todavía guarde el email.
  const snap   = await col.get();
  const legacy = snap.docs.filter(d => 'email' in d.data());
  for (const d of legacy) {
    if (!dryRun) await d.ref.delete();
  }
  console.log(`   ✓ Entradas del formato anterior borradas: ${legacy.length}`);

  console.log(
    `\n${dryRun
      ? '🔎 Dry run terminado. Para migrar de verdad: node migrate_user_directory.js --commit'
      : '✅ Migración completada.'}\n`
  );
  process.exit(0);
})().catch(err => {
  console.error('\n❌ Error:', err);
  process.exit(1);
});
