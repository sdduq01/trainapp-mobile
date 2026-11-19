import 'package:cloud_firestore/cloud_firestore.dart';

/// Facturación del premium que los gimnasios activan a sus atletas. Las
/// reglas son las mismas de `functions/premium.js`, que es quien genera las
/// facturas; aquí se usan para la proyección del mes en curso.
///
/// - $4.000 COP por atleta premium al mes, proporcional a los días del mes
///   en que tuvo premium (un día con premium cuenta completo).
/// - El mes en que se activa por primera vez es gratis: se cobra desde el
///   día 1 del mes siguiente (`freeFrom`). El mes gratis es uno solo por
///   atleta y gimnasio.
/// - La factura del mes se genera el día 1 del mes siguiente y vence el 5.
///
/// Meses en hora de Bogotá (UTC-5 fijo, Colombia no tiene horario de verano).
class Billing {
  Billing._();

  static const int pricePerAthlete = 4000;
  static const int dueDay = 5;
  static const int _bogotaOffsetHours = 5;

  static const List<String> monthNames = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
    'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  /// Instante (UTC) en que empieza el mes [month] (1-12) de [year] en Bogotá.
  /// Acepta meses fuera de rango (13 = enero del año siguiente).
  static DateTime monthStart(int year, int month) =>
      DateTime.utc(year, month, 1, _bogotaOffsetHours);

  /// (año, mes 1-12) en Bogotá del instante [date].
  static ({int year, int month}) bogotaMonthOf(DateTime date) {
    final local =
        date.toUtc().subtract(const Duration(hours: _bogotaOffsetHours));
    return (year: local.year, month: local.month);
  }

  /// Último instante del plazo de pago de la factura del mes [month]: día 5
  /// del mes siguiente a las 23:59:59 de Bogotá.
  static DateTime dueDateFor(int year, int month) => monthStart(year, month + 1)
      .add(const Duration(days: dueDay))
      .subtract(const Duration(seconds: 1));

  static int daysInMonth(int year, int month) =>
      DateTime.utc(year, month + 1, 0).day;

  /// Valor de [days] días del mes: proporcional, redondeado al peso.
  static int amountForDays(int days, int year, int month) =>
      (pricePerAthlete * days / daysInMonth(year, month)).round();

  /// Id de la factura del mes: 'yyyyMM'.
  static String monthId(int year, int month) =>
      '$year${month.toString().padLeft(2, '0')}';

  static String monthLabel(int year, int month) {
    final m = DateTime.utc(year, month);
    return '${monthNames[m.month - 1]} de ${m.year}';
  }

  static String monthLabelFromId(String id) =>
      monthLabel(int.parse(id.substring(0, 4)), int.parse(id.substring(4)));

  /// Pesos colombianos con punto de miles: 12000 → "$12.000".
  static String formatCop(int value) {
    final digits = value.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
      buf.write(digits[i]);
    }
    return '${value < 0 ? '-' : ''}\$$buf';
  }

  /// Fecha corta en hora de Bogotá: "5 de diciembre".
  static String formatDay(DateTime date) {
    final local =
        date.toUtc().subtract(const Duration(hours: _bogotaOffsetHours));
    return '${local.day} de ${monthNames[local.month - 1]}';
  }
}

class PremiumPeriod {
  final DateTime start;
  final DateTime? end; // null = sigue activo

  const PremiumPeriod(this.start, this.end);

  bool overlaps(DateTime from, DateTime to) =>
      start.isBefore(to) && (end == null || end!.isAfter(from));
}

/// `gyms/{gymId}/billing_athletes/{uid}`: lo escribe solo el servidor.
class BillingAthlete {
  final String uid;
  final String email;
  final DateTime firstPremiumAt;
  final DateTime freeFrom;
  final List<PremiumPeriod> periods;
  final bool active;

  const BillingAthlete({
    required this.uid,
    required this.email,
    required this.firstPremiumAt,
    required this.freeFrom,
    required this.periods,
    required this.active,
  });

  factory BillingAthlete.fromMap(String uid, Map<String, dynamic> m) =>
      BillingAthlete(
        uid: uid,
        email: m['email'] as String? ?? '',
        firstPremiumAt: (m['firstPremiumAt'] as Timestamp).toDate(),
        freeFrom: (m['freeFrom'] as Timestamp).toDate(),
        periods: [
          for (final p in (m['periods'] as List? ?? []))
            PremiumPeriod(
              ((p as Map)['start'] as Timestamp).toDate(),
              (p['end'] as Timestamp?)?.toDate(),
            ),
        ],
        active: m['active'] as bool? ?? false,
      );

  bool hadPremiumIn(int year, int month) => periods.any((p) =>
      p.overlaps(Billing.monthStart(year, month), Billing.monthStart(year, month + 1)));

  /// Días del mes [month] de [year] que se le cobran: los días (de Bogotá)
  /// con premium, si el mes ya pasó su mes gratis. Un periodo abierto cuenta
  /// hasta fin de mes (por eso sirve de proyección).
  int billableDaysIn(int year, int month) {
    final start = Billing.monthStart(year, month);
    if (freeFrom.isAfter(start)) return 0;
    var days = 0;
    for (var d = 0; d < Billing.daysInMonth(year, month); d++) {
      final dayStart = start.add(Duration(days: d));
      final dayEnd = dayStart.add(const Duration(days: 1));
      if (periods.any((p) => p.overlaps(dayStart, dayEnd))) days++;
    }
    return days;
  }

  int amountIn(int year, int month) =>
      Billing.amountForDays(billableDaysIn(year, month), year, month);

  /// ¿Se le cobra algo del mes [month] de [year]?
  bool isBillableIn(int year, int month) => billableDaysIn(year, month) > 0;

  /// ¿Tiene premium este mes pero todavía en su mes gratis?
  bool isInFreeMonth(int year, int month) =>
      hadPremiumIn(year, month) && !isBillableIn(year, month);
}

/// Proyección de la factura de un mes que aún no se ha generado.
class BillingProjection {
  final int year;
  final int month;
  final List<BillingAthlete> billable;
  final List<BillingAthlete> freeMonth;

  BillingProjection._(this.year, this.month, this.billable, this.freeMonth);

  factory BillingProjection.forMonth(
    List<BillingAthlete> athletes,
    int year,
    int month,
  ) {
    int byEmail(BillingAthlete a, BillingAthlete b) => a.email.compareTo(b.email);
    return BillingProjection._(
      year,
      month,
      athletes.where((a) => a.isBillableIn(year, month)).toList()..sort(byEmail),
      athletes.where((a) => a.isInFreeMonth(year, month)).toList()..sort(byEmail),
    );
  }

  int get total =>
      billable.fold(0, (acc, a) => acc + a.amountIn(year, month));
  DateTime get dueAt => Billing.dueDateFor(year, month);
}

/// `gyms/{gymId}/invoices/{yyyyMM}`: la genera el servidor el día 1; el admin
/// la marca como pagada.
class GymInvoice {
  final String id; // yyyyMM
  final String gymId;
  final String gymName;
  final int unitPrice;
  final int daysInMonth;
  final int count;
  final int total;
  final List<({String uid, String email, int days, int amount})> lines;
  final String status; // pending | paid
  final DateTime issuedAt;
  final DateTime dueAt;
  final DateTime? paidAt;
  final String paidNote;

  const GymInvoice({
    required this.id,
    required this.gymId,
    required this.gymName,
    required this.unitPrice,
    required this.daysInMonth,
    required this.count,
    required this.total,
    required this.lines,
    required this.status,
    required this.issuedAt,
    required this.dueAt,
    this.paidAt,
    this.paidNote = '',
  });

  factory GymInvoice.fromMap(String id, Map<String, dynamic> m) => GymInvoice(
        id: id,
        gymId: m['gymId'] as String? ?? '',
        gymName: m['gymName'] as String? ?? '',
        unitPrice: (m['unitPrice'] as num?)?.toInt() ?? Billing.pricePerAthlete,
        daysInMonth: (m['daysInMonth'] as num?)?.toInt() ?? 30,
        count: (m['count'] as num?)?.toInt() ?? 0,
        total: (m['total'] as num?)?.toInt() ?? 0,
        lines: [
          for (final l in (m['lines'] as List? ?? []))
            (
              uid: (l as Map)['uid'] as String? ?? '',
              email: l['email'] as String? ?? '',
              // Facturas anteriores al prorrateo: mes completo.
              days: (l['days'] as num?)?.toInt() ??
                  ((m['daysInMonth'] as num?)?.toInt() ?? 30),
              amount: (l['amount'] as num?)?.toInt() ??
                  ((m['unitPrice'] as num?)?.toInt() ?? Billing.pricePerAthlete),
            ),
        ],
        status: m['status'] as String? ?? 'pending',
        issuedAt: (m['issuedAt'] as Timestamp).toDate(),
        dueAt: (m['dueAt'] as Timestamp).toDate(),
        paidAt: (m['paidAt'] as Timestamp?)?.toDate(),
        paidNote: m['paidNote'] as String? ?? '',
      );

  bool get isPaid => status == 'paid';
  bool isOverdue([DateTime? now]) =>
      !isPaid && (now ?? DateTime.now()).isAfter(dueAt);

  String get monthLabel => Billing.monthLabelFromId(id);
}
