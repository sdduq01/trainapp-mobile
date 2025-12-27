class UserProfile {
  final String uid;
  final double? weight;
  final double? height;
  final double? bodyFat;
  final int? trainingExperienceMonths;
  final bool completedOnboarding;

  UserProfile({
    required this.uid,
    this.weight,
    this.height,
    this.bodyFat,
    this.trainingExperienceMonths,
    required this.completedOnboarding,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      weight: (data['weight'] as num?)?.toDouble(),
      height: (data['height'] as num?)?.toDouble(),
      bodyFat: (data['bodyFat'] as num?)?.toDouble(),
      trainingExperienceMonths: data['trainingExperienceMonths'],
      completedOnboarding: data['completedOnboarding'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'weight': weight,
      'height': height,
      'bodyFat': bodyFat,
      'trainingExperienceMonths': trainingExperienceMonths,
      'completedOnboarding': completedOnboarding,
    };
  }
}
