import 'package:flutter_test/flutter_test.dart';
import 'package:trainapp_mobile/home/streak.dart';

/// Semanas con el mismo objetivo; la última es la semana en curso.
List<WeekRecord> weeks(List<int> done, {int planned = 4}) =>
    [for (final d in done) WeekRecord(done: d, planned: planned)];

void main() {
  test('semanas completas y con un día menos mantienen la racha', () {
    expect(Streak.compute(weeks([4, 3, 4, 3, 0])).weeks, 4);
  });

  test('la semana en curso suma al llegar al mínimo y nunca corta', () {
    expect(Streak.compute(weeks([4, 4, 0])).weeks, 2);
    expect(Streak.compute(weeks([4, 4, 3])).weeks, 3);
  });

  test('tres días menos cortan la racha', () {
    expect(Streak.compute(weeks([4, 4, 1, 4, 0])).weeks, 1);
  });

  test('dos días menos se salvan completando la semana siguiente', () {
    expect(Streak.compute(weeks([4, 2, 4, 0])).weeks, 3);
  });

  test('dos días menos sin completar la siguiente pierden la racha', () {
    // La semana de 3 no salva la racha, pero empieza una nueva.
    expect(Streak.compute(weeks([4, 4, 2, 3, 0])).weeks, 1);
    expect(Streak.compute(weeks([4, 4, 2, 0, 0])).weeks, 0);
  });

  test('en riesgo durante la semana en curso', () {
    final r = Streak.compute(weeks([4, 4, 2, 1]));
    expect(r.weeks, 3);
    expect(r.atRisk, isTrue);
    expect(r.daysToSave, 3);

    final saved = Streak.compute(weeks([4, 4, 2, 4]));
    expect(saved.weeks, 4);
    expect(saved.atRisk, isFalse);
  });

  test('una semana sin entrenar nunca mantiene la racha', () {
    expect(Streak.compute(weeks([1, 0, 0], planned: 1)).weeks, 0);
    expect(Streak.compute(weeks([2, 0, 0], planned: 2)).weeks, 0);
    expect(Streak.compute(weeks([2, 1, 0], planned: 2)).weeks, 2);
  });

  test('cada semana se mide con el objetivo que tenía', () {
    // 3 de 5 (dos menos) y luego cambio a rutina de 3: la semana con
    // objetivo 3 completa la salva; la de 5 sigue contando como de 5.
    final r = Streak.compute(const [
      WeekRecord(done: 5, planned: 5),
      WeekRecord(done: 3, planned: 5),
      WeekRecord(done: 3, planned: 3),
      WeekRecord(done: 0, planned: 3),
    ]);
    expect(r.weeks, 3);

    // 2 de 5 cortó la racha aunque hoy la rutina sea de 3 días.
    expect(
      Streak.compute(const [
        WeekRecord(done: 5, planned: 5),
        WeekRecord(done: 2, planned: 5),
        WeekRecord(done: 0, planned: 3),
      ]).weeks,
      0,
    );
  });
}
