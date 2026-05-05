class Exercise {
  final String id;
  final String name;
  final String muscle; // push | pull | legs
  final int defaultSets;
  final int defaultRepsMin;
  final int defaultRepsMax;
  final int restSeconds;
  final String defaultWeightUnit;     // 'kg' | 'lbs'
  final double defaultProgressionStep;

  const Exercise({
    required this.id,
    required this.name,
    required this.muscle,
    required this.defaultSets,
    required this.defaultRepsMin,
    required this.defaultRepsMax,
    required this.restSeconds,
    this.defaultWeightUnit = 'kg',
    this.defaultProgressionStep = 2.5,
  });

  factory Exercise.fromMap(String id, Map<String, dynamic> m) => Exercise(
        id: id,
        name: m['name'] as String,
        muscle: m['muscle'] as String,
        defaultSets: (m['defaultSets'] as num?)?.toInt() ?? 3,
        defaultRepsMin: (m['defaultRepsMin'] as num?)?.toInt() ?? 8,
        defaultRepsMax: (m['defaultRepsMax'] as num?)?.toInt() ?? 12,
        restSeconds: (m['restSeconds'] as num?)?.toInt() ?? 90,
        defaultWeightUnit: m['defaultWeightUnit'] as String? ?? 'kg',
        defaultProgressionStep:
            (m['defaultProgressionStep'] as num?)?.toDouble() ?? 2.5,
      );
}
