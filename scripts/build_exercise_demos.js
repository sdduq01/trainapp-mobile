/**
 * Demostraciones de ejercicios (WebP animado de 2 cuadros, ~35 KB).
 *
 * Fuente inicial: ilustraciones de Everkinetic (github.com/everkinetic/data,
 * CC BY-SA 4.0): posición inicial y final de cada ejercicio, alternadas.
 * El cruce con el catálogo está en exercise_demos/everkinetic_map.json.
 *
 * Cada demostración se sube a Storage en `exercise_demos/{exerciseId}.webp`
 * (lectura pública, ver storage.rules) y el doc `exercises/{exerciseId}`
 * recibe `demoUrl` (con ?v= para refrescar la caché de la app) y
 * `demoCredit` (texto de atribución; vacío si el clip es propio).
 *
 * Uso (desde la raíz del proyecto):
 *   node scripts/build_exercise_demos.js                 → genera en exercise_demos/out + hoja de revisión
 *   node scripts/build_exercise_demos.js --commit        → además sube a Storage y actualiza Firestore
 *
 * Reemplazar por un clip propio (WebP/GIF/PNG ya listo):
 *   node scripts/build_exercise_demos.js --own press_banca=/ruta/press_banca.webp --commit
 *   (sube el archivo tal cual, deja demoCredit vacío y cambia la versión)
 *
 * Autenticación: Application Default Credentials
 *   gcloud auth application-default login
 */

const fs    = require('fs');
const path  = require('path');
const sharp = require('sharp');

const PROJECT_ID  = 'trainapp-prod';
const DATABASE_ID = 'trainapp';
const BUCKET      = 'trainapp-prod.firebasestorage.app';

// Commit fijo del repo de Everkinetic (no cambia lo que se descarga).
const EK_COMMIT = '6f3ce86eb79b17e7bbaf588b7960149725bc8fc7';
const EK_PNG    = id => `https://raw.githubusercontent.com/everkinetic/data/${EK_COMMIT}/dist/png/${id}`;
const EK_CREDIT = 'Ilustración adaptada de Everkinetic · CC BY-SA 4.0';

const DIR      = path.join(__dirname, 'exercise_demos');
const OUT      = path.join(DIR, 'out');
const CACHE    = path.join(DIR, '.cache');
const WIDTH    = 480;
const HEIGHT   = 420;
const FRAME_MS = 900;

const args   = process.argv.slice(2);
const COMMIT = args.includes('--commit');
const OWN    = args.filter((a, i) => args[i - 1] === '--own');

async function download(name) {
  fs.mkdirSync(CACHE, { recursive: true });
  const file = path.join(CACHE, name);
  if (!fs.existsSync(file)) {
    const res = await fetch(EK_PNG(name));
    if (!res.ok) throw new Error(`${name}: HTTP ${res.status}`);
    fs.writeFileSync(file, Buffer.from(await res.arrayBuffer()));
  }
  return file;
}

/** Posición inicial y final alternadas, fondo blanco, 480 px de ancho. */
async function buildEverkinetic(exerciseId, ekId) {
  // Los dos cuadros pueden tener distinta proporción: se encajan en el
  // mismo lienzo para que la figura no salte.
  const load = async f => sharp(await download(f))
    .flatten({ background: '#ffffff' })
    .resize({ width: WIDTH, height: HEIGHT, fit: 'contain', background: '#ffffff' })
    .raw()
    .toBuffer({ resolveWithObject: true });
  const a = await load(`${ekId}-relaxation.png`);
  const b = await load(`${ekId}-tension.png`);
  const { width, height, channels } = a.info;
  const out = path.join(OUT, `${exerciseId}.webp`);
  await sharp(Buffer.concat([a.data, b.data]), {
    raw: { width, height: height * 2, channels, pageHeight: height },
  })
    .webp({ quality: 85, effort: 6, loop: 0, delay: [FRAME_MS, FRAME_MS] })
    .toFile(out);
  // Miniatura para la hoja de revisión.
  const thumb = await sharp(b.data, { raw: { width, height, channels } })
    .resize({ width: 200, height: 180, fit: 'contain', background: '#ffffff' })
    .png()
    .toBuffer();
  return { out, thumb };
}

/** Hoja con todas las miniaturas y su exerciseId, para revisar el cruce. */
async function contactSheet(items) {
  const cols = 6, cw = 210, ch = 210;
  const rows = Math.ceil(items.length / cols);
  const esc = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;');
  const composites = [];
  items.forEach((it, i) => {
    const x = (i % cols) * cw, y = Math.floor(i / cols) * ch;
    composites.push({ input: it.thumb, left: x + 5, top: y });
    composites.push({
      input: Buffer.from(`<svg width="${cw}" height="24"><text x="5" y="16" font-size="12" font-family="sans-serif">${esc(it.id)} (${it.ek})</text></svg>`),
      left: x, top: y + 184,
    });
  });
  const file = path.join(DIR, 'revision.png');
  await sharp({ create: { width: cols * cw, height: rows * ch, channels: 3, background: '#ffffff' } })
    .composite(composites)
    .png()
    .toFile(file);
  return file;
}

async function upload(entries) {
  const { initializeApp, applicationDefault } = require('firebase-admin/app');
  const { getFirestore, FieldValue }          = require('firebase-admin/firestore');
  const { getStorage }                        = require('firebase-admin/storage');
  const app    = initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID, storageBucket: BUCKET });
  const db     = getFirestore(app, DATABASE_ID);
  const bucket = getStorage(app).bucket();

  for (const e of entries) {
    const ref  = db.collection('exercises').doc(e.id);
    const snap = await ref.get();
    if (!snap.exists) {
      console.warn(`  ⚠ ${e.id}: no existe en Firestore, se omite`);
      continue;
    }
    const version = ((snap.data().demoVersion) || 0) + 1;
    const dest = `exercise_demos/${e.id}.webp`;
    await bucket.upload(e.file, {
      destination: dest,
      metadata: {
        contentType: e.contentType || 'image/webp',
        cacheControl: 'public, max-age=86400',
      },
    });
    const demoUrl = `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/` +
      `${encodeURIComponent(dest)}?alt=media&v=${version}`;
    await ref.update({
      demoUrl,
      demoCredit: e.credit,
      demoVersion: version,
      demoUpdatedAt: FieldValue.serverTimestamp(),
    });
    console.log(`  ✓ ${e.id} (v${version})`);
  }
}

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const entries = [];

  if (OWN.length) {
    for (const spec of OWN) {
      const [id, file] = spec.split('=');
      if (!id || !file || !fs.existsSync(file)) throw new Error(`--own inválido: ${spec}`);
      const ext = path.extname(file).toLowerCase();
      const contentType = { '.webp': 'image/webp', '.gif': 'image/gif', '.png': 'image/png' }[ext];
      if (!contentType) throw new Error(`${file}: usa .webp, .gif o .png`);
      entries.push({ id, file, credit: '', contentType });
      console.log(`Propio: ${id} ← ${file} (${(fs.statSync(file).size / 1024).toFixed(0)} KB)`);
    }
  } else {
    const map = JSON.parse(fs.readFileSync(path.join(DIR, 'everkinetic_map.json'), 'utf8'));
    delete map._comment;
    const items = [];
    let bytes = 0;
    for (const [id, ek] of Object.entries(map)) {
      const { out, thumb } = await buildEverkinetic(id, ek);
      bytes += fs.statSync(out).size;
      items.push({ id, ek, thumb });
      entries.push({ id, file: out, credit: EK_CREDIT });
    }
    const sheet = await contactSheet(items);
    console.log(`Generados ${entries.length} WebP (${(bytes / 1024).toFixed(0)} KB en total) en ${OUT}`);
    console.log(`Revisa el cruce en ${sheet}`);
  }

  if (!COMMIT) {
    console.log('\nDry-run: nada se subió. Agrega --commit para subir a Storage y actualizar Firestore.');
    return;
  }
  console.log('\nSubiendo…');
  await upload(entries);
  console.log('Listo.');
})().catch(err => {
  console.error(err);
  process.exit(1);
});
