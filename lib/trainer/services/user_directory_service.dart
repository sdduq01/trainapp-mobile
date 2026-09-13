import '../../core/firebase/firestore_instance.dart';

/// Directorio liviano email -> uid. Solo guarda el email (nada de datos
/// personales) para poder resolver "¿a qué uid corresponde este email?"
/// desde el cliente sin exponer el resto del perfil. Ver trade-off de
/// privacidad en el plan del módulo entrenador.
class UserDirectoryService {
  static String _normalize(String email) => email.trim().toLowerCase();

  /// Crea o actualiza la entrada del directorio para [uid]. Idempotente,
  /// pensado para llamarse tanto al registrarse como (como backfill) cada
  /// vez que una cuenta existente abre la app.
  Future<void> ensureDirectoryEntry(String uid, String? email) async {
    if (email == null || email.trim().isEmpty) return;
    await db.collection('user_directory').doc(uid).set({
      'email': _normalize(email),
    });
  }

  /// Busca el uid registrado para [email], o null si no existe.
  Future<String?> findUidByEmail(String email) async {
    final query = await db
        .collection('user_directory')
        .where('email', isEqualTo: _normalize(email))
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return query.docs.first.id;
  }
}
