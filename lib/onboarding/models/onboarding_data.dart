import '../../profile/models/user_profile.dart';

class OnboardingData {
  final double? weight;
  final double? height;
  final double? bodyFat;
  final int? trainingExperienceMonths;
  final TrainingGoal? goal;

  OnboardingData({
    this.weight,
    this.height,
    this.bodyFat,
    this.trainingExperienceMonths,
    this.goal,
  });

  OnboardingData copyWith({
    double? weight,
    double? height,
    double? bodyFat,
    int? trainingExperienceMonths,
    TrainingGoal? goal,
  }) {
    return OnboardingData(
      weight: weight ?? this.weight,
      height: height ?? this.height,
      bodyFat: bodyFat ?? this.bodyFat,
      trainingExperienceMonths:
          trainingExperienceMonths ?? this.trainingExperienceMonths,
      goal: goal ?? this.goal,
    );
  }

  @override
  String toString() {
    return '''
OnboardingData(
  weight: $weight,
  height: $height,
  bodyFat: $bodyFat,
  trainingExperienceMonths: $trainingExperienceMonths,
  goal: $goal
)
''';
  }
}
