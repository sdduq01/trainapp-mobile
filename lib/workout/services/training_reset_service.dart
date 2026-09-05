import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/firebase/firestore_instance.dart';
import '../models/routine.dart';
import 'routine_service.dart';

/// Borra todo el progreso de entrenamiento guardado de un usuario y deja la
/// rutina como recién generada (pesos en 0, semana 1), para "empezar de
/// cero". No toca el perfil físico ni la estructura de la rutina (días,
/// ejercicios, series/reps/descanso configurados).
///
/// Se borra:
/// - Historial de sesiones (`sessions/{uid}/logs`)
/// - PRs por ejercicio (`exercise_prs/{uid}/items`)
/// - Eventos de progresión semanal (`progressions/{uid}/logs`)
/// - Apuntes personales por ejercicio (`exercise_notes/{uid}/items`)
/// - Hitos desbloqueados (yeahBuddyWeeks / senecaWeeks en el perfil)
/// - Avance del macro ciclo (`macrocycles/{uid}`) y el desbloqueo de Top
///   Secret (`forjadoHierroCompletado` en el perfil)
/// - El draft de sesión activa guardado en el dispositivo
///
/// Se reinicia (sin borrar):
/// - `currentWeight` de cada ejercicio de la rutina → 0
/// - `createdAt` de la rutina → ahora (reinicia el contador de semanas)
class TrainingResetService {
  Future<void> resetAll(String userId) async {
    await Future.wait([
      _deleteCollection(
          db.collection('sessions').doc(userId).collection('logs')),
      _deleteCollection(
          db.collection('exercise_prs').doc(userId).collection('items')),
      _deleteCollection(
          db.collection('progressions').doc(userId).collection('logs')),
      _deleteCollection(
          db.collection('exercise_notes').doc(userId).collection('items')),
      _resetRoutineProgress(userId),
      _clearMilestones(userId),
      _clearMacrocycle(userId),
      _clearLocalDraft(),
    ]);
  }

  Future<void> _clearMacrocycle(String userId) async {
    await db.collection('macrocycles').doc(userId).delete();
  }

  Future<void> _deleteCollection(
      CollectionReference<Map<String, dynamic>> col) async {
    // Firestore limita los batch a 500 operaciones — se pagina por si acaso.
    const pageSize = 300;
    while (true) {
      final snap = await col.limit(pageSize).get();
      if (snap.docs.isEmpty) return;
      final batch = db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snap.docs.length < pageSize) return;
    }
  }

  Future<void> _resetRoutineProgress(String userId) async {
    final routine = await RoutineService().getRoutine(userId);
    if (routine == null) return;
    final resetDays = routine.days.map((day) {
      final exercises =
          day.exercises.map((e) => e.copyWith(currentWeight: 0)).toList();
      return RoutineDay(
        dayNumber: day.dayNumber,
        name: day.name,
        focus: day.focus,
        exercises: exercises,
      );
    }).toList();
    await RoutineService().saveRoutine(Routine(
      userId: routine.userId,
      type: routine.type,
      name: routine.name,
      weekNumber: routine.weekNumber,
      createdAt: DateTime.now(),
      days: resetDays,
    ));
  }

  Future<void> _clearMilestones(String userId) async {
    await db.collection('profiles').doc(userId).set({
      'yeahBuddyWeeks': [],
      'senecaWeeks': [],
      'forjadoHierroCompletado': false,
    }, SetOptions(merge: true));
  }

  Future<void> _clearLocalDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('session_draft');
    } catch (_) {}
  }
}
