enum GymRequestStatus { pending, approved, rejected }

/// Solicitud de alta de un gimnasio desde el portal web
/// (`gym_requests/{uid}`, un doc por usuario). La aprueba o rechaza un admin;
/// si la rechaza, el usuario puede corregirla y reenviarla.
class GymRequest {
  final String uid;
  final String gymName;
  final String city;
  final String address;
  final String phone;
  final String contactName;
  final String email;
  final GymRequestStatus status;
  final String? gymId;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  const GymRequest({
    required this.uid,
    required this.gymName,
    required this.city,
    required this.address,
    required this.phone,
    required this.contactName,
    required this.email,
    required this.status,
    required this.createdAt,
    this.gymId,
    this.rejectionReason,
    this.reviewedAt,
  });

  Map<String, dynamic> toMap() => {
        'gymName': gymName,
        'city': city,
        'address': address,
        'phone': phone,
        'contactName': contactName,
        'email': email,
        'status': status.name,
        'gymId': gymId,
        'rejectionReason': rejectionReason,
        'createdAt': createdAt.toIso8601String(),
        'reviewedAt': reviewedAt?.toIso8601String(),
      };

  factory GymRequest.fromMap(String uid, Map<String, dynamic> m) => GymRequest(
        uid: uid,
        gymName: m['gymName'] as String? ?? '',
        city: m['city'] as String? ?? '',
        address: m['address'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        contactName: m['contactName'] as String? ?? '',
        email: m['email'] as String? ?? '',
        status: GymRequestStatus.values.firstWhere(
          (s) => s.name == m['status'],
          orElse: () => GymRequestStatus.pending,
        ),
        gymId: m['gymId'] as String?,
        rejectionReason: m['rejectionReason'] as String?,
        createdAt: DateTime.parse(m['createdAt'] as String),
        reviewedAt: m['reviewedAt'] != null
            ? DateTime.parse(m['reviewedAt'] as String)
            : null,
      );
}
