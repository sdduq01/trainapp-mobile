enum TrainerLinkStatus { pending, accepted }

extension TrainerLinkStatusX on TrainerLinkStatus {
  String get id => name;

  static TrainerLinkStatus fromId(String? id) {
    return TrainerLinkStatus.values.firstWhere(
      (s) => s.id == id,
      orElse: () => TrainerLinkStatus.pending,
    );
  }
}

/// Relación entrenador-atleta. Un solo doc por atleta
/// (`trainer_links/{athleteUid}`): un atleta solo puede tener un entrenador
/// activo (pending o accepted) a la vez.
class TrainerLink {
  final String athleteUid;
  final String trainerUid;
  final TrainerLinkStatus status;
  final String trainerEmail;
  final String athleteEmail;
  final DateTime createdAt;
  final DateTime? respondedAt;

  const TrainerLink({
    required this.athleteUid,
    required this.trainerUid,
    required this.status,
    required this.trainerEmail,
    required this.athleteEmail,
    required this.createdAt,
    this.respondedAt,
  });

  Map<String, dynamic> toMap() => {
        'athleteUid': athleteUid,
        'trainerUid': trainerUid,
        'status': status.id,
        'trainerEmail': trainerEmail,
        'athleteEmail': athleteEmail,
        'createdAt': createdAt.toIso8601String(),
        'respondedAt': respondedAt?.toIso8601String(),
      };

  factory TrainerLink.fromMap(String athleteUid, Map<String, dynamic> m) =>
      TrainerLink(
        athleteUid: athleteUid,
        trainerUid: m['trainerUid'] as String,
        status: TrainerLinkStatusX.fromId(m['status'] as String?),
        trainerEmail: m['trainerEmail'] as String? ?? '',
        athleteEmail: m['athleteEmail'] as String? ?? '',
        createdAt: DateTime.parse(m['createdAt'] as String),
        respondedAt: m['respondedAt'] != null
            ? DateTime.parse(m['respondedAt'] as String)
            : null,
      );

  TrainerLink copyWith({
    TrainerLinkStatus? status,
    DateTime? respondedAt,
  }) =>
      TrainerLink(
        athleteUid: athleteUid,
        trainerUid: trainerUid,
        status: status ?? this.status,
        trainerEmail: trainerEmail,
        athleteEmail: athleteEmail,
        createdAt: createdAt,
        respondedAt: respondedAt ?? this.respondedAt,
      );
}
