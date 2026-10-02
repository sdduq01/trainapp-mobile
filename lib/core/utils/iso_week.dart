/// Semanas ISO 8601: de lunes a domingo, y la semana 1 es la que contiene el
/// primer jueves del año. Es la única cuenta de semanas de la app — la gráfica
/// de consistencia, los eventos de progresión y los hitos deben coincidir.
class IsoWeek {
  /// El jueves de la semana de [date] determina el año y el número ISO
  /// (evita edge cases en ene/dic).
  static DateTime _thursdayOf(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.add(Duration(days: DateTime.thursday - d.weekday));
  }

  static int weekNumber(DateTime date) {
    final thursday = _thursdayOf(date);
    final startOfYear = DateTime(thursday.year, 1, 1);
    return (thursday.difference(startOfYear).inDays / 7).floor() + 1;
  }

  static int year(DateTime date) => _thursdayOf(date).year;

  /// Lunes (00:00 local) de la semana ISO 1 de [isoYear].
  static DateTime firstMonday(int isoYear) {
    final jan4 = DateTime(isoYear, 1, 4); // siempre cae en la semana 1
    return jan4.subtract(Duration(days: jan4.weekday - DateTime.monday));
  }
}
