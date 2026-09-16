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

  /// Última serie registrada (la más reciente sesión que incluya el
  /// ejercicio) para cada ejercicio de [exerciseIds] — permite mostrar
  /// "la última vez hiciste X kg × Y reps" en esa misma serie.
  Future<Map<String, List<SessionSet>>> getLastLoggedSets(
    String userId,
    Iterable<String> exerciseIds,
  ) async {
    final remaining = exerciseIds.toSet();
    if (remaining.isEmpty) return {};
    final sessions = await getSessionsForUser(userId);
    final result = <String, List<SessionSet>>{};
    for (final session in sessions) {
      if (remaining.isEmpty) break;
      if (!session.completed) continue;
      for (final ex in session.exercises) {
        if (remaining.remove(ex.exerciseId)) {
          result[ex.exerciseId] = ex.sets;
        }
      }
    }
    return result;
  }

  /// Nº de sesiones registradas en el día del calendario de [day] (fechas
  /// guardadas como ISO 8601, así que el rango es comparación de strings).
  Future<int> countSessionsOnDay(String userId, DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final snap = await db
        .collection('sessions')
        .doc(userId)
        .collection('logs')
        .where('date', isGreaterThanOrEqualTo: start.toIso8601String())
        .where('date', isLessThan: end.toIso8601String())
        .get();
    return snap.docs.length;
  }
}
