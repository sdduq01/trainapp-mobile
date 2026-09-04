import '../../core/firebase/firestore_instance.dart';
import '../models/exercise.dart';

class ExerciseService {
  Future<List<Exercise>> getExercises() async {
    final snap = await db.collection('exercises').orderBy('name').get();
    return snap.docs.map((d) => Exercise.fromMap(d.id, d.data())).toList();
  }

  /// Crea un ejercicio nuevo en el catálogo (p. ej. uno propio del usuario,
  /// agrupado bajo "Mis ejercicios"). [exercise.id] se ignora — Firestore
  /// asigna el id definitivo, reflejado en el resultado.
  Future<Exercise> createExercise(Exercise exercise) async {
    final ref = db.collection('exercises').doc();
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
}
