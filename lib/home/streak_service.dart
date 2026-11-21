import 'package:cloud_firestore/cloud_firestore.dart' show SetOptions;

import '../core/firebase/firestore_instance.dart';
import '../core/utils/iso_week.dart';
import '../workout/models/workout_session.dart';
import '../workout/services/progression_service.dart';
import '../workout/services/session_service.dart';
import 'streak.dart';

/// Semanas del usuario con su objetivo y la racha resultante.
class StreakData {
  /// Por lunes (00:00 local), desde la primera sesión hasta la semana actual.
  final Map<DateTime, WeekRecord> weeks;
  final StreakResult streak;

  /// Ejercicios con progresión por semana (lunes), para la gráfica.
  final Map<DateTime, int> progressions;

  /// Objetivo de las semanas sin sesiones que lo guarden (ver [StreakService]).
  final int legacyGoal;

  const StreakData({
    required this.weeks,
    required this.streak,
    required this.progressions,
    required this.legacyGoal,
  });

  WeekRecord get current => weeks.values.last;

  /// Regla de la forja: ¿se rompió la racha después de [since]? La semana de
  /// [since] no cuenta (la forja pudo empezar o reglamentarse a mitad de
  /// semana); se evalúan las semanas siguientes hasta la actual.
  bool brokeSince(DateTime since) {
    final graceMonday = StreakService.mondayOf(since);
    final after = weeks.entries
        .where((e) => e.key.isAfter(graceMonday))
        .map((e) => e.value)
        .toList();
    // Si `since` es de esta semana no hay nada que evaluar todavía.
    if (after.isEmpty) return false;
    return Streak.brokeIn(after);
  }
}

/// Sesiones y objetivo de una semana antes de aplicar el objetivo heredado.
class _WeekSummary {
  final int done;
  final int? planned;

  const _WeekSummary(this.done, this.planned);

  factory _WeekSummary.of(List<WorkoutSession> sessions) {
    final stamped = sessions.where((s) => s.plannedDays != null).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return _WeekSummary(
        sessions.length, stamped.isEmpty ? null : stamped.first.plannedDays);
  }
}

/// Calcula la racha. Lo usan la gráfica del inicio y el aviso local de racha.
///
/// Lee el resumen semanal `session_stats/{uid}` (lo mantiene la Cloud
/// Function `syncSessionStats`) más las sesiones de la semana en curso, que
/// así no dependen de que la función ya haya corrido. Si el resumen aún no
/// existe (usuarios que no han entrenado desde que se activó), usa el
/// historial completo como antes.
class StreakService {
  static DateTime mondayOf(DateTime date) =>
      DateTime(date.year, date.month, date.day - (date.weekday - 1));

  static DateTime _parseKey(String key) {
    final p = key.split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2]);
  }

  /// [plannedNow]: días de la rutina activa.
  Future<StreakData> load(String uid, int plannedNow, {DateTime? now}) async {
    now ??= DateTime.now();
    final thisMonday = mondayOf(now);
    final nextMonday =
        DateTime(thisMonday.year, thisMonday.month, thisMonday.day + 7);

    final summaries = <DateTime, _WeekSummary>{};
    final progressions = <DateTime, int>{};
    var fromStats = false;
    try {
      final doc = await db.collection('session_stats').doc(uid).get();
      final data = doc.data();
      if (data != null && data['version'] == 1) {
        fromStats = true;
        final weeks = (data['weeks'] as Map<String, dynamic>?) ?? const {};
        for (final e in weeks.entries) {
          final w = e.value as Map<String, dynamic>;
          summaries[_parseKey(e.key)] = _WeekSummary(
              (w['done'] as num?)?.toInt() ?? 0, (w['planned'] as num?)?.toInt());
        }
        final prog =
            (data['progressions'] as Map<String, dynamic>?) ?? const {};
        for (final e in prog.entries) {
          progressions[_parseKey(e.key)] = (e.value as num).toInt();
        }
      }
    } catch (_) {
      // Sin red o sin reglas aún: se usa el historial completo.
    }

    if (fromStats) {
      // La semana en curso, siempre fresca.
      try {
        final week = await SessionService()
            .getSessionsInRange(uid, thisMonday, nextMonday);
        if (week.isEmpty) {
          summaries.remove(thisMonday);
        } else {
          summaries[thisMonday] = _WeekSummary.of(week);
        }
        progressions[thisMonday] = await ProgressionService()
            .getExerciseCountInRange(uid, thisMonday, nextMonday);
      } catch (_) {}
    } else {
      List<WorkoutSession> sessions = const [];
      try {
        sessions = await SessionService().getSessionsForUser(uid);
      } catch (_) {
        // Sin permisos o sin red: se calcula vacío.
      }
      final byMonday = <DateTime, List<WorkoutSession>>{};
      for (final s in sessions) {
        byMonday.putIfAbsent(mondayOf(s.date), () => []).add(s);
      }
      for (final e in byMonday.entries) {
        summaries[e.key] = _WeekSummary.of(e.value);
      }
      try {
        final year = IsoWeek.year(now);
        final byWeek =
            await ProgressionService().getProgressionsByWeek(uid, year);
        final first = IsoWeek.firstMonday(year);
        for (final e in byWeek.entries) {
          progressions[DateTime(
              first.year, first.month, first.day + 7 * (e.key - 1))] = e.value;
        }
      } catch (_) {}
    }

    final needsLegacy = summaries.entries
        .any((e) => e.value.planned == null && e.key != thisMonday);
    final legacyGoal =
        needsLegacy ? await _legacyGoal(uid, plannedNow) : plannedNow;

    // Semanas desde la primera sesión hasta la actual (cruzando años, para
    // que la racha no se reinicie en enero), con el objetivo que tenía la
    // rutina en cada una: el de su primera sesión que lo guarde; si no
    // tiene, el de la semana anterior. La semana en curso sin sesiones con
    // objetivo usa la rutina actual.
    var monday = summaries.keys.fold<DateTime>(
        thisMonday, (min, m) => m.isBefore(min) ? m : min);
    final weeks = <DateTime, WeekRecord>{};
    var goal = legacyGoal;
    while (!monday.isAfter(thisMonday)) {
      final week = summaries[monday];
      if (week?.planned != null) {
        goal = week!.planned!;
      } else if (monday == thisMonday) {
        goal = plannedNow;
      }
      weeks[monday] = WeekRecord(done: week?.done ?? 0, planned: goal);
      monday = DateTime(monday.year, monday.month, monday.day + 7);
    }
    return StreakData(
      weeks: weeks,
      streak: Streak.compute(weeks.values.toList()),
      progressions: progressions,
      legacyGoal: legacyGoal,
    );
  }

  /// Objetivo de las sesiones anteriores a `plannedDays`: los días de la
  /// rutina activa la primera vez que se calcula, guardado en el perfil para
  /// que un cambio de rutina posterior no reescriba esas semanas.
  Future<int> _legacyGoal(String uid, int planned) async {
    final ref = db.collection('profiles').doc(uid);
    try {
      final saved = (await ref.get()).data()?['streakLegacyGoal'];
      if (saved is int) return saved;
      await ref.set({'streakLegacyGoal': planned}, SetOptions(merge: true));
    } catch (_) {
      // Sin red: se usa la rutina actual y se guarda en otra ocasión.
    }
    return planned;
  }
}
