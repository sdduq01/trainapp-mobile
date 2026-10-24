import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../core/firebase/firestore_instance.dart';

/// Directorio liviano email -> uid. El id de cada doc es el SHA-256 del
/// email normalizado y el doc solo guarda el uid, así que para resolver una
/// cuenta hay que conocer el email exacto: las reglas permiten `get` pero no
/// `list`, y nadie puede enumerar los correos registrados.
class UserDirectoryService {
  static String _normalize(String email) => email.trim().toLowerCase();

  static String _docId(String email) =>
      sha256.convert(utf8.encode(_normalize(email))).toString();

  /// Crea o actualiza la entrada del directorio para [uid]. Idempotente,
  /// pensado para llamarse tanto al registrarse como (como backfill) cada
  /// vez que una cuenta existente abre la app.
  Future<void> ensureDirectoryEntry(String uid, String? email) async {
    if (email == null || email.trim().isEmpty) return;
    await db.collection('user_directory').doc(_docId(email)).set({
      'uid': uid,
    });
  }

  /// Busca el uid registrado para [email], o null si no existe.
  Future<String?> findUidByEmail(String email) async {
    final doc =
        await db.collection('user_directory').doc(_docId(email)).get();
    return doc.data()?['uid'] as String?;
  }

  /// Borra la entrada de [uid]/[email], y la del formato anterior (doc id =
  /// uid) si todavía existe.
  Future<void> deleteDirectoryEntry(String uid, String? email) async {
    final col = db.collection('user_directory');
    await Future.wait([
      if (email != null && email.trim().isNotEmpty)
        col.doc(_docId(email)).delete(),
      col.doc(uid).delete(),
    ]);
  }
}
