/**
 * Crea un gimnasio (`gyms/{gymId}`) con su dueño y, opcionalmente, su logo,
 * sin pasar por una solicitud del portal (lo normal es que el dueño la envíe
 * desde /gimnasio y un admin la apruebe ahí). El dueño completa ciudad,
 * dirección y teléfono desde el portal.
 *
 * Uso:
 *   node create_gym.js --name "Iron Gym" --owner dueno@ejemplo.com [--logo ./logo.png]
 *       → dry-run (no escribe)
 *   node create_gym.js --name "Iron Gym" --owner dueno@ejemplo.com [--logo ./logo.png] --commit
 *       → crea el gimnasio en serio
 *
 * El dueño debe tener cuenta en TrainApp. Una cuenta administra un solo
 * gimnasio. El logo (PNG o JPG, idealmente cuadrado y < 1 MB) se sube a
 * Storage en gym_logos/{ownerUid}/.
 *
 * Autenticación: Application Default Credentials
 *   gcloud auth application-default login
 */

const fs   = require('fs');
const path = require('path');
const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getAuth }                            = require('firebase-admin/auth');
const { getFirestore, FieldValue }           = require('firebase-admin/firestore');
const { getStorage, getDownloadURL }         = require('firebase-admin/storage');

const PROJECT_ID  = 'trainapp-prod';
const DATABASE_ID = 'trainapp';
const BUCKET      = 'trainapp-prod.firebasestorage.app';

function arg(name) {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

const name    = arg('name')?.trim();
const owner   = arg('owner')?.trim().toLowerCase();
const logo    = arg('logo');
const dryRun  = !process.argv.includes('--commit');

const MIME = { '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp' };

(async () => {
  if (!name || !owner) {
    console.error('Uso: node create_gym.js --name "Nombre" --owner email [--logo archivo] [--commit]');
    process.exit(1);
  }
  let contentType;
  if (logo) {
    contentType = MIME[path.extname(logo).toLowerCase()];
    if (!contentType) throw new Error('El logo debe ser .png, .jpg o .webp');
    if (!fs.existsSync(logo)) throw new Error(`No existe el archivo ${logo}`);
    if (fs.statSync(logo).size >= 1024 * 1024) throw new Error('El logo debe pesar menos de 1 MB');
  }

  console.log(`\n🏋️  create_gym — modo: ${dryRun ? 'DRY RUN' : 'COMMIT'}\n`);

  const app = initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
  const db  = getFirestore(app, DATABASE_ID);

  const user = await getAuth(app).getUserByEmail(owner);
  console.log(`Dueño: ${owner} (uid ${user.uid})`);

  const existing = await db.collection('gyms').where('ownerUid', '==', user.uid).limit(1).get();
  if (!existing.empty) {
    const g = existing.docs[0];
    throw new Error(`Esa cuenta ya administra el gimnasio "${g.data().name}" (${g.id})`);
  }

  const ref = db.collection('gyms').doc();
  console.log(`Gimnasio: "${name}" → gyms/${ref.id}`);

  let logoUrl = null;
  if (logo) {
    const dest = `gym_logos/${user.uid}/logo_${Date.now()}`;
    console.log(`Logo: ${logo} → ${dest}`);
    if (!dryRun) {
      const file = getStorage(app).bucket(BUCKET).file(dest);
      await file.save(fs.readFileSync(logo), { contentType });
      logoUrl = await getDownloadURL(file);
    }
  }

  if (!dryRun) {
    await ref.set({
      name,
      ownerUid: user.uid,
      logoUrl,
      city: '',
      address: '',
      phone: '',
      cancelWindowHours: 2,
      status: 'active',
      createdAt: FieldValue.serverTimestamp(),
    });
  }

  console.log(
    `\n${dryRun
      ? '🔎 Dry run terminado. Para crearlo de verdad agrega --commit'
      : `✅ Gimnasio creado. ${owner} verá el ícono "Mi gimnasio" en el home.`}\n`
  );
  process.exit(0);
})().catch(err => {
  console.error('\n❌ Error:', err.message ?? err);
  process.exit(1);
});
