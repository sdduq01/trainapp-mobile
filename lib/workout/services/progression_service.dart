import '../../core/firebase/firestore_instance.dart';
import '../../core/utils/iso_week.dart';

class ProgressionService {
  Future<void> saveProgressionEvent(String userId, int exerciseCount) async {
    final now = DateTime.now();
    await db
        .collection('progressions')
        .doc(userId)
        .collection('logs')
        .add({
      'date': now.toIso8601String(),
      'year': IsoWeek.year(now),
      'weekNumber': IsoWeek.weekNumber(now),
      'exerciseCount': exerciseCount,
    });
  }

  /// Progresiones por semana ISO del año ISO [isoYear]. La semana se deriva
  /// de `date` y no del `weekNumber` guardado: los eventos anteriores a
  /// 2026-10 se guardaron con semanas contadas desde el 1 de enero (no ISO) y
  /// el resaltado de la gráfica caía corrido una semana.
  Future<Map<int, int>> getProgressionsByWeek(String userId, int isoYear) async {
    final start = IsoWeek.firstMonday(isoYear);
    final end = IsoWeek.firstMonday(isoYear + 1);
    final snap = await db
        .collection('progressions')
        .doc(userId)
        .collection('logs')
        .where('date', isGreaterThanOrEqualTo: start.toIso8601String())
        .where('date', isLessThan: end.toIso8601String())
        .get();

    final Map<int, int> result = {};
    for (final doc in snap.docs) {
      final date = DateTime.tryParse(doc.data()['date'] as String? ?? '');
      if (date == null) continue;
      final week = IsoWeek.weekNumber(date);
      final count = doc.data()['exerciseCount'] as int? ?? 0;
      result[week] = (result[week] ?? 0) + count;
    }
    return result;
  }

  /// Suma de ejercicios con progresión entre [from] y [to) (semana en curso;
  /// lee solo los eventos de ese rango).
  Future<int> getExerciseCountInRange(
      String userId, DateTime from, DateTime to) async {
    final snap = await db
        .collection('progressions')
        .doc(userId)
        .collection('logs')
        .where('date', isGreaterThanOrEqualTo: from.toIso8601String())
        .where('date', isLessThan: to.toIso8601String())
        .get();
    return snap.docs.fold<int>(
        0, (n, d) => n + (d.data()['exerciseCount'] as int? ?? 0));
  }

  // Devuelve true la primera vez que se completa la meta de sesiones en una semana dada.
  Future<bool> checkAndMarkYeahBuddyMilestone(
      String userId, int weekNumber) async {
    final doc = await db.collection('profiles').doc(userId).get();
    final weeks = (doc.data()?['yeahBuddyWeeks'] as List<dynamic>?)
            ?.whereType<int>()
            .toList() ??
        [];
    if (weeks.contains(weekNumber)) return false;
    await db
        .collection('profiles')
        .doc(userId)
        .update({'yeahBuddyWeeks': [...weeks, weekNumber]});
    return true;
  }

  // Devuelve true la primera vez que una semana supera el 60% de ejercicios de la rutina con progresión.
  Future<bool> checkAndMarkSenecaMilestone(
      String userId, int year, int weekNumber, int totalRoutineExercises) async {
    // Solo los eventos de esa semana, no los del año entero.
    final first = IsoWeek.firstMonday(year);
    final from =
        DateTime(first.year, first.month, first.day + 7 * (weekNumber - 1));
    final to = DateTime(from.year, from.month, from.day + 7);
    final count = await getExerciseCountInRange(userId, from, to);
    if (count <= totalRoutineExercises * 0.3) return false;

    final doc = await db.collection('profiles').doc(userId).get();
    final senecaWeeks = (doc.data()?['senecaWeeks'] as List<dynamic>?)
            ?.whereType<int>()
            .toList() ??
        [];
    if (senecaWeeks.contains(weekNumber)) return false;

    await db.collection('profiles').doc(userId).update({
      'senecaWeeks': [...senecaWeeks, weekNumber],
    });
    return true;
  }
}
