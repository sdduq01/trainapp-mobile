import 'package:flutter_test/flutter_test.dart';
import 'package:trainapp_mobile/core/utils/iso_week.dart';

void main() {
  test('semana 38 de 2026 va del lunes 14 al domingo 20 de septiembre', () {
    expect(IsoWeek.weekNumber(DateTime(2026, 9, 13)), 37);
    expect(IsoWeek.weekNumber(DateTime(2026, 9, 14)), 38);
    expect(IsoWeek.weekNumber(DateTime(2026, 9, 20, 23, 59)), 38);
    expect(IsoWeek.weekNumber(DateTime(2026, 9, 21)), 39);
  });

  test('bordes de año', () {
    // 2026-01-01 es jueves: semana 1 arranca el lunes 2025-12-29.
    expect(IsoWeek.weekNumber(DateTime(2025, 12, 29)), 1);
    expect(IsoWeek.year(DateTime(2025, 12, 29)), 2026);
    expect(IsoWeek.firstMonday(2026), DateTime(2025, 12, 29));
    // 2027-01-01 es viernes: pertenece a la semana 53 de 2026.
    expect(IsoWeek.weekNumber(DateTime(2027, 1, 1)), 53);
    expect(IsoWeek.year(DateTime(2027, 1, 1)), 2026);
    expect(IsoWeek.firstMonday(2027), DateTime(2027, 1, 4));
  });
}
