import 'progression_type.dart';

class RoutineExercise {
  final String exerciseId;
  final String name;
  final int sets;
  final int repsMin;
  final int repsMax;
  final double currentWeight;
  final int restSeconds;
  final String weightUnit;       // 'kg' | 'lbs' | 'unidades'
  final double progressionStep;  // e.g. 1.25, 2.5, 5.0, 10.0
  final ProgressionType progressionType;
  final bool isIsometric; // true para plancha y similares: se ejecuta con cronómetro,
                           // repsMin/repsMax representan segundos objetivo, no repeticiones.

  const RoutineExercise({
    required this.exerciseId,
    required this.name,
    required this.sets,
    required this.repsMin,
    required this.repsMax,
    this.currentWeight = 0,
    required this.restSeconds,
    this.weightUnit = 'kg',
    this.progressionStep = 2.5,
    this.progressionType = ProgressionType.doubleLinear,
    this.isIsometric = false,
  });

  Map<String, dynamic> toMap() => {
        'exerciseId': exerciseId,
        'name': name,
        'sets': sets,
        'repsMin': repsMin,
        'repsMax': repsMax,
        'currentWeight': currentWeight,
        'restSeconds': restSeconds,
        'weightUnit': weightUnit,
        'progressionStep': progressionStep,
        'progressionType': progressionType.id,
        'isIsometric': isIsometric,
      };

  factory RoutineExercise.fromMap(Map<String, dynamic> m) => RoutineExercise(
        exerciseId: m['exerciseId'] as String,
        name: m['name'] as String,
        sets: m['sets'] as int,
        repsMin: m['repsMin'] as int,
        repsMax: m['repsMax'] as int,
        currentWeight: (m['currentWeight'] as num).toDouble(),
        restSeconds: m['restSeconds'] as int,
        weightUnit: m['weightUnit'] as String? ?? 'kg',
        progressionStep: (m['progressionStep'] as num?)?.toDouble() ?? 2.5,
        progressionType:
            ProgressionTypeX.fromId(m['progressionType'] as String?),
        isIsometric: m['isIsometric'] as bool? ?? false,
      );

  RoutineExercise copyWith({
    String? exerciseId,
    String? name,
    int? sets,
    int? repsMin,
    int? repsMax,
    double? currentWeight,
    int? restSeconds,
    String? weightUnit,
    double? progressionStep,
    ProgressionType? progressionType,
    bool? isIsometric,
  }) =>
      RoutineExercise(
        exerciseId: exerciseId ?? this.exerciseId,
        name: name ?? this.name,
        sets: sets ?? this.sets,
        repsMin: repsMin ?? this.repsMin,
        repsMax: repsMax ?? this.repsMax,
        currentWeight: currentWeight ?? this.currentWeight,
        restSeconds: restSeconds ?? this.restSeconds,
        weightUnit: weightUnit ?? this.weightUnit,
        progressionStep: progressionStep ?? this.progressionStep,
        progressionType: progressionType ?? this.progressionType,
        isIsometric: isIsometric ?? this.isIsometric,
      );
}

class RoutineDay {
  final int dayNumber;
  final String name;   // "Push", "Pull", "Legs", "Upper A", "Lower A"
  final String focus;  // "push" | "pull" | "legs" | "upper" | "lower"
  final List<RoutineExercise> exercises;

  const RoutineDay({
    required this.dayNumber,
    required this.name,
    required this.focus,
    required this.exercises,
  });

  Map<String, dynamic> toMap() => {
        'dayNumber': dayNumber,
        'name': name,
        'focus': focus,
        'exercises': exercises.map((e) => e.toMap()).toList(),
      };

  factory RoutineDay.fromMap(Map<String, dynamic> m) => RoutineDay(
        dayNumber: m['dayNumber'] as int,
        name: m['name'] as String,
        focus: m['focus'] as String,
        exercises: (m['exercises'] as List)
            .map((e) => RoutineExercise.fromMap(e as Map<String, dynamic>))
            .toList(),
      );
}

class Routine {
  final String userId;
  final String type;  // PPL | UpperLower | FullBody
  final String name;
  final int weekNumber;
  final DateTime createdAt;
  final List<RoutineDay> days;

  Routine({
    required this.userId,
    required this.type,
    required this.name,
    required this.weekNumber,
    required this.createdAt,
    required this.days,
  });

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'type': type,
        'name': name,
        'weekNumber': weekNumber,
        'createdAt': createdAt.toIso8601String(),
        'days': days.map((d) => d.toMap()).toList(),
      };

  factory Routine.fromMap(String userId, Map<String, dynamic> m) => Routine(
        userId: userId,
        type: m['type'] as String,
        name: m['name'] as String,
        weekNumber: m['weekNumber'] as int? ?? 1,
        createdAt: DateTime.parse(m['createdAt'] as String),
        days: (m['days'] as List)
            .map((d) => RoutineDay.fromMap(d as Map<String, dynamic>))
            .toList(),
      );
}
