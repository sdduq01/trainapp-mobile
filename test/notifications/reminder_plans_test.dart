import 'package:flutter_test/flutter_test.dart';
import 'package:trainapp_mobile/gym/models/gym_class.dart';
import 'package:trainapp_mobile/home/streak.dart';
import 'package:trainapp_mobile/notifications/reminder_plans.dart';

/// Jueves 19 nov 2026, 10:00 en Bogotá (semana lun 16 – dom 22).
final thursday = BogotaTime.toUtc(2026, 11, 19, 10, 0);

ReminderPlan? streakPlan({
  required int done,
  int planned = 4,
  int weeks = 3,
  bool atRisk = false,
  DateTime? now,
  String? forge,
}) =>
    ReminderPlans.streak(
      streak: StreakResult(weeks: weeks, atRisk: atRisk),
      current: WeekRecord(done: done, planned: planned),
      now: now ?? thursday,
      hour: 18,
      forge: forge,
    );

void main() {
  group('aviso de racha', () {
    test('falta una sesión: el domingo a la hora elegida', () {
      final p = streakPlan(done: 2)!;
      expect(p.at, BogotaTime.toUtc(2026, 11, 22, 18, 0));
      expect(p.title, contains('3 semanas'));
      expect(p.body, contains('queda en riesgo'));
    });

    test('faltan dos: el sábado', () {
      expect(streakPlan(done: 1)!.at, BogotaTime.toUtc(2026, 11, 21, 18, 0));
    });

    test('faltan tantas como días quedan: hoy', () {
      expect(streakPlan(done: 0, planned: 5)!.at,
          BogotaTime.toUtc(2026, 11, 19, 18, 0));
    });

    test('sin aviso si ya cumple, si no alcanza o si ya pasó la hora', () {
      expect(streakPlan(done: 3), isNull);
      expect(streakPlan(done: 0, planned: 6), isNull);
      expect(
        streakPlan(
            done: 0, planned: 5, now: BogotaTime.toUtc(2026, 11, 19, 19, 0)),
        isNull,
      );
    });

    test('sin racha no hay aviso', () {
      expect(streakPlan(done: 0, weeks: 0), isNull);
    });

    test('en riesgo exige completar todos los días', () {
      final p = streakPlan(done: 3, atRisk: true)!;
      expect(p.at, BogotaTime.toUtc(2026, 11, 22, 18, 0));
      expect(p.body, contains('salva tu racha'));
      expect(streakPlan(done: 4, atRisk: true), isNull);
    });
  });

  group('aviso de racha con forja', () {
    const forge = 'tu forja (fase 2 de 6, 46 de 192 sesiones)';

    test('menciona la forja y lo que lleva', () {
      final p = streakPlan(done: 2, forge: forge)!;
      expect(p.title, '🔥 Tu racha de 3 semanas y tu forja están en juego');
      expect(p.body, contains('46 de 192 sesiones'));
    });

    test('en riesgo: pierdes la racha y la forja se enfría', () {
      final p = streakPlan(done: 3, atRisk: true, forge: forge)!;
      expect(p.body, contains('pierdes tu racha y $forge se enfría'));
    });

    test('con forja avisa aunque la racha esté en 0', () {
      expect(streakPlan(done: 2, weeks: 0), isNull);
      expect(streakPlan(done: 2, weeks: 0, forge: forge)!.title,
          '🔥 Tu forja está en juego');
    });
  });

  group('recordatorio de clase', () {
    GymClass yoga({String status = GymClass.statusScheduled}) => GymClass(
          id: 'c1',
          gymId: 'g1',
          name: 'Yoga',
          startsAt: BogotaTime.toUtc(2026, 11, 19, 18, 0),
          durationMin: 60,
          capacity: 10,
          status: status,
        );

    test('una hora antes de que cierre la ventana de cancelación', () {
      final p = ReminderPlans.classReminder(
          gymClass: yoga(), cancelWindowHours: 2, now: thursday)!;
      expect(p.at, BogotaTime.toUtc(2026, 11, 19, 15, 0));
      expect(p.title, 'Clase de Yoga hoy a las 18:00');
      expect(p.body, contains('antes de las 16:00'));
    });

    test('clase temprano: sin aviso de madrugada, la noche anterior', () {
      final early = GymClass(
        id: 'c2',
        gymId: 'g1',
        name: 'Spinning',
        startsAt: BogotaTime.toUtc(2026, 11, 20, 6, 0),
        durationMin: 45,
        capacity: 10,
      );
      final p = ReminderPlans.classReminder(
          gymClass: early, cancelWindowHours: 2, now: thursday)!;
      // 6:00 − 3 h = 3:00 → se adelanta a las 21:00 del jueves.
      expect(p.at, BogotaTime.toUtc(2026, 11, 19, 21, 0));
      expect(p.title, 'Clase de Spinning mañana a las 06:00');
    });

    test('sin aviso si está cancelada o ya pasó el momento', () {
      expect(
        ReminderPlans.classReminder(
            gymClass: yoga(status: GymClass.statusCancelled),
            cancelWindowHours: 2,
            now: thursday),
        isNull,
      );
      expect(
        ReminderPlans.classReminder(
            gymClass: yoga(),
            cancelWindowHours: 2,
            now: BogotaTime.toUtc(2026, 11, 19, 15, 30)),
        isNull,
      );
    });
  });
}
