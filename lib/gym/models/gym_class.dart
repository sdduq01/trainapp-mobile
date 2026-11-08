import 'package:cloud_firestore/cloud_firestore.dart';

/// Hora de Colombia (UTC-5 fijo, sin horario de verano). Las clases se
/// muestran siempre en hora de Bogotá, sin importar la zona del dispositivo.
abstract final class BogotaTime {
  static const offset = Duration(hours: -5);

  /// [utc] expresado como fecha/hora de Bogotá. El resultado es un DateTime
  /// UTC cuyos campos (día, hora…) son los de Bogotá: solo para mostrar.
  static DateTime fromUtc(DateTime utc) => utc.toUtc().add(offset);

  /// Instante real de una fecha/hora de Bogotá.
  static DateTime toUtc(int year, int month, int day, int hour, int minute) =>
      DateTime.utc(year, month, day, hour, minute).subtract(offset);

  static DateTime now() => fromUtc(DateTime.now().toUtc());

  static String hhmm(DateTime bogota) =>
      '${bogota.hour.toString().padLeft(2, '0')}:'
      '${bogota.minute.toString().padLeft(2, '0')}';

  static const _weekdays = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo',
  ];
  static const _months = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  /// "Martes 28 oct".
  static String dayLabel(DateTime bogota) =>
      '${_weekdays[bogota.weekday - 1]} ${bogota.day} ${_months[bogota.month - 1]}';
}

/// Clase grupal concreta (`gyms/{gymId}/classes/{id}`). Las de un horario
/// las genera la Cloud Function; las sueltas las crea el staff.
class GymClass {
  static const statusScheduled = 'scheduled';
  static const statusCancelled = 'cancelled';

  final String id;
  final String gymId;
  final String name;
  final String description;
  final String instructor;
  final DateTime startsAt; // UTC
  final int durationMin;
  final int capacity;
  final int enrolledCount;
  final String status;
  final String? scheduleId;

  /// El staff la editó a mano: los cambios del horario ya no la tocan.
  final bool edited;

  const GymClass({
    required this.id,
    required this.gymId,
    required this.name,
    this.description = '',
    this.instructor = '',
    required this.startsAt,
    required this.durationMin,
    required this.capacity,
    this.enrolledCount = 0,
    this.status = statusScheduled,
    this.scheduleId,
    this.edited = false,
  });

  bool get isCancelled => status == statusCancelled;
  bool get isFull => enrolledCount >= capacity;
  int get freeSpots => (capacity - enrolledCount).clamp(0, capacity);
  DateTime get endsAt => startsAt.add(Duration(minutes: durationMin));
  DateTime get startsAtBogota => BogotaTime.fromUtc(startsAt);

  /// "06:00 – 06:45" en hora de Bogotá.
  String get timeRange =>
      '${BogotaTime.hhmm(startsAtBogota)} – ${BogotaTime.hhmm(BogotaTime.fromUtc(endsAt))}';

  /// Último instante para cancelar la inscripción.
  DateTime cancelDeadline(int cancelWindowHours) =>
      startsAt.subtract(Duration(hours: cancelWindowHours));

  Map<String, dynamic> toMap() => {
        'name': name.trim(),
        'description': description.trim(),
        'instructor': instructor.trim(),
        'startsAt': Timestamp.fromDate(startsAt),
        'durationMin': durationMin,
        'capacity': capacity,
        'enrolledCount': enrolledCount,
        'status': status,
        'scheduleId': scheduleId,
        'edited': edited,
      };

  factory GymClass.fromMap(String gymId, String id, Map<String, dynamic> m) =>
      GymClass(
        id: id,
        gymId: gymId,
        name: m['name'] as String? ?? '',
        description: m['description'] as String? ?? '',
        instructor: m['instructor'] as String? ?? '',
        startsAt: (m['startsAt'] as Timestamp).toDate().toUtc(),
        durationMin: (m['durationMin'] as num?)?.toInt() ?? 60,
        capacity: (m['capacity'] as num?)?.toInt() ?? 1,
        enrolledCount: (m['enrolledCount'] as num?)?.toInt() ?? 0,
        status: m['status'] as String? ?? statusScheduled,
        scheduleId: m['scheduleId'] as String?,
        edited: m['edited'] as bool? ?? false,
      );

  GymClass copyWith({
    String? name,
    String? description,
    String? instructor,
    DateTime? startsAt,
    int? durationMin,
    int? capacity,
    String? status,
    bool? edited,
  }) =>
      GymClass(
        id: id,
        gymId: gymId,
        name: name ?? this.name,
        description: description ?? this.description,
        instructor: instructor ?? this.instructor,
        startsAt: startsAt ?? this.startsAt,
        durationMin: durationMin ?? this.durationMin,
        capacity: capacity ?? this.capacity,
        enrolledCount: enrolledCount,
        status: status ?? this.status,
        scheduleId: scheduleId,
        edited: edited ?? this.edited,
      );
}

/// Inscripción de un atleta a una clase (`.../enrollments/{uid}`).
class GymEnrollment {
  final String uid;
  final String gymId;
  final String classId;
  final DateTime startsAt;
  final String email;

  const GymEnrollment({
    required this.uid,
    required this.gymId,
    required this.classId,
    required this.startsAt,
    required this.email,
  });

  factory GymEnrollment.fromMap(Map<String, dynamic> m) => GymEnrollment(
        uid: m['uid'] as String,
        gymId: m['gymId'] as String,
        classId: m['classId'] as String,
        startsAt: (m['startsAt'] as Timestamp).toDate().toUtc(),
        email: m['email'] as String? ?? '',
      );
}
