/// Gimnasio (`gyms/{gymId}`). Lo crea el script admin `create_gym.js`; desde
/// la app el dueño solo cambia el nombre y el logo.
class Gym {
  final String id;
  final String name;
  final String ownerUid;
  final String? logoUrl;

  const Gym({
    required this.id,
    required this.name,
    required this.ownerUid,
    this.logoUrl,
  });

  factory Gym.fromMap(String id, Map<String, dynamic> m) => Gym(
        id: id,
        name: m['name'] as String? ?? '',
        ownerUid: m['ownerUid'] as String,
        logoUrl: m['logoUrl'] as String?,
      );
}
