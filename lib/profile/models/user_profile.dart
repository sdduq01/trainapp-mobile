enum TrainingGoal {
  fatLoss,
  muscleGain,
  recomposition,
  sportComplement,
}

class UserProfile {
  final String uid;
  final double? weight;
  final double? height;
  final double? bodyFat;
  final int? trainingExperienceMonths;
  final int? trainingDaysPerWeek;
  final TrainingGoal? goal;
  final bool completedOnboarding;

  UserProfile({
    required this.uid,
    this.weight,
    this.height,
    this.bodyFat,
    this.trainingExperienceMonths,
    this.trainingDaysPerWeek,
    this.goal,
    required this.completedOnboarding,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      weight: (data['weight'] as num?)?.toDouble(),
      height: (data['height'] as num?)?.toDouble(),
      bodyFat: (data['bodyFat'] as num?)?.toDouble(),
      trainingExperienceMonths: data['trainingExperienceMonths'] as int?,
      trainingDaysPerWeek: data['trainingDaysPerWeek'] as int?,
      goal: data['goal'] != null
          ? TrainingGoal.values[data['goal'] as int]
          : null,
      completedOnboarding: data['completedOnboarding'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'weight': weight,
      'height': height,
      'bodyFat': bodyFat,
      'trainingExperienceMonths': trainingExperienceMonths,
      'trainingDaysPerWeek': trainingDaysPerWeek,
      'goal': goal?.index,
      'completedOnboarding': completedOnboarding,
    };
  }

  UserProfile copyWith({
    double? weight,
    double? height,
    double? bodyFat,
    int? trainingExperienceMonths,
    TrainingGoal? goal,
    bool? completedOnboarding,
  }) {
    return UserProfile(
      uid: uid,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      bodyFat: bodyFat ?? this.bodyFat,
      trainingExperienceMonths:
          trainingExperienceMonths ?? this.trainingExperienceMonths,
      goal: goal ?? this.goal,
      completedOnboarding:
          completedOnboarding ?? this.completedOnboarding,
    );
  }
}
