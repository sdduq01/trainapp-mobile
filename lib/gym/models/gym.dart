/// Gimnasio (`gyms/{gymId}`). Lo crea un admin al aprobar una solicitud del
/// portal (o el script `create_gym.js`); el dueño edita nombre, logo, datos de
/// contacto y la ventana de cancelación de clases.
class Gym {
  static const int kDefaultCancelWindowHours = 2;

  final String id;
  final String name;
  final String ownerUid;
  final String? logoUrl;
  final String city;
  final String address;
  final String phone;

  /// Horas antes de una clase hasta las que un atleta puede cancelar.
  final int cancelWindowHours;

  /// `active` o `suspended`. Solo lo cambia un admin (más adelante, el cobro).
  final String status;

  const Gym({
    required this.id,
    required this.name,
    required this.ownerUid,
    this.logoUrl,
    this.city = '',
    this.address = '',
    this.phone = '',
    this.cancelWindowHours = kDefaultCancelWindowHours,
    this.status = 'active',
  });

  factory Gym.fromMap(String id, Map<String, dynamic> m) => Gym(
        id: id,
        name: m['name'] as String? ?? '',
        ownerUid: m['ownerUid'] as String,
        logoUrl: m['logoUrl'] as String?,
        city: m['city'] as String? ?? '',
        address: m['address'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        cancelWindowHours: (m['cancelWindowHours'] as num?)?.toInt() ??
            kDefaultCancelWindowHours,
        status: m['status'] as String? ?? 'active',
      );

  Gym copyWith({
    String? name,
    String? logoUrl,
    String? city,
    String? address,
    String? phone,
    int? cancelWindowHours,
  }) =>
      Gym(
        id: id,
        name: name ?? this.name,
        ownerUid: ownerUid,
        logoUrl: logoUrl ?? this.logoUrl,
        city: city ?? this.city,
        address: address ?? this.address,
        phone: phone ?? this.phone,
        cancelWindowHours: cancelWindowHours ?? this.cancelWindowHours,
        status: status,
      );
}
