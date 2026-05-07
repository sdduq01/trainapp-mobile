import 'routine.dart';

/// Plantilla de rutina disponible en el catálogo (Recomendadas, Deportes).
/// No tiene userId ni currentWeight: al activarla se construye una [Routine]
/// concreta para el usuario actual.
class RoutineTemplate {
  final String id;
  final String category;     // 'recommended' | 'sport'
  final String name;
  final String description;
  final String? sport;       // 'futbol', etc. Solo para category == 'sport'
  final String type;         // 'PPL' | 'UpperLower' | 'FullBody' | 'Sport'
  final List<RoutineDay> days;

  const RoutineTemplate({
    required this.id,
    required this.category,
    required this.name,
    required this.description,
    required this.type,
    required this.days,
    this.sport,
  });

  factory RoutineTemplate.fromMap(String id, Map<String, dynamic> m) =>
      RoutineTemplate(
        id: id,
        category: m['category'] as String,
        name: m['name'] as String,
        description: m['description'] as String? ?? '',
        type: m['type'] as String? ?? 'Custom',
        sport: m['sport'] as String?,
        days: (m['days'] as List)
            .map((d) => RoutineDay.fromMap(d as Map<String, dynamic>))
            .toList(),
      );

  /// Convierte la plantilla en una rutina activa para [userId].
  /// currentWeight siempre 0 para que el usuario establezca sus marcas.
  Routine toRoutine(String userId) => Routine(
        userId: userId,
        type: type,
        name: name,
        weekNumber: 1,
        createdAt: DateTime.now(),
        days: days,
      );
}
