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
  final String? websiteUrl;

  /// Horas antes de una clase hasta las que un atleta puede cancelar.
  final int cancelWindowHours;

  /// `active` o `suspended`. Solo lo cambia un admin (más adelante, el cobro).
  final String status;

  /// Exento de cobro (gimnasios aliados, pruebas gratuitas). Solo lo cambia
  /// un admin: sus atletas tienen premium sin generar facturas.
  final bool billingExempt;

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
    this.websiteUrl,
    this.billingExempt = false,
  });

  /// Máximo de caracteres de la página web (igual que en firestore.rules).
  static const int kMaxWebsiteLength = 300;

  /// Normaliza la página web que escribe el dueño: vacío → '' (sin página);
  /// sin esquema se le antepone https://. Devuelve null si no es una URL
  /// http(s) válida.
  static String? normalizeWebsite(String input) {
    var text = input.trim();
    if (text.isEmpty) return '';
    if (!text.contains('://')) text = 'https://$text';
    final uri = Uri.tryParse(text);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        !uri.host.contains('.') ||
        text.length > kMaxWebsiteLength) {
      return null;
    }
    return text;
  }

  /// Validador de formulario para la página web (opcional).
  static String? validateWebsite(String? v) =>
      normalizeWebsite(v ?? '') == null
          ? 'Escribe una dirección válida, p. ej. https://migimnasio.com'
          : null;

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
        websiteUrl: m['websiteUrl'] as String?,
        billingExempt: m['billingExempt'] as bool? ?? false,
      );

  Gym copyWith({
    String? name,
    String? logoUrl,
    String? city,
    String? address,
    String? phone,
    int? cancelWindowHours,
    String? websiteUrl,
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
        websiteUrl: websiteUrl ?? this.websiteUrl,
        billingExempt: billingExempt,
      );
}
