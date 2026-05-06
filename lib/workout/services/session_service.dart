import '../../core/firebase/firestore_instance.dart';
import '../models/workout_session.dart';

class SessionService {
  // sessions/{uid}/logs/{sessionId}
  // Subcollección por usuario → compatible con acceso de entrenador en módulo futuro
  Future<void> saveSession(WorkoutSession session) async {
    await db
        .collection('sessions')
        .doc(session.userId)
        .collection('logs')
        .doc(session.id)
        .set(session.toMap());
  }

  Future<List<WorkoutSession>> getSessionsForUser(String userId) async {
    final snap = await db
        .collection('sessions')
        .doc(userId)
        .collection('logs')
        .orderBy('date', descending: true)
        .get();
    return snap.docs
        .map((d) => WorkoutSession.fromMap(d.id, d.data()))
        .toList();
  }
}
