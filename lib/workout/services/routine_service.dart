import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;

import '../../core/firebase/firestore_instance.dart';
import '../models/routine.dart';
import 'exercise_pr_service.dart';

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

  /// El entrenador editó la rutina del atleta a mano: la Cloud Function
  /// `notifyRoutineEdit` le avisa al atleta. Los guardados automáticos
  /// (progresión, cambio de fase) no lo marcan, así que no avisan.
  Future<void> markEditedByTrainer(String athleteUid, String trainerUid) =>
      db.collection('routines').doc(athleteUid).update({
        'trainerEditedAt': FieldValue.serverTimestamp(),
        'trainerEditedBy': trainerUid,
      });

  /// Aplica los PRs persistidos del usuario a una rutina nueva.
  /// Para cada ejercicio cuyo `exerciseId` tenga PR registrado, copia
  /// `currentWeight` y `weightUnit` desde el PR.
  Future<Routine> hydrateWithPRs(Routine routine) async {
    final prs = await ExercisePrService().getAll(routine.userId);
    if (prs.isEmpty) return routine;

    final hydratedDays = routine.days.map((day) {
      final exercises = day.exercises.map((ex) {
        final pr = prs[ex.exerciseId];
        if (pr == null) return ex;
        return ex.copyWith(currentWeight: pr.weight, weightUnit: pr.unit);
      }).toList();
      return RoutineDay(
        dayNumber: day.dayNumber,
        name: day.name,
        focus: day.focus,
        exercises: exercises,
      );
    }).toList();

    return routine.copyWith(days: hydratedDays);
  }
}
