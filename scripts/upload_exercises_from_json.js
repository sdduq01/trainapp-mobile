/**
 * Sube ejercicios (.json) a Firestore desde una carpeta externa.
 *
 * Carpeta por defecto:
 *   /mnt/c/Users/sdduq/OneDrive/Documentos/TrainApp/Ejercicios
 * (override con la variable de entorno EXERCISES_DIR)
 *
 * Comportamiento:
 *   - Lee todos los .json del directorio (ignora los que empiezan con "_").
 *   - Valida estructura mínima.
 *   - Compara contra Firestore por ID y por NOMBRE (case-insensitive).
 *   - Sube solo los ejercicios cuyo id Y nombre no existan todavía.
 *
 * Uso (desde el directorio del proyecto):
 *   node scripts/upload_exercises_from_json.js            → dry-run
 *   node scripts/upload_exercises_from_json.js --commit   → escribe en Firestore
 *
 * Autenticación: Application Default Credentials
 *   gcloud auth application-default login
 */

const fs   = require('fs');
const path = require('path');
const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore }                       = require('firebase-admin/firestore');

const PROJECT_ID  = 'trainapp-prod';
const DATABASE_ID = 'trainapp';
const COLLECTION  = 'exercises';

const DEFAULT_DIR  = '/mnt/c/Users/sdduq/OneDrive/Documentos/TrainApp/Ejercicios';
const EXERCISES_DIR = process.env.EXERCISES_DIR || DEFAULT_DIR;

const VALID_MUSCLES = ['push', 'pull', 'legs'];
const VALID_UNITS   = ['kg', 'lbs'];
const VALID_STEPS   = [1.0, 1.25, 2.5, 5.0, 10.0];

// ── Helpers ─────────────────────────────────────────────────────────────────

function slugify(s) {
  return s
    .toString()
    .toLowerCase()
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 60);
}

function loadJsonFiles(dir) {
  if (!fs.existsSync(dir)) {
    console.error(`\n❌ La carpeta no existe: ${dir}`);
    console.error('   Crea la carpeta o define EXERCISES_DIR=/ruta/a/tus/ejercicios');
    process.exit(1);
  }
  const files = fs.readdirSync(dir)
    .filter(f => f.endsWith('.json'))
    .filter(f => !f.startsWith('_'));

  return files.map(file => {
    const full = path.join(dir, file);
    let data;
    try {
      data = JSON.parse(fs.readFileSync(full, 'utf8'));
    } catch (e) {
      console.error(`\n❌ JSON inválido en ${file}: ${e.message}`);
      process.exit(1);
    }
    return { file, data };
  });
}

function validateExercise(file, e) {
  const errs = [];
  if (!e.name || typeof e.name !== 'string' || !e.name.trim()) {
    errs.push(`name vacío`);
  }
  if (!e.muscle || !VALID_MUSCLES.includes(e.muscle)) {
    errs.push(`muscle debe ser uno de: ${VALID_MUSCLES.join(', ')}`);
  }
  for (const k of ['defaultSets', 'defaultRepsMin', 'defaultRepsMax', 'restSeconds']) {
    if (typeof e[k] !== 'number' || e[k] <= 0) {
      errs.push(`${k} debe ser número > 0`);
    }
  }
  if (typeof e.defaultRepsMin === 'number' && typeof e.defaultRepsMax === 'number'
      && e.defaultRepsMax < e.defaultRepsMin) {
    errs.push(`defaultRepsMax (${e.defaultRepsMax}) < defaultRepsMin (${e.defaultRepsMin})`);
  }
  if (e.defaultWeightUnit !== undefined && !VALID_UNITS.includes(e.defaultWeightUnit)) {
    errs.push(`defaultWeightUnit debe ser "kg" o "lbs"`);
  }
  if (e.defaultProgressionStep !== undefined &&
      !VALID_STEPS.includes(Number(e.defaultProgressionStep))) {
    errs.push(`defaultProgressionStep debe ser uno de: ${VALID_STEPS.join(', ')}`);
  }
  if (e.id !== undefined && e.id !== null && e.id !== '' && !/^[a-z0-9_]+$/.test(e.id)) {
    errs.push(`id "${e.id}" debe ser snake_case (solo a-z, 0-9, _)`);
  }

  if (errs.length) {
    console.error(`\n❌ Validación falló en ${file}:`);
    errs.forEach(err => console.error(`   · ${err}`));
    process.exit(1);
  }
}

function normalize(e) {
  const docId = (e.id && e.id.trim()) || slugify(e.name);
  return {
    docId,
    data: {
      name:                   e.name.trim(),
      muscle:                 e.muscle,
      defaultSets:            e.defaultSets,
      defaultRepsMin:         e.defaultRepsMin,
      defaultRepsMax:         e.defaultRepsMax,
      restSeconds:            e.restSeconds,
      defaultWeightUnit:      e.defaultWeightUnit ?? 'kg',
      defaultProgressionStep: e.defaultProgressionStep ?? 2.5,
    },
  };
}

// ── Main ────────────────────────────────────────────────────────────────────

async function main() {
  const commit = process.argv.includes('--commit');

  console.log(`\nTrainApp · Upload Exercises from JSON`);
  console.log(`Proyecto       : ${PROJECT_ID}`);
  console.log(`Base de datos  : ${DATABASE_ID}`);
  console.log(`Carpeta origen : ${EXERCISES_DIR}`);
  console.log(`Modo           : ${commit ? '✍️  COMMIT (escribe en Firestore)' : '🔍 DRY-RUN (solo lectura)'}\n`);

  console.log('─── Leyendo archivos .json...');
  const files = loadJsonFiles(EXERCISES_DIR);
  if (files.length === 0) {
    console.log(`    No hay archivos .json en la carpeta (excluyendo los que empiezan con "_").`);
    process.exit(0);
  }
  console.log(`    ${files.length} archivo(s) encontrado(s)\n`);

  const items = [];
  for (const { file, data } of files) {
    validateExercise(file, data);
    items.push({ file, ...normalize(data) });
  }

  // Detectar duplicados internos (por id y por name)
  const localIds   = new Map();
  const localNames = new Map();
  for (const it of items) {
    if (localIds.has(it.docId)) {
      console.error(`\n❌ ID duplicado entre archivos locales: "${it.docId}" en ${localIds.get(it.docId)} y ${it.file}`);
      process.exit(1);
    }
    const nameKey = it.data.name.toLowerCase();
    if (localNames.has(nameKey)) {
      console.error(`\n❌ NAME duplicado entre archivos locales: "${it.data.name}" en ${localNames.get(nameKey)} y ${it.file}`);
      process.exit(1);
    }
    localIds.set(it.docId, it.file);
    localNames.set(nameKey, it.file);
  }
  console.log(`─── Validación local OK (${items.length} ejercicios)\n`);

  const app = initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
  const db  = getFirestore(app, DATABASE_ID);

  console.log('─── Leyendo colección existente en Firestore...');
  const snap = await db.collection(COLLECTION).get();
  const existingIds   = new Set(snap.docs.map(d => d.id));
  const existingNames = new Set(snap.docs.map(d => (d.data().name || '').toLowerCase().trim()));
  console.log(`    ${existingIds.size} ejercicios en Firestore\n`);

  const toInsert   = [];
  const skipById   = [];
  const skipByName = [];
  for (const it of items) {
    if (existingIds.has(it.docId)) {
      skipById.push(it);
    } else if (existingNames.has(it.data.name.toLowerCase().trim())) {
      skipByName.push(it);
    } else {
      toInsert.push(it);
    }
  }

  if (skipById.length) {
    console.log(`⚠️  Omitidos por ID ya existente (${skipById.length}):`);
    skipById.forEach(s => console.log(`   [${s.file}] id="${s.docId}"`));
    console.log();
  }
  if (skipByName.length) {
    console.log(`⚠️  Omitidos por NAME ya existente (${skipByName.length}):`);
    skipByName.forEach(s => console.log(`   [${s.file}] name="${s.data.name}"`));
    console.log();
  }

  if (!toInsert.length) {
    console.log('✅ No hay ejercicios nuevos para subir.');
    process.exit(0);
  }

  console.log(`📋 Ejercicios a subir (${toInsert.length}):`);
  toInsert.forEach(t => console.log(`   [${t.docId}] "${t.data.name}" · ${t.data.muscle}`));
  console.log();

  if (!commit) {
    console.log('ℹ️  Dry-run finalizado. Ejecuta con --commit para escribir en Firestore.');
    process.exit(0);
  }

  const batch = db.batch();
  for (const t of toInsert) {
    batch.set(db.collection(COLLECTION).doc(t.docId), t.data);
  }
  await batch.commit();

  console.log(`\n✅ ${toInsert.length} ejercicio(s) subidos a Firestore.`);
}

main().catch(err => {
  console.error('\n❌ Error:', err.message || err);
  process.exit(1);
});
