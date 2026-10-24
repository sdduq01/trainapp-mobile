/**
 * Asigna o quita el rol de admin de TrainApp (custom claim `admin: true`) a
 * una cuenta. El admin ve "Solicitudes" en el portal de gimnasios y puede
 * aprobarlas o rechazarlas. Solo se puede asignar con el Admin SDK: ningún
 * usuario puede dárselo a sí mismo.
 *
 * Uso:
 *   node set_admin.js --email tu@correo.com                    → dry-run
 *   node set_admin.js --email tu@correo.com --commit           → asigna
 *   node set_admin.js --email tu@correo.com --remove --commit  → quita
 *
 * El portal renueva el token al cargar, así que basta con recargar la página.
 *
 * Autenticación: Application Default Credentials
 *   gcloud auth application-default login
 */

const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getAuth }                            = require('firebase-admin/auth');

const PROJECT_ID = 'trainapp-prod';

function arg(name) {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

const email  = arg('email')?.trim().toLowerCase();
const remove = process.argv.includes('--remove');
const dryRun = !process.argv.includes('--commit');

(async () => {
  if (!email) {
    console.error('Uso: node set_admin.js --email correo [--remove] [--commit]');
    process.exit(1);
  }
  console.log(`\n🔑 set_admin — modo: ${dryRun ? 'DRY RUN' : 'COMMIT'}\n`);

  const auth = getAuth(initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID }));
  const user = await auth.getUserByEmail(email);
  const claims = { ...(user.customClaims ?? {}) };
  console.log(`Cuenta: ${email} (uid ${user.uid})`);
  console.log(`Admin actual: ${claims.admin === true ? 'sí' : 'no'}`);

  if (remove) delete claims.admin;
  else claims.admin = true;

  if (!dryRun) await auth.setCustomUserClaims(user.uid, claims);

  console.log(
    `\n${dryRun
      ? `🔎 Dry run: se ${remove ? 'quitaría' : 'asignaría'} el rol admin. Agrega --commit para aplicarlo.`
      : `✅ Rol admin ${remove ? 'quitado' : 'asignado'}. Recarga el portal.`}\n`
  );
  process.exit(0);
})().catch(err => {
  console.error('\n❌ Error:', err.message ?? err);
  process.exit(1);
});
