import '../../core/firebase/firestore_instance.dart';
import '../models/exercise.dart';

class ExerciseService {
  /// Catálogo global curado (colección `exercises`, poblada por los scripts
  /// admin). Solo lectura desde el cliente.
  Future<List<Exercise>> getExercises() async {
    final snap = await db.collection('exercises').orderBy('name').get();
    return snap.docs.map((d) => Exercise.fromMap(d.id, d.data())).toList();
  }

  /// Ejercicios propios del usuario (`custom_exercises/{userId}/items`),
  /// ordenados por nombre en cliente.
  Future<List<Exercise>> getCustomExercises(String userId) async {
    final snap = await db
        .collection('custom_exercises')
        .doc(userId)
        .collection('items')
        .get();
    return snap.docs.map((d) => Exercise.fromMap(d.id, d.data())).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Catálogo global + ejercicios propios del usuario (si hay sesión), en un
  /// solo listado para los selectores de ejercicio. Si los propios no cargan
  /// (sin permisos, sin red), devuelve al menos el catálogo global.
  Future<List<Exercise>> getExercisesWithCustom(String? userId) async {
    final global = await getExercises();
    if (userId == null) return global;
    try {
      return [...global, ...await getCustomExercises(userId)];
    } catch (_) {
      return global;
    }
  }

  /// Crea un ejercicio propio del usuario bajo `custom_exercises/{userId}/items`,
  /// catalogado en el grupo "Mis ejercicios". [exercise.id] se ignora —
  /// Firestore asigna el id definitivo, reflejado en el resultado.
  Future<Exercise> createCustomExercise(String userId, Exercise exercise) async {
    final ref = db
        .collection('custom_exercises')
        .doc(userId)
        .collection('items')
        .doc();
    await ref.set(exercise.toMap());
    return Exercise(
      id: ref.id,
      name: exercise.name,
      muscle: exercise.muscle,
      muscleGroup: exercise.muscleGroup,
      defaultSets: exercise.defaultSets,
      defaultRepsMin: exercise.defaultRepsMin,
      defaultRepsMax: exercise.defaultRepsMax,
      restSeconds: exercise.restSeconds,
      defaultWeightUnit: exercise.defaultWeightUnit,
      defaultProgressionStep: exercise.defaultProgressionStep,
      isIsometric: exercise.isIsometric,
    );
  }

  /// Borra un ejercicio propio del usuario. No afecta a rutinas que ya lo
  /// tengan agregado (guardan una copia de sus datos).
  Future<void> deleteCustomExercise(String userId, String exerciseId) async {
    await db
        .collection('custom_exercises')
        .doc(userId)
        .collection('items')
        .doc(exerciseId)
        .delete();
  }
}
