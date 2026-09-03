class Exercise {
  final String id;
  final String name;
  final String muscle; // push | pull | legs — usado por el generador automático de rutinas
  final String muscleGroup; // grupo muscular específico: pecho, espalda, biceps, gemelos...
  final int defaultSets;
  final int defaultRepsMin;
  final int defaultRepsMax;
  final int restSeconds;
  final String defaultWeightUnit;     // 'kg' | 'lbs' | 'unidades'
  final double defaultProgressionStep;
  final bool isIsometric; // true para plancha y similares: se ejecuta con cronómetro,
                           // defaultRepsMin/Max representan segundos objetivo, no repeticiones.

  const Exercise({
    required this.id,
    required this.name,
    required this.muscle,
    required this.muscleGroup,
    required this.defaultSets,
    required this.defaultRepsMin,
    required this.defaultRepsMax,
    required this.restSeconds,
    this.defaultWeightUnit = 'kg',
    this.defaultProgressionStep = 2.5,
    this.isIsometric = false,
  });

  factory Exercise.fromMap(String id, Map<String, dynamic> m) => Exercise(
        id: id,
        name: m['name'] as String,
        muscle: m['muscle'] as String,
        muscleGroup: m['muscleGroup'] as String? ?? 'otros',
        defaultSets: (m['defaultSets'] as num?)?.toInt() ?? 3,
        defaultRepsMin: (m['defaultRepsMin'] as num?)?.toInt() ?? 8,
        defaultRepsMax: (m['defaultRepsMax'] as num?)?.toInt() ?? 12,
        restSeconds: (m['restSeconds'] as num?)?.toInt() ?? 90,
        defaultWeightUnit: m['defaultWeightUnit'] as String? ?? 'kg',
        defaultProgressionStep:
            (m['defaultProgressionStep'] as num?)?.toDouble() ?? 2.5,
        isIsometric: m['isIsometric'] as bool? ?? false,
      );
}
