/// Racha semanal de entrenamiento.
///
/// Reglas:
/// - Una semana mantiene la racha si se entrenan al menos los días de la
///   rutina menos uno (y siempre al menos un día).
/// - Una semana con dos días menos (y al menos un día entrenado) deja la
///   racha "en riesgo": se salva si la semana siguiente se cumplen todos los
///   días de la rutina; si no, se pierde.
/// - Cualquier semana por debajo de eso corta la racha.
/// - La semana en curso nunca corta la racha: suma en cuanto llega al
///   mínimo, y si viene de una semana en riesgo suma al completarse.
///
/// El objetivo de cada semana es el que tenía la rutina en ese momento (cada
/// sesión guarda `plannedDays`), así que cambiar de rutina no reescribe las
/// semanas pasadas.
class WeekRecord {
  final int done;
  final int planned;

  const WeekRecord({required this.done, required this.planned});
}

class StreakResult {
  /// Semanas de racha, contando la semana en riesgo mientras se pueda salvar.
  final int weeks;

  /// La semana pasada quedó dos días corta: hay que completar la actual.
  final bool atRisk;

  /// Días que faltan esta semana para salvar la racha (si [atRisk]).
  final int daysToSave;

  const StreakResult({
    required this.weeks,
    this.atRisk = false,
    this.daysToSave = 0,
  });
}

class Streak {
  static bool _full(WeekRecord w) => w.done >= w.planned && w.done >= 1;

  static bool _keeps(WeekRecord w) => w.done >= 1 && w.done >= w.planned - 1;

  static bool _slips(WeekRecord w) => w.done >= 1 && w.done == w.planned - 2;

  /// [weeks]: semanas consecutivas en orden cronológico; la última es la
  /// semana en curso.
  static StreakResult compute(List<WeekRecord> weeks) {
    if (weeks.isEmpty) return const StreakResult(weeks: 0);

    var streak = 0;
    var pendingRecovery = false;

    for (final w in weeks.take(weeks.length - 1)) {
      if (pendingRecovery) {
        pendingRecovery = false;
        if (_full(w)) {
          streak++;
          continue;
        }
        // No se recuperó: la racha se perdió en la semana en riesgo y esta
        // semana se evalúa como el posible inicio de una nueva.
        streak = 0;
      }
      if (_keeps(w)) {
        streak++;
      } else if (_slips(w)) {
        streak++;
        pendingRecovery = true;
      } else {
        streak = 0;
      }
    }

    final current = weeks.last;
    if (pendingRecovery) {
      if (_full(current)) return StreakResult(weeks: streak + 1);
      return StreakResult(
        weeks: streak,
        atRisk: true,
        daysToSave: current.planned - current.done,
      );
    }
    return StreakResult(weeks: _keeps(current) ? streak + 1 : streak);
  }
}
