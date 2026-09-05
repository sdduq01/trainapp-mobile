import 'routine.dart';

/// Rutina personalizada guardada por el usuario en "Mis rutinas"
/// (`custom_routines/{uid}/items/{id}`). Al usarla se construye una [Routine]
/// activa concreta.
class CustomRoutine {
  final String id;
  final String name;
  final String type; // normalmente 'Custom'
  final List<RoutineDay> days;
  final DateTime createdAt;

  const CustomRoutine({
    required this.id,
    required this.name,
    required this.type,
    required this.days,
    required this.createdAt,
  });

  int get totalExercises =>
      days.fold(0, (sum, d) => sum + d.exercises.length);

  Map<String, dynamic> toMap() => {
        'name': name,
        'type': type,
        'createdAt': createdAt.toIso8601String(),
        'days': days.map((d) => d.toMap()).toList(),
      };

  factory CustomRoutine.fromMap(String id, Map<String, dynamic> m) =>
      CustomRoutine(
        id: id,
        name: m['name'] as String? ?? 'Rutina',
        type: m['type'] as String? ?? 'Custom',
        days: (m['days'] as List? ?? [])
            .map((d) => RoutineDay.fromMap(d as Map<String, dynamic>))
            .toList(),
        createdAt:
            DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
      );

  /// Rutina activa para [userId] a partir de esta plantilla guardada.
  Routine toRoutine(String userId) => Routine(
        userId: userId,
        type: type,
        name: name,
        weekNumber: 1,
        createdAt: DateTime.now(),
        days: days,
      );
}
