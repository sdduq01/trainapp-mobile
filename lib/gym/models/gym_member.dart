enum GymRole { trainer, athlete }

enum GymMemberStatus { pending, accepted }

/// Pertenencia de un usuario a un gimnasio. Un solo doc por usuario
/// (`gym_members/{uid}`): cada persona pertenece a un gimnasio a la vez. El
/// dueño invita (pending) y el usuario acepta; salir, rechazar o retirar a
/// alguien es siempre un delete.
class GymMember {
  final String uid;
  final String gymId;
  final String gymName;
  final GymRole role;
  final GymMemberStatus status;
  final String email;
  final DateTime invitedAt;
  final DateTime? respondedAt;

  const GymMember({
    required this.uid,
    required this.gymId,
    required this.gymName,
    required this.role,
    required this.status,
    required this.email,
    required this.invitedAt,
    this.respondedAt,
  });

  bool get isAccepted => status == GymMemberStatus.accepted;
  bool get isTrainer => role == GymRole.trainer;

  String get roleLabel => isTrainer ? 'entrenador' : 'atleta';

  Map<String, dynamic> toMap() => {
        'gymId': gymId,
        'gymName': gymName,
        'role': role.name,
        'status': status.name,
        'email': email,
        'invitedAt': invitedAt.toIso8601String(),
        'respondedAt': respondedAt?.toIso8601String(),
      };

  factory GymMember.fromMap(String uid, Map<String, dynamic> m) => GymMember(
        uid: uid,
        gymId: m['gymId'] as String,
        gymName: m['gymName'] as String? ?? '',
        role: m['role'] == GymRole.trainer.name
            ? GymRole.trainer
            : GymRole.athlete,
        status: m['status'] == GymMemberStatus.accepted.name
            ? GymMemberStatus.accepted
            : GymMemberStatus.pending,
        email: m['email'] as String? ?? '',
        invitedAt: DateTime.parse(m['invitedAt'] as String),
        respondedAt: m['respondedAt'] != null
            ? DateTime.parse(m['respondedAt'] as String)
            : null,
      );
}
