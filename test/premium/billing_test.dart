import 'package:flutter_test/flutter_test.dart';
import 'package:trainapp_mobile/gym/models/billing.dart';
import 'package:trainapp_mobile/premium/free_tier.dart';
import 'package:trainapp_mobile/workout/models/routine.dart';

BillingAthlete athlete({
  required DateTime freeFrom,
  required List<PremiumPeriod> periods,
}) =>
    BillingAthlete(
      uid: 'a',
      email: 'a@x.com',
      firstPremiumAt: periods.first.start,
      freeFrom: freeFrom,
      periods: periods,
      active: periods.any((p) => p.end == null),
    );

void main() {
  group('Billing (mismas reglas que functions/premium.js)', () {
    test('meses en hora de Bogotá', () {
      expect(Billing.monthStart(2026, 12), DateTime.utc(2026, 12, 1, 5));
      expect(Billing.monthStart(2026, 13), DateTime.utc(2027, 1, 1, 5));
      // 30 de nov a las 23:00 de Bogotá sigue siendo noviembre.
      expect(Billing.bogotaMonthOf(DateTime.utc(2026, 12, 1, 4)),
          (year: 2026, month: 11));
      expect(Billing.dueDateFor(2026, 11), DateTime.utc(2026, 12, 6, 4, 59, 59));
    });

    test('el mes de activación es gratis y se cobra desde el siguiente', () {
      final a = athlete(
        freeFrom: Billing.monthStart(2026, 12),
        periods: [PremiumPeriod(DateTime.utc(2026, 11, 19, 15), null)],
      );
      expect(a.isBillableIn(2026, 11), isFalse);
      expect(a.isInFreeMonth(2026, 11), isTrue);
      expect(a.isBillableIn(2026, 12), isTrue);
    });

    test('retiro el 8 de febrero: se cobran solo los días con premium', () {
      final a = athlete(
        freeFrom: Billing.monthStart(2026, 12),
        periods: [
          // 17 nov 10:00 → 8 feb 15:00 (hora de Bogotá)
          PremiumPeriod(DateTime.utc(2026, 11, 17, 15), DateTime.utc(2027, 2, 8, 20)),
        ],
      );
      expect(a.billableDaysIn(2026, 11), 0);
      expect(a.amountIn(2026, 12), 4000);
      expect(a.amountIn(2027, 1), 4000);
      expect(a.billableDaysIn(2027, 2), 8);
      expect(a.amountIn(2027, 2), 1143);
      expect(a.isBillableIn(2027, 3), isFalse);
    });

    test('reactivación sin mes gratis: se cobra desde el día que vuelve', () {
      final a = athlete(
        freeFrom: Billing.monthStart(2026, 12),
        periods: [
          PremiumPeriod(DateTime.utc(2026, 11, 17, 15), DateTime.utc(2026, 11, 28, 15)),
          PremiumPeriod(DateTime.utc(2027, 1, 10, 15), null),
        ],
      );
      expect(a.isBillableIn(2026, 12), isFalse);
      expect(a.billableDaysIn(2027, 1), 22);
      expect(a.amountIn(2027, 1), 2839);
    });

    test('proyección y formato', () {
      final list = [
        athlete(
          freeFrom: Billing.monthStart(2026, 11),
          periods: [PremiumPeriod(DateTime.utc(2026, 10, 2), null)],
        ),
        athlete(
          freeFrom: Billing.monthStart(2026, 12),
          periods: [PremiumPeriod(DateTime.utc(2026, 11, 18), null)],
        ),
      ];
      final p = BillingProjection.forMonth(list, 2026, 11);
      expect(p.billable.length, 1);
      expect(p.freeMonth.length, 1);
      expect(p.total, 4000);
      expect(Billing.formatCop(124000), r'$124.000');
      expect(Billing.formatCop(4000), r'$4.000');
      expect(Billing.formatCop(0), r'$0');
      expect(Billing.monthLabelFromId('202612'), 'diciembre de 2026');
    });
  });

  group('FreeTier', () {
    Routine routine(String name, {String? templateId}) => Routine(
          userId: 'u',
          type: 'PPL',
          name: name,
          weekNumber: 1,
          createdAt: DateTime(2026),
          days: const [],
          templateId: templateId,
        );

    test('solo las tres TrainApp son gratis', () {
      expect(FreeTier.isFreeRoutine(routine('x', templateId: 'trainapp_duty')), isTrue);
      expect(FreeTier.isFreeRoutine(routine('x', templateId: 'ppl_clasico')), isFalse);
      // Rutinas viejas sin templateId: por nombre.
      expect(FreeTier.isFreeRoutine(routine('TrainApp Hard Duty')), isTrue);
      expect(FreeTier.isFreeRoutine(routine('PPL generado')), isFalse);
    });

    test('rutina gratis según días por semana', () {
      expect(FreeTier.templateIdForDays(3), FreeTier.lightDutyId);
      expect(FreeTier.templateIdForDays(4), FreeTier.dutyId);
      expect(FreeTier.templateIdForDays(6), FreeTier.hardDutyId);
      expect(FreeTier.templateIdForDays(null), FreeTier.dutyId);
    });

    test('templateId sobrevive a toMap/fromMap y copyWith', () {
      final r = routine('TrainApp Duty', templateId: 'trainapp_duty');
      final back = Routine.fromMap('u', r.toMap());
      expect(back.templateId, 'trainapp_duty');
      expect(back.copyWith(days: const []).templateId, 'trainapp_duty');
    });
  });
}
