class SessionSet {
  final int setNumber;
  final int repsTarget;
  final int repsDone;
  final double weight;
  final String weightUnit;

  const SessionSet({
    required this.setNumber,
    required this.repsTarget,
    required this.repsDone,
    required this.weight,
    required this.weightUnit,
  });

  Map<String, dynamic> toMap() => {
        'setNumber': setNumber,
        'repsTarget': repsTarget,
        'repsDone': repsDone,
        'weight': weight,
        'weightUnit': weightUnit,
      };

  factory SessionSet.fromMap(Map<String, dynamic> m) => SessionSet(
        setNumber: m['setNumber'] as int,
        repsTarget: m['repsTarget'] as int,
        repsDone: m['repsDone'] as int,
        weight: (m['weight'] as num).toDouble(),
        weightUnit: m['weightUnit'] as String? ?? 'kg',
      );
}

class SessionExercise {
  final String exerciseId;
  final String name;
  final List<SessionSet> sets;

  const SessionExercise({
    required this.exerciseId,
    required this.name,
    required this.sets,
  });

  Map<String, dynamic> toMap() => {
        'exerciseId': exerciseId,
        'name': name,
        'sets': sets.map((s) => s.toMap()).toList(),
      };

  factory SessionExercise.fromMap(Map<String, dynamic> m) => SessionExercise(
        exerciseId: m['exerciseId'] as String,
        name: m['name'] as String,
        sets: (m['sets'] as List)
            .map((s) => SessionSet.fromMap(s as Map<String, dynamic>))
            .toList(),
      );
}

class WorkoutSession {
  final String id;
  final String userId;
  final DateTime date;
  final int dayNumber;
  final String dayName;
  final String focus;
  final List<SessionExercise> exercises;
  final bool completed;

  WorkoutSession({
    required this.id,
    required this.userId,
    required this.date,
    required this.dayNumber,
    required this.dayName,
    required this.focus,
    required this.exercises,
    required this.completed,
  });

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'date': date.toIso8601String(),
        'dayNumber': dayNumber,
        'dayName': dayName,
        'focus': focus,
        'exercises': exercises.map((e) => e.toMap()).toList(),
        'completed': completed,
      };

  factory WorkoutSession.fromMap(String id, Map<String, dynamic> m) =>
      WorkoutSession(
        id: id,
        userId: m['userId'] as String,
        date: DateTime.parse(m['date'] as String),
        dayNumber: m['dayNumber'] as int,
        dayName: m['dayName'] as String,
        focus: m['focus'] as String,
        exercises: (m['exercises'] as List)
            .map((e) => SessionExercise.fromMap(e as Map<String, dynamic>))
            .toList(),
        completed: m['completed'] as bool? ?? false,
      );
}
