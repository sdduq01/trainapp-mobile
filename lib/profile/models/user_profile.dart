enum TrainingGoal {
  fatLoss,
  muscleGain,
  recomposition,
  sportComplement,
  mentalHealth,
}

class UserProfile {
  static const int kFailureCadenceMin = 3;
  static const int kFailureCadenceMax = 6;
  static const int kFailureCadenceDefault = 4;

  final String uid;
  final double? weight;
  final double? height;
  final double? bodyFat;
  final DateTime? birthDate;
  final int? trainingExperienceMonths;
  final int? trainingDaysPerWeek;
  final TrainingGoal? goal;
  final bool completedOnboarding;
  final bool intensityEnabled;
  final int failureWeekCadence;
  final bool warmupEnabled;    // series de aproximación automáticas antes de cada ejercicio
  final bool stretchingEnabled; // muestra el grupo "Estiramiento" en los selectores de ejercicio
  final bool cardioEnabled;     // muestra el grupo "Cardio" en los selectores de ejercicio

  UserProfile({
    required this.uid,
    this.weight,
    this.height,
    this.bodyFat,
    this.birthDate,
    this.trainingExperienceMonths,
    this.trainingDaysPerWeek,
    this.goal,
    required this.completedOnboarding,
    this.intensityEnabled = false,
    this.failureWeekCadence = kFailureCadenceDefault,
    this.warmupEnabled = false,
    this.stretchingEnabled = false,
    this.cardioEnabled = false,
  });

  int? get age {
    if (birthDate == null) return null;
    final now = DateTime.now();
    int years = now.year - birthDate!.year;
    final hasHadBirthday = (now.month > birthDate!.month) ||
        (now.month == birthDate!.month && now.day >= birthDate!.day);
    if (!hasHadBirthday) years--;
    return years;
  }

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    DateTime? parseBirthDate(dynamic value) {
      if (value == null) return null;
      if (value is String) return DateTime.tryParse(value);
      // Soporta Timestamp de Firestore sin importarlo aquí (toDate dinámico).
      try {
        return (value as dynamic).toDate() as DateTime;
      } catch (_) {
        return null;
      }
    }

    final cadence = (data['failureWeekCadence'] as num?)?.toInt() ??
        kFailureCadenceDefault;
    return UserProfile(
      uid: uid,
      weight: (data['weight'] as num?)?.toDouble(),
      height: (data['height'] as num?)?.toDouble(),
      bodyFat: (data['bodyFat'] as num?)?.toDouble(),
      birthDate: parseBirthDate(data['birthDate']),
      trainingExperienceMonths: data['trainingExperienceMonths'] as int?,
      trainingDaysPerWeek: data['trainingDaysPerWeek'] as int?,
      goal: data['goal'] != null
          ? TrainingGoal.values[data['goal'] as int]
          : null,
      completedOnboarding: data['completedOnboarding'] as bool? ?? false,
      intensityEnabled: data['intensityEnabled'] as bool? ?? false,
      failureWeekCadence:
          cadence.clamp(kFailureCadenceMin, kFailureCadenceMax),
      warmupEnabled: data['warmupEnabled'] as bool? ?? false,
      stretchingEnabled: data['stretchingEnabled'] as bool? ?? false,
      cardioEnabled: data['cardioEnabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'weight': weight,
      'height': height,
      'bodyFat': bodyFat,
      'birthDate': birthDate?.toIso8601String(),
      'trainingExperienceMonths': trainingExperienceMonths,
      'trainingDaysPerWeek': trainingDaysPerWeek,
      'goal': goal?.index,
      'completedOnboarding': completedOnboarding,
      'intensityEnabled': intensityEnabled,
      'failureWeekCadence': failureWeekCadence,
      'warmupEnabled': warmupEnabled,
      'stretchingEnabled': stretchingEnabled,
      'cardioEnabled': cardioEnabled,
    };
  }

  UserProfile copyWith({
    double? weight,
    double? height,
    double? bodyFat,
    DateTime? birthDate,
    int? trainingExperienceMonths,
    int? trainingDaysPerWeek,
    TrainingGoal? goal,
    bool? completedOnboarding,
    bool? intensityEnabled,
    int? failureWeekCadence,
    bool? warmupEnabled,
    bool? stretchingEnabled,
    bool? cardioEnabled,
  }) {
    return UserProfile(
      uid: uid,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      bodyFat: bodyFat ?? this.bodyFat,
      birthDate: birthDate ?? this.birthDate,
      trainingExperienceMonths:
          trainingExperienceMonths ?? this.trainingExperienceMonths,
      trainingDaysPerWeek: trainingDaysPerWeek ?? this.trainingDaysPerWeek,
      goal: goal ?? this.goal,
      completedOnboarding: completedOnboarding ?? this.completedOnboarding,
      intensityEnabled: intensityEnabled ?? this.intensityEnabled,
      failureWeekCadence: failureWeekCadence ?? this.failureWeekCadence,
      warmupEnabled: warmupEnabled ?? this.warmupEnabled,
      stretchingEnabled: stretchingEnabled ?? this.stretchingEnabled,
      cardioEnabled: cardioEnabled ?? this.cardioEnabled,
    );
  }
}
