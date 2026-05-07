import '../../core/firebase/firestore_instance.dart';

class ProgressionService {
  static int _weekNumber(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    return (date.difference(startOfYear).inDays / 7).floor() + 1;
  }

  Future<void> saveProgressionEvent(String userId, int exerciseCount) async {
    final now = DateTime.now();
    await db
        .collection('progressions')
        .doc(userId)
        .collection('logs')
        .add({
      'date': now.toIso8601String(),
      'year': now.year,
      'weekNumber': _weekNumber(now),
      'exerciseCount': exerciseCount,
    });
  }

  Future<Map<int, int>> getProgressionsByWeek(String userId, int year) async {
    final snap = await db
        .collection('progressions')
        .doc(userId)
        .collection('logs')
        .where('year', isEqualTo: year)
        .get();

    final Map<int, int> result = {};
    for (final doc in snap.docs) {
      final week = doc.data()['weekNumber'] as int;
      final count = doc.data()['exerciseCount'] as int? ?? 0;
      result[week] = (result[week] ?? 0) + count;
    }
    return result;
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
    final byWeek = await getProgressionsByWeek(userId, year);
    if ((byWeek[weekNumber] ?? 0) <= totalRoutineExercises * 0.3) return false;

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
