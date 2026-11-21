import 'package:cloud_firestore/cloud_firestore.dart';

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

  CollectionReference<Map<String, dynamic>> _logs(String userId) =>
      db.collection('sessions').doc(userId).collection('logs');

  static List<WorkoutSession> _parse(
          QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs.map((d) => WorkoutSession.fromMap(d.id, d.data())).toList();

  /// Todo el historial, de la más reciente a la más vieja. Cada sesión es una
  /// lectura: usarlo solo donde de verdad se necesita todo (historial
  /// premium, respaldo de la racha).
  Future<List<WorkoutSession>> getSessionsForUser(String userId,
      {int? limit}) async {
    Query<Map<String, dynamic>> q =
        _logs(userId).orderBy('date', descending: true);
    if (limit != null) q = q.limit(limit);
    return _parse(await q.get());
  }

  /// Cuántas sesiones tiene en total, sin leerlas (una consulta de conteo
  /// cuesta 1 lectura por cada 1.000 sesiones).
  Future<int> countSessions(String userId) async {
    final agg = await _logs(userId).count().get();
    return agg.count ?? 0;
  }

  /// Sesiones con fecha en [from, to) (fechas ISO 8601 locales, así que el
  /// rango es comparación de strings).
  Future<List<WorkoutSession>> getSessionsInRange(
      String userId, DateTime from, DateTime to) async {
    final snap = await _logs(userId)
        .where('date', isGreaterThanOrEqualTo: from.toIso8601String())
        .where('date', isLessThan: to.toIso8601String())
        .get();
    return _parse(snap);
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
    // Por páginas desde la más reciente: casi siempre la primera alcanza (los
    // ejercicios de un día se repiten cada semana), en vez de leer todo el
    // historial en cada sesión.
    const pageSize = 15;
    final result = <String, List<SessionSet>>{};
    Query<Map<String, dynamic>> q =
        _logs(userId).orderBy('date', descending: true).limit(pageSize);
    while (remaining.isNotEmpty) {
      final snap = await q.get();
      for (final d in snap.docs) {
        final session = WorkoutSession.fromMap(d.id, d.data());
        if (!session.completed) continue;
        for (final ex in session.exercises) {
          if (remaining.remove(ex.exerciseId)) {
            result[ex.exerciseId] = ex.sets;
          }
        }
        if (remaining.isEmpty) break;
      }
      if (snap.docs.length < pageSize) break;
      q = q.startAfterDocument(snap.docs.last);
    }
    return result;
  }

  /// Nº de sesiones registradas en el día del calendario de [day] (fechas
  /// guardadas como ISO 8601, así que el rango es comparación de strings).
  Future<int> countSessionsOnDay(String userId, DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day + 1);
    return (await getSessionsInRange(userId, start, end)).length;
  }
}
