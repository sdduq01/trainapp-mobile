import '../gym/models/gym_class.dart';
import '../home/streak.dart';

/// Un aviso local por programar. [at] es un instante real (UTC).
class ReminderPlan {
  final DateTime at;
  final String title;
  final String body;

  const ReminderPlan({required this.at, required this.title, required this.body});
}

/// Cálculos puros de los avisos locales (sin plugins, para poder probarlos).
abstract final class ReminderPlans {
  /// Horas de silencio de los recordatorios de clase (Bogotá).
  static const quietStart = 22;
  static const quietEnd = 7;

  /// Aviso de racha: el último día en que todavía alcanza para no perderla
  /// (o no dejarla en riesgo), a [hour] de Bogotá. null si no hace falta:
  /// sin racha (ni forja), la semana ya cumple, o ya no alcanzan los días.
  ///
  /// [forge]: si hay una forja en curso (activa o guardada), qué se pierde
  /// con ella, p. ej. "tu forja (fase 2 de 6, 46 de 192 sesiones)". Con forja
  /// se avisa aunque la racha esté en 0: la forja se enfría igual.
  static ReminderPlan? streak({
    required StreakResult streak,
    required WeekRecord current,
    required DateTime now,
    required int hour,
    String? forge,
  }) {
    if (streak.weeks == 0 && forge == null) return null;
    final minimum = streak.atRisk
        ? current.planned
        : (current.planned - 1 < 1 ? 1 : current.planned - 1);
    final need = minimum - current.done;
    if (need <= 0) return null;

    final today = BogotaTime.fromUtc(now.toUtc());
    final daysLeft = DateTime.sunday - today.weekday; // sin contar hoy
    final dayOffset = daysLeft - (need - 1);
    if (dayOffset < 0) return null; // ya no alcanza
    final at = BogotaTime.toUtc(
        today.year, today.month, today.day + dayOffset, hour, 0);
    if (!at.isAfter(now.toUtc())) return null;

    final weeks = streak.weeks == 1 ? '1 semana' : '${streak.weeks} semanas';
    final String title;
    if (forge == null) {
      title = '🔥 Tu racha de $weeks está en juego';
    } else {
      title = streak.weeks == 0
          ? '🔥 Tu forja está en juego'
          : '🔥 Tu racha de $weeks y tu forja están en juego';
    }
    final String body;
    if (need == 1) {
      if (forge == null) {
        body = streak.atRisk
            ? 'Hoy es tu último día para completar la semana: entrena y salva tu racha.'
            : 'Si no entrenas hoy, tu racha queda en riesgo.';
      } else {
        body = streak.atRisk
            ? 'Hoy es tu último día para completar la semana: si no entrenas, '
                'pierdes tu racha y $forge se enfría.'
            : 'Si no entrenas hoy, tu racha queda en riesgo, y con ella $forge.';
      }
    } else {
      body = 'Te quedan $need días de la semana y necesitas $need sesiones: '
          'entrena hoy para mantener tu racha'
          '${forge == null ? '' : ' y $forge'}.';
    }
    return ReminderPlan(at: at, title: title, body: body);
  }

  /// Recordatorio de una clase inscrita: una hora antes de que cierre la
  /// ventana de cancelación del gimnasio. null si ese momento ya pasó o la
  /// clase está cancelada.
  static ReminderPlan? classReminder({
    required GymClass gymClass,
    required int cancelWindowHours,
    required DateTime now,
  }) {
    if (gymClass.status != GymClass.statusScheduled) return null;
    var at = gymClass.startsAt
        .subtract(Duration(hours: cancelWindowHours + 1));
    // Sin avisos de madrugada: entre las 22:00 y las 7:00 se adelanta a las
    // 21:00 de la noche anterior (sigue antes del límite para cancelar).
    final local = BogotaTime.fromUtc(at);
    if (local.hour < quietEnd || local.hour >= quietStart) {
      final day = local.hour < quietEnd ? local.day - 1 : local.day;
      at = BogotaTime.toUtc(local.year, local.month, day, quietStart - 1, 0);
    }
    if (!at.isAfter(now.toUtc())) return null;

    final starts = gymClass.startsAtBogota;
    final deadline =
        BogotaTime.fromUtc(gymClass.startsAt.subtract(Duration(hours: cancelWindowHours)));
    final daysBetween = DateTime.utc(starts.year, starts.month, starts.day)
        .difference(DateTime.utc(BogotaTime.fromUtc(at).year,
            BogotaTime.fromUtc(at).month, BogotaTime.fromUtc(at).day))
        .inDays;
    final hhmm = BogotaTime.hhmm(starts);
    final when = switch (daysBetween) {
      0 => 'hoy a las $hhmm',
      1 => 'mañana a las $hhmm',
      _ => 'el ${BogotaTime.dayLabel(starts).toLowerCase()} a las $hhmm',
    };
    return ReminderPlan(
      at: at,
      title: 'Clase de ${gymClass.name} $when',
      body: 'Si no puedes ir, cancela antes de las ${BogotaTime.hhmm(deadline)} '
          'para liberar tu cupo.',
    );
  }
}
