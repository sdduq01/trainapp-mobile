import '../models/exercise.dart';

const List<Exercise> allExercises = [
  // ── PUSH · Pecho ──────────────────────────────────────────
  Exercise(id: 'press_banca',        name: 'Press de Banca',                  muscle: 'push', defaultSets: 4, defaultRepsMin: 8,  defaultRepsMax: 12, restSeconds: 90),
  Exercise(id: 'press_inclinado',    name: 'Press Inclinado con Mancuernas',  muscle: 'push', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12, restSeconds: 90),
  Exercise(id: 'aperturas_cable',    name: 'Aperturas en Cable',              muscle: 'push', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 15, restSeconds: 60),
  Exercise(id: 'press_maquina',      name: 'Press de Pecho en Máquina',       muscle: 'push', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12, restSeconds: 75),

  // ── PUSH · Hombros ────────────────────────────────────────
  Exercise(id: 'press_militar',      name: 'Press Militar',                   muscle: 'push', defaultSets: 4, defaultRepsMin: 8,  defaultRepsMax: 10, restSeconds: 90),
  Exercise(id: 'elev_laterales',     name: 'Elevaciones Laterales',           muscle: 'push', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 15, restSeconds: 60),
  Exercise(id: 'elev_frontales',     name: 'Elevaciones Frontales',           muscle: 'push', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 15, restSeconds: 60),

  // ── PUSH · Tríceps ────────────────────────────────────────
  Exercise(id: 'fondos_triceps',     name: 'Fondos para Tríceps',             muscle: 'push', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 15, restSeconds: 60),
  Exercise(id: 'ext_triceps_cable',  name: 'Extensión de Tríceps en Cable',   muscle: 'push', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 15, restSeconds: 60),
  Exercise(id: 'press_frances',      name: 'Press Francés',                   muscle: 'push', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12, restSeconds: 75),

  // ── PULL · Espalda ────────────────────────────────────────
  Exercise(id: 'jalon_pecho',        name: 'Jalón al Pecho',                  muscle: 'pull', defaultSets: 4, defaultRepsMin: 8,  defaultRepsMax: 12, restSeconds: 90),
  Exercise(id: 'remo_barra',         name: 'Remo con Barra',                  muscle: 'pull', defaultSets: 4, defaultRepsMin: 8,  defaultRepsMax: 10, restSeconds: 90),
  Exercise(id: 'remo_mancuerna',     name: 'Remo con Mancuerna',              muscle: 'pull', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12, restSeconds: 75),
  Exercise(id: 'remo_cable',         name: 'Remo en Cable',                   muscle: 'pull', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12, restSeconds: 75),
  Exercise(id: 'face_pull',          name: 'Face Pull',                       muscle: 'pull', defaultSets: 3, defaultRepsMin: 15, defaultRepsMax: 20, restSeconds: 60),

  // ── PULL · Bíceps ─────────────────────────────────────────
  Exercise(id: 'curl_barra',         name: 'Curl de Bíceps con Barra',        muscle: 'pull', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12, restSeconds: 60),
  Exercise(id: 'curl_martillo',      name: 'Curl Martillo',                   muscle: 'pull', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12, restSeconds: 60),
  Exercise(id: 'curl_concentrado',   name: 'Curl Concentrado',                muscle: 'pull', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 15, restSeconds: 60),

  // ── LEGS ──────────────────────────────────────────────────
  Exercise(id: 'sentadilla',         name: 'Sentadilla con Barra',            muscle: 'legs', defaultSets: 4, defaultRepsMin: 8,  defaultRepsMax: 12, restSeconds: 120),
  Exercise(id: 'prensa_piernas',     name: 'Prensa de Piernas',               muscle: 'legs', defaultSets: 4, defaultRepsMin: 10, defaultRepsMax: 12, restSeconds: 90),
  Exercise(id: 'ext_cuadriceps',     name: 'Extensión de Cuádriceps',         muscle: 'legs', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 15, restSeconds: 60),
  Exercise(id: 'curl_isquio',        name: 'Curl de Isquiotibiales',          muscle: 'legs', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 15, restSeconds: 60),
  Exercise(id: 'peso_muerto_rumano', name: 'Peso Muerto Rumano',              muscle: 'legs', defaultSets: 4, defaultRepsMin: 8,  defaultRepsMax: 12, restSeconds: 90),
  Exercise(id: 'zancadas',           name: 'Zancadas',                        muscle: 'legs', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12, restSeconds: 75),
  Exercise(id: 'elev_talones',       name: 'Elevación de Talones',            muscle: 'legs', defaultSets: 4, defaultRepsMin: 15, defaultRepsMax: 20, restSeconds: 60),
];

List<Exercise> byMuscle(String muscle) =>
    allExercises.where((e) => e.muscle == muscle).toList();
