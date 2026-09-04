/**
 * Sube ejercicios (.json) a Firestore desde una carpeta externa.
 *
 * Carpeta por defecto:
 *   ./scripts/exercises_templates
 * (override con la variable de entorno EXERCISES_DIR)
 *
 * Comportamiento:
 *   - Lee todos los .json del directorio (ignora los que empiezan con "_").
 *   - Valida estructura mínima.
 *   - Compara contra Firestore por ID y por NOMBRE (case-insensitive).
 *   - Si el ID ya existe → reemplaza el documento en Firestore con el JSON local.
 *   - Si el nombre ya existe con distinto ID → advierte y escribe con el nuevo ID.
 *   - Si es nuevo → inserta.
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

const DEFAULT_DIR  = './scripts/exercises_templates';
const EXERCISES_DIR = process.env.EXERCISES_DIR || DEFAULT_DIR;

const VALID_MUSCLES = ['push', 'pull', 'legs'];
const VALID_MUSCLE_GROUPS = [
  'pecho', 'espalda', 'hombros', 'trapecios',
  'biceps', 'triceps', 'antebrazo',
  'cuadriceps', 'femorales', 'gluteos', 'gemelos', 'abductores', 'aductores',
  'abdominales', 'cardio', 'estiramiento', 'otros',
];
const VALID_UNITS   = ['kg', 'lbs', 'unidades'];
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
  if (!e.muscleGroup || !VALID_MUSCLE_GROUPS.includes(e.muscleGroup)) {
    errs.push(`muscleGroup debe ser uno de: ${VALID_MUSCLE_GROUPS.join(', ')}`);
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
    errs.push(`defaultWeightUnit debe ser uno de: ${VALID_UNITS.join(', ')}`);
  }
  if (e.defaultProgressionStep !== undefined &&
      !VALID_STEPS.includes(Number(e.defaultProgressionStep))) {
    errs.push(`defaultProgressionStep debe ser uno de: ${VALID_STEPS.join(', ')}`);
  }
  if (e.id !== undefined && e.id !== null && e.id !== '' && !/^[a-z0-9_]+$/.test(e.id)) {
    errs.push(`id "${e.id}" debe ser snake_case (solo a-z, 0-9, _)`);
  }
  if (e.isIsometric !== undefined && typeof e.isIsometric !== 'boolean') {
    errs.push(`isIsometric debe ser boolean`);
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
      muscleGroup:            e.muscleGroup,
      defaultSets:            e.defaultSets,
      defaultRepsMin:         e.defaultRepsMin,
      defaultRepsMax:         e.defaultRepsMax,
      restSeconds:            e.restSeconds,
      defaultWeightUnit:      e.defaultWeightUnit ?? 'kg',
      defaultProgressionStep: e.defaultProgressionStep ?? 2.5,
      isIsometric:            e.isIsometric ?? false,
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

  const toInsert       = [];
  const toUpdate       = [];
  const nameConflict   = [];
  for (const it of items) {
    if (existingIds.has(it.docId)) {
      toUpdate.push(it);
    } else if (existingNames.has(it.data.name.toLowerCase().trim())) {
      nameConflict.push(it);
    } else {
      toInsert.push(it);
    }
  }

  if (nameConflict.length) {
    console.log(`⚠️  Nombre ya existe con distinto ID — se escribirá con el nuevo ID (${nameConflict.length}):`);
    nameConflict.forEach(s => console.log(`   [${s.file}] id="${s.docId}" name="${s.data.name}"`));
    console.log();
  }
  if (toUpdate.length) {
    console.log(`🔄 Ejercicios a reemplazar (${toUpdate.length}):`);
    toUpdate.forEach(t => console.log(`   [${t.docId}] "${t.data.name}" · ${t.data.muscle} · ${t.data.muscleGroup}`));
    console.log();
  }
  if (toInsert.length) {
    console.log(`📋 Ejercicios nuevos a subir (${toInsert.length}):`);
    toInsert.forEach(t => console.log(`   [${t.docId}] "${t.data.name}" · ${t.data.muscle} · ${t.data.muscleGroup}`));
    console.log();
  }

  const toWrite = [...toInsert, ...toUpdate, ...nameConflict];

  if (!toWrite.length) {
    console.log('✅ No hay ejercicios para subir.');
    process.exit(0);
  }

  if (!commit) {
    console.log('ℹ️  Dry-run finalizado. Ejecuta con --commit para escribir en Firestore.');
    process.exit(0);
  }

  const batch = db.batch();
  for (const t of toWrite) {
    batch.set(db.collection(COLLECTION).doc(t.docId), t.data);
  }
  await batch.commit();

  console.log(`\n✅ ${toInsert.length} nuevo(s), ${toUpdate.length} reemplazado(s), ${nameConflict.length} con ID nuevo — total ${toWrite.length} ejercicio(s) escritos en Firestore.`);
}

main().catch(err => {
  console.error('\n❌ Error:', err.message || err);
  process.exit(1);
});
