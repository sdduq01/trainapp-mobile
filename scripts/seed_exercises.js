/**
 * Sube los ejercicios del catálogo a Firestore.
 * Valida duplicados por ID de documento y por nombre antes de escribir.
 *
 * Uso:
 *   node seed_exercises.js            → modo dry-run (solo muestra qué haría)
 *   node seed_exercises.js --commit   → escribe en Firestore
 *
 * Autenticación: Application Default Credentials
 *   gcloud auth application-default login
 */

const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore }                       = require('firebase-admin/firestore');

const PROJECT_ID  = 'trainapp-prod';
const DATABASE_ID = 'trainapp';
const COLLECTION  = 'exercises';

// ── Catálogo local ────────────────────────────────────────────────────────────
// Sincronizado con lib/workout/data/exercise_catalog.dart
const catalog = [
  // PUSH · Pecho
  { id: 'press_banca',        name: 'Press de Banca',                  muscle: 'push', defaultSets: 4, defaultRepsMin: 8,  defaultRepsMax: 12, restSeconds: 120, defaultWeightUnit: 'kg',  defaultProgressionStep: 2.5 },
  { id: 'press_inclinado',    name: 'Press Inclinado con Mancuernas',  muscle: 'push', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12, restSeconds: 90,  defaultWeightUnit: 'kg',  defaultProgressionStep: 2.5 },
  { id: 'aperturas_cable',    name: 'Aperturas en Cable',              muscle: 'push', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 15, restSeconds: 60,  defaultWeightUnit: 'kg',  defaultProgressionStep: 2.5 },
  { id: 'press_maquina',      name: 'Press de Pecho en Máquina',       muscle: 'push', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12, restSeconds: 75,  defaultWeightUnit: 'kg',  defaultProgressionStep: 5   },

  // PUSH · Hombros
  { id: 'press_militar',      name: 'Press Militar',                   muscle: 'push', defaultSets: 4, defaultRepsMin: 8,  defaultRepsMax: 10, restSeconds: 90,  defaultWeightUnit: 'kg',  defaultProgressionStep: 2.5 },
  { id: 'elev_laterales',     name: 'Elevaciones Laterales',           muscle: 'push', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 15, restSeconds: 60,  defaultWeightUnit: 'kg',  defaultProgressionStep: 1.25 },
  { id: 'elev_frontales',     name: 'Elevaciones Frontales',           muscle: 'push', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 15, restSeconds: 60,  defaultWeightUnit: 'kg',  defaultProgressionStep: 1.25 },

  // PUSH · Tríceps
  { id: 'fondos_triceps',     name: 'Fondos para Tríceps',             muscle: 'push', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 15, restSeconds: 60,  defaultWeightUnit: 'kg',  defaultProgressionStep: 2.5 },
  { id: 'ext_triceps_cable',  name: 'Extensión de Tríceps en Cable',   muscle: 'push', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 15, restSeconds: 60,  defaultWeightUnit: 'kg',  defaultProgressionStep: 2.5 },
  { id: 'press_frances',      name: 'Press Francés',                   muscle: 'push', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12, restSeconds: 75,  defaultWeightUnit: 'kg',  defaultProgressionStep: 2.5 },

  // PULL · Espalda
  { id: 'jalon_pecho',        name: 'Jalón al Pecho',                  muscle: 'pull', defaultSets: 4, defaultRepsMin: 8,  defaultRepsMax: 12, restSeconds: 90,  defaultWeightUnit: 'kg',  defaultProgressionStep: 5   },
  { id: 'remo_barra',         name: 'Remo con Barra',                  muscle: 'pull', defaultSets: 4, defaultRepsMin: 8,  defaultRepsMax: 10, restSeconds: 90,  defaultWeightUnit: 'kg',  defaultProgressionStep: 5   },
  { id: 'remo_mancuerna',     name: 'Remo con Mancuerna',              muscle: 'pull', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12, restSeconds: 75,  defaultWeightUnit: 'kg',  defaultProgressionStep: 2.5 },
  { id: 'remo_cable',         name: 'Remo en Cable',                   muscle: 'pull', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12, restSeconds: 75,  defaultWeightUnit: 'kg',  defaultProgressionStep: 2.5 },
  { id: 'face_pull',          name: 'Face Pull',                       muscle: 'pull', defaultSets: 3, defaultRepsMin: 15, defaultRepsMax: 20, restSeconds: 60,  defaultWeightUnit: 'kg',  defaultProgressionStep: 2.5 },

  // PULL · Bíceps
  { id: 'curl_barra',         name: 'Curl de Bíceps con Barra',        muscle: 'pull', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12, restSeconds: 60,  defaultWeightUnit: 'kg',  defaultProgressionStep: 2.5 },
  { id: 'curl_martillo',      name: 'Curl Martillo',                   muscle: 'pull', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12, restSeconds: 60,  defaultWeightUnit: 'kg',  defaultProgressionStep: 2.5 },
  { id: 'curl_concentrado',   name: 'Curl Concentrado',                muscle: 'pull', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 15, restSeconds: 60,  defaultWeightUnit: 'kg',  defaultProgressionStep: 1.25 },

  // LEGS
  { id: 'sentadilla',         name: 'Sentadilla con Barra',            muscle: 'legs', defaultSets: 4, defaultRepsMin: 8,  defaultRepsMax: 12, restSeconds: 120, defaultWeightUnit: 'kg',  defaultProgressionStep: 5   },
  { id: 'prensa_piernas',     name: 'Prensa de Piernas',               muscle: 'legs', defaultSets: 4, defaultRepsMin: 10, defaultRepsMax: 12, restSeconds: 90,  defaultWeightUnit: 'kg',  defaultProgressionStep: 10  },
  { id: 'ext_cuadriceps',     name: 'Extensión de Cuádriceps',         muscle: 'legs', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 15, restSeconds: 60,  defaultWeightUnit: 'kg',  defaultProgressionStep: 5   },
  { id: 'curl_isquio',        name: 'Curl de Isquiotibiales',          muscle: 'legs', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 15, restSeconds: 60,  defaultWeightUnit: 'kg',  defaultProgressionStep: 5   },
  { id: 'peso_muerto_rumano', name: 'Peso Muerto Rumano',              muscle: 'legs', defaultSets: 4, defaultRepsMin: 8,  defaultRepsMax: 12, restSeconds: 90,  defaultWeightUnit: 'kg',  defaultProgressionStep: 5   },
  { id: 'zancadas',           name: 'Zancadas',                        muscle: 'legs', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12, restSeconds: 75,  defaultWeightUnit: 'kg',  defaultProgressionStep: 2.5 },
  { id: 'elev_talones',       name: 'Elevación de Talones',            muscle: 'legs', defaultSets: 4, defaultRepsMin: 15, defaultRepsMax: 20, restSeconds: 60,  defaultWeightUnit: 'kg',  defaultProgressionStep: 5   },
];

// ── Validación interna del catálogo ───────────────────────────────────────────

function validateCatalog(exercises) {
  const ids   = exercises.map(e => e.id);
  const names = exercises.map(e => e.name.toLowerCase());

  const dupIds   = ids.filter((id, i) => ids.indexOf(id) !== i);
  const dupNames = names.filter((n, i) => names.indexOf(n) !== i);

  if (dupIds.length || dupNames.length) {
    console.error('\n❌ El catálogo local tiene duplicados:');
    dupIds.forEach(id => console.error(`   ID repetido: "${id}"`));
    dupNames.forEach(n => console.error(`   Nombre repetido: "${n}"`));
    process.exit(1);
  }
}

// ── Main ──────────────────────────────────────────────────────────────────────

async function main() {
  const commit = process.argv.includes('--commit');

  console.log(`\nTrainApp · Seed Exercises`);
  console.log(`Proyecto : ${PROJECT_ID}`);
  console.log(`Base de datos: ${DATABASE_ID}`);
  console.log(`Modo   : ${commit ? '✍️  COMMIT (escribe en Firestore)' : '🔍 DRY-RUN (solo lectura)'}\n`);

  // 1. Validar catálogo local antes de cualquier llamada a Firestore
  console.log('─── Validando catálogo local...');
  validateCatalog(catalog);
  console.log(`    ${catalog.length} ejercicios · sin duplicados internos ✓\n`);

  // 2. Conectar a Firestore
  const app = initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
  const db  = getFirestore(app, DATABASE_ID);

  // 3. Leer ejercicios existentes en Firestore
  console.log('─── Leyendo colección existente en Firestore...');
  const snap = await db.collection(COLLECTION).get();

  const existingIds   = new Set(snap.docs.map(d => d.id));
  const existingNames = new Set(snap.docs.map(d => (d.data().name || '').toLowerCase()));

  console.log(`    ${existingIds.size} ejercicios encontrados en Firestore\n`);

  // 4. Clasificar ejercicios del catálogo
  const toInsert   = [];
  const skipById   = [];
  const skipByName = [];

  for (const ex of catalog) {
    if (existingIds.has(ex.id)) {
      skipById.push(ex);
    } else if (existingNames.has(ex.name.toLowerCase())) {
      skipByName.push(ex);
    } else {
      toInsert.push(ex);
    }
  }

  // 5. Reporte de duplicados
  if (skipById.length) {
    console.log(`⚠️  Omitidos por ID ya existente (${skipById.length}):`);
    skipById.forEach(e => console.log(`   [${e.id}] ${e.name}`));
    console.log();
  }

  if (skipByName.length) {
    console.log(`⚠️  Omitidos por nombre ya existente (${skipByName.length}):`);
    skipByName.forEach(e => console.log(`   [${e.id}] ${e.name}`));
    console.log();
  }

  if (!toInsert.length) {
    console.log('✅ No hay ejercicios nuevos para subir. Colección ya está al día.');
    process.exit(0);
  }

  // 6. Mostrar qué se va a escribir
  console.log(`📋 Ejercicios a subir (${toInsert.length}):`);
  toInsert.forEach(e => console.log(`   [${e.id}] ${e.name} · ${e.muscle}`));
  console.log();

  if (!commit) {
    console.log('ℹ️  Dry-run finalizado. Ejecuta con --commit para escribir en Firestore.');
    process.exit(0);
  }

  // 7. Escribir en batch (máx 500 operaciones por batch en Firestore)
  const BATCH_SIZE = 499;
  let written = 0;

  for (let i = 0; i < toInsert.length; i += BATCH_SIZE) {
    const chunk = toInsert.slice(i, i + BATCH_SIZE);
    const batch = db.batch();

    for (const ex of chunk) {
      const { id, ...data } = ex;
      batch.set(db.collection(COLLECTION).doc(id), data);
    }

    await batch.commit();
    written += chunk.length;
    console.log(`   Batch ${Math.floor(i / BATCH_SIZE) + 1}: ${chunk.length} escritos`);
  }

  console.log(`\n✅ ${written} ejercicios subidos a Firestore correctamente.`);
}

main().catch(err => {
  console.error('\n❌ Error:', err.message || err);
  process.exit(1);
});
