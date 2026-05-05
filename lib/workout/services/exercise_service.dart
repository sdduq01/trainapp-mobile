import '../../core/firebase/firestore_instance.dart';
import '../models/exercise.dart';

class ExerciseService {
  Future<List<Exercise>> getExercises() async {
    final snap = await db.collection('exercises').orderBy('name').get();
    return snap.docs.map((d) => Exercise.fromMap(d.id, d.data())).toList();
  }
}
