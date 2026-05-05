import '../../core/firebase/firestore_instance.dart';
import '../models/routine.dart';

class RoutineService {
  Future<Routine?> getRoutine(String userId) async {
    final doc = await db.collection('routines').doc(userId).get();
    if (!doc.exists) return null;
    return Routine.fromMap(userId, doc.data()!);
  }

  Future<void> saveRoutine(Routine routine) async {
    await db
        .collection('routines')
        .doc(routine.userId)
        .set(routine.toMap());
  }
}
