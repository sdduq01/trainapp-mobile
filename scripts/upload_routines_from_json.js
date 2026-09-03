/**
 * Sube plantillas de rutina (.json) a Firestore desde una carpeta externa.
 *
 * Carpeta por defecto:
 *   ./scripts/routines_templates
 * (se puede override con la variable de entorno ROUTINES_DIR)
 *
 * Comportamiento:
 *   - Lee todos los .json del directorio (ignora los que empiezan con "_").
 *   - Valida estructura mínima.
 *   - Compara contra Firestore por ID (derivado del nombre o campo `id`).
 *   - Si ya existe → reemplaza el documento en Firestore con el JSON local.
 *   - Si es nuevo → inserta.
 *
 * Uso (desde el directorio del proyecto):
 *   node scripts/upload_routines_from_json.js            → dry-run
 *   node scripts/upload_routines_from_json.js --commit   → escribe en Firestore
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
const COLLECTION  = 'routine_templates';

const DEFAULT_DIR = './scripts/routines_templates';
const ROUTINES_DIR = process.env.ROUTINES_DIR || DEFAULT_DIR;

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
    console.error('   Crea la carpeta o define ROUTINES_DIR=/ruta/a/tus/rutinas');
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

const VALID_CATEGORIES = ['recommended', 'sport', 'macro', 'limited'];
const VALID_PROGRESSION_TYPES = ['none', 'doubleLinear', 'pyramid', 'reversePyramid'];

function validateRoutine(file, r) {
  const errs = [];
  if (!r.category || !VALID_CATEGORIES.includes(r.category)) {
    errs.push(`category debe ser uno de: ${VALID_CATEGORIES.join(', ')}`);
  }
  if (!r.name || typeof r.name !== 'string' || !r.name.trim()) {
    errs.push(`name vacío`);
  }
  if (typeof r.description !== 'string') {
    errs.push(`description debe ser string`);
  }
  if (!r.type || typeof r.type !== 'string') {
    errs.push(`type vacío (ej: PPL, UpperLower, FullBody, Sport, Custom)`);
  }
  if (r.category === 'sport' && !r.sport) {
    errs.push(`category="sport" requiere campo "sport" (ej: "futbol")`);
  }
  if (!Array.isArray(r.days) || r.days.length === 0) {
    errs.push(`days debe ser array no vacío`);
  } else {
    r.days.forEach((d, i) => {
      if (typeof d.dayNumber !== 'number') errs.push(`days[${i}].dayNumber faltante`);
      if (!d.name)  errs.push(`days[${i}].name faltante`);
      if (!d.focus) errs.push(`days[${i}].focus faltante`);
      if (!Array.isArray(d.exercises) || d.exercises.length === 0) {
        errs.push(`days[${i}].exercises vacío`);
      } else {
        d.exercises.forEach((e, j) => {
          const need = ['exerciseId', 'name', 'sets', 'repsMin', 'repsMax', 'restSeconds'];
          for (const k of need) {
            if (e[k] === undefined || e[k] === null) {
              errs.push(`days[${i}].exercises[${j}].${k} faltante`);
            }
          }
          if (e.repsMax !== undefined && e.repsMin !== undefined && e.repsMax < e.repsMin) {
            errs.push(`days[${i}].exercises[${j}]: repsMax (${e.repsMax}) < repsMin (${e.repsMin})`);
          }
          if (e.progressionType !== undefined &&
              !VALID_PROGRESSION_TYPES.includes(e.progressionType)) {
            errs.push(`days[${i}].exercises[${j}]: progressionType debe ser uno de: ${VALID_PROGRESSION_TYPES.join(', ')}`);
          }
          if (e.isIsometric !== undefined && typeof e.isIsometric !== 'boolean') {
            errs.push(`days[${i}].exercises[${j}]: isIsometric debe ser boolean`);
          }
        });
      }
    });
  }

  if (errs.length) {
    console.error(`\n❌ Validación falló en ${file}:`);
    errs.forEach(e => console.error(`   · ${e}`));
    process.exit(1);
  }
}

// Normaliza al esquema que espera la app (defaults para campos opcionales).
function normalize(r) {
  const days = r.days.map(d => ({
    dayNumber: d.dayNumber,
    name: d.name,
    focus: d.focus,
    exercises: d.exercises.map(e => ({
      exerciseId:      e.exerciseId,
      name:            e.name,
      sets:            e.sets,
      repsMin:         e.repsMin,
      repsMax:         e.repsMax,
      currentWeight:   e.currentWeight ?? 0,
      restSeconds:     e.restSeconds,
      weightUnit:      e.weightUnit ?? 'kg',
      progressionStep: e.progressionStep ?? 2.5,
      progressionType: e.progressionType ?? 'doubleLinear',
      isIsometric:     e.isIsometric ?? false,
    })),
  }));

  const docId = (r.id && r.id.trim()) || slugify(r.name);

  const out = {
    docId,
    data: {
      category:    r.category,
      name:        r.name.trim(),
      description: (r.description || '').trim(),
      type:        r.type,
      days,
    },
  };
  if (r.sport) out.data.sport = r.sport;
  return out;
}

// ── Main ────────────────────────────────────────────────────────────────────

async function main() {
  const commit = process.argv.includes('--commit');

  console.log(`\nTrainApp · Upload Routines from JSON`);
  console.log(`Proyecto       : ${PROJECT_ID}`);
  console.log(`Base de datos  : ${DATABASE_ID}`);
  console.log(`Carpeta origen : ${ROUTINES_DIR}`);
  console.log(`Modo           : ${commit ? '✍️  COMMIT (escribe en Firestore)' : '🔍 DRY-RUN (solo lectura)'}\n`);

  // 1. Cargar y validar JSONs locales
  console.log('─── Leyendo archivos .json...');
  const files = loadJsonFiles(ROUTINES_DIR);
  if (files.length === 0) {
    console.log(`    No hay archivos .json en la carpeta (excluyendo los que empiezan con "_").`);
    process.exit(0);
  }
  console.log(`    ${files.length} archivo(s) encontrado(s)\n`);

  const items = [];
  for (const { file, data } of files) {
    validateRoutine(file, data);
    items.push({ file, ...normalize(data) });
  }

  // 2. Detectar duplicados internos por NAME
  const localNames = new Map();
  for (const it of items) {
    const key = it.data.name.toLowerCase();
    if (localNames.has(key)) {
      console.error(`\n❌ Duplicado de NAME entre archivos locales:`);
      console.error(`   "${it.data.name}" en ${localNames.get(key)} y ${it.file}`);
      process.exit(1);
    }
    localNames.set(key, it.file);
  }
  console.log(`─── Validación local OK (${items.length} rutinas, sin duplicados de nombre)\n`);

  // 3. Conectar a Firestore y leer nombres existentes
  const app = initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
  const db  = getFirestore(app, DATABASE_ID);

  console.log('─── Leyendo colección existente en Firestore...');
  const snap = await db.collection(COLLECTION).get();
  const existingIds = new Set(snap.docs.map(d => d.id));
  console.log(`    ${existingIds.size} rutina(s) en Firestore\n`);

  // 4. Clasificar
  const toInsert = [];
  const toUpdate = [];
  for (const it of items) {
    if (existingIds.has(it.docId)) {
      toUpdate.push(it);
    } else {
      toInsert.push(it);
    }
  }

  if (toUpdate.length) {
    console.log(`🔄 Rutinas a reemplazar (${toUpdate.length}):`);
    toUpdate.forEach(t => {
      const tag = t.data.category === 'sport' ? `sport:${t.data.sport}` : t.data.category;
      console.log(`   [${t.docId}] "${t.data.name}" · ${tag} · ${t.data.days.length} días`);
    });
    console.log();
  }
  if (toInsert.length) {
    console.log(`📋 Rutinas nuevas a subir (${toInsert.length}):`);
    toInsert.forEach(t => {
      const tag = t.data.category === 'sport' ? `sport:${t.data.sport}` : t.data.category;
      console.log(`   [${t.docId}] "${t.data.name}" · ${tag} · ${t.data.days.length} días`);
    });
    console.log();
  }

  const toWrite = [...toInsert, ...toUpdate];

  if (!toWrite.length) {
    console.log('✅ No hay rutinas para subir.');
    process.exit(0);
  }

  if (!commit) {
    console.log('ℹ️  Dry-run finalizado. Ejecuta con --commit para escribir en Firestore.');
    process.exit(0);
  }

  // 5. Escribir en batch
  const batch = db.batch();
  for (const t of toWrite) {
    batch.set(db.collection(COLLECTION).doc(t.docId), t.data);
  }
  await batch.commit();

  console.log(`\n✅ ${toInsert.length} nueva(s), ${toUpdate.length} reemplazada(s) — total ${toWrite.length} rutina(s) escritas en Firestore.`);
}

main().catch(err => {
  console.error('\n❌ Error:', err.message || err);
  process.exit(1);
});
