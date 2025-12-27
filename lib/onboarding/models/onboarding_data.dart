class OnboardingData {
  final double? weight;
  final double? height;
  final double? bodyFat;

  final String? goal;
  final int? trainingExperienceMonths;

  OnboardingData({
    this.weight,
    this.height,
    this.bodyFat,
    this.goal,
    this.trainingExperienceMonths,
  });

  OnboardingData copyWith({
    double? weight,
    double? height,
    double? bodyFat,
    String? goal,
    int? trainingExperienceMonths,
  }) {
    return OnboardingData(
      weight: weight ?? this.weight,
      height: height ?? this.height,
      bodyFat: bodyFat ?? this.bodyFat,
      goal: goal ?? this.goal,
      trainingExperienceMonths:
          trainingExperienceMonths ?? this.trainingExperienceMonths,
    );
  }

  @override
  String toString() {
    return '''
Weight: $weight
Height: $height
BodyFat: $bodyFat
Goal: $goal
Experience: $trainingExperienceMonths months
''';
  }
}