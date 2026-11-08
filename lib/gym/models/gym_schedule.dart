import 'package:cloud_firestore/cloud_firestore.dart';

/// Horario semanal de una clase grupal (`gyms/{gymId}/schedules/{id}`). Lo
/// administra el staff en el portal; la Cloud Function `syncGymSchedule`
/// genera con él las clases de los próximos 14 días.
class GymSchedule {
  static const weekdayLabels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  final String id;
  final String name;
  final String description;
  final String instructor;

  /// Días ISO: lunes = 1 … domingo = 7.
  final List<int> weekdays;

  /// Hora de inicio en Bogotá, "HH:mm".
  final String startTime;
  final int durationMin;
  final int capacity;
  final bool active;

  const GymSchedule({
    required this.id,
    required this.name,
    this.description = '',
    this.instructor = '',
    required this.weekdays,
    required this.startTime,
    required this.durationMin,
    required this.capacity,
    this.active = true,
  });

  String get weekdaysLabel =>
      ([...weekdays]..sort()).map((d) => weekdayLabels[d - 1]).join(', ');

  Map<String, dynamic> toMap() => {
        'name': name.trim(),
        'description': description.trim(),
        'instructor': instructor.trim(),
        'weekdays': [...weekdays]..sort(),
        'startTime': startTime,
        'durationMin': durationMin,
        'capacity': capacity,
        'active': active,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory GymSchedule.fromMap(String id, Map<String, dynamic> m) => GymSchedule(
        id: id,
        name: m['name'] as String? ?? '',
        description: m['description'] as String? ?? '',
        instructor: m['instructor'] as String? ?? '',
        weekdays: [
          for (final d in (m['weekdays'] as List? ?? [])) (d as num).toInt(),
        ],
        startTime: m['startTime'] as String? ?? '00:00',
        durationMin: (m['durationMin'] as num?)?.toInt() ?? 60,
        capacity: (m['capacity'] as num?)?.toInt() ?? 1,
        active: m['active'] as bool? ?? true,
      );
}
