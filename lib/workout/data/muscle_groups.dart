import '../models/exercise.dart';
import '../models/progression_type.dart';
import '../models/routine.dart';

/// Grupos musculares específicos usados para catalogar ejercicios y para el
/// selector en dos pasos (grupo muscular → ejercicio) en los menús de
/// rutina. Los ejercicios multiarticulares usan la zona principal que
/// entrenan (pecho, espalda, cuádriceps...) y los analíticos el músculo
/// puntual (bíceps, tríceps, gemelos...).
/// Grupo especial donde se guardan los ejercicios que el usuario crea desde
/// cero (fuera del catálogo curado), para tenerlos siempre a mano.
const String kCustomExerciseGroup = 'mis_ejercicios';

const Map<String, String> muscleGroupLabels = {
  'mis_ejercicios': 'Mis ejercicios',
  'pecho': 'Pecho',
  'espalda': 'Espalda',
  'hombros': 'Hombros',
  'trapecios': 'Trapecios',
  'biceps': 'Bíceps',
  'triceps': 'Tríceps',
  'antebrazo': 'Antebrazo',
  'cuadriceps': 'Cuádriceps',
  'femorales': 'Femorales',
  'gluteos': 'Glúteos',
  'gemelos': 'Gemelos',
  'abductores': 'Abductores',
  'aductores': 'Aductores',
  'abdominales': 'Abdominales',
  'cardio': 'Cardio',
  'estiramiento': 'Estiramiento',
  'otros': 'Otros',
};

/// Orden de despliegue en los selectores (agrupado visualmente por zona:
/// tren superior empuje/tracción, brazos, tren inferior, core).
const List<String> muscleGroupOrder = [
  'mis_ejercicios',
  'pecho',
  'espalda',
  'hombros',
  'trapecios',
  'biceps',
  'triceps',
  'antebrazo',
  'cuadriceps',
  'femorales',
  'gluteos',
  'gemelos',
  'abductores',
  'aductores',
  'abdominales',
  'cardio',
  'estiramiento',
  'otros',
];

/// Grupos que no manejan progresión de peso: cardio (duración) y
/// estiramientos (sostén). El resto arranca en doble progresión lineal.
const Set<String> nonWeightedMuscleGroups = {'cardio', 'estiramiento'};

/// Tipo de progresión sugerido al agregar [ex] desde el catálogo.
ProgressionType defaultProgressionTypeFor(Exercise ex) =>
    nonWeightedMuscleGroups.contains(ex.muscleGroup)
        ? ProgressionType.none
        : ProgressionType.doubleLinear;

/// Construye el [RoutineExercise] por defecto al agregar [ex] del catálogo
/// a un día de rutina (usado tanto al editar la rutina completa como al
/// agregar un ejercicio desde una sesión activa).
RoutineExercise routineExerciseFromCatalog(Exercise ex) => RoutineExercise(
      exerciseId: ex.id,
      name: ex.name,
      sets: ex.defaultSets,
      repsMin: ex.defaultRepsMin,
      repsMax: ex.defaultRepsMax,
      restSeconds: ex.restSeconds,
      weightUnit: ex.defaultWeightUnit,
      progressionStep: ex.defaultProgressionStep,
      isIsometric: ex.isIsometric,
      progressionType: defaultProgressionTypeFor(ex),
    );
