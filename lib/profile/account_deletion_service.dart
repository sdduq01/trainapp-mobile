import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/firebase/delete_collection.dart';
import '../core/firebase/firestore_instance.dart';
import '../trainer/services/user_directory_service.dart';

/// Elimina la cuenta del usuario actual y todos sus datos, de forma
/// irreversible.
///
/// Se borra:
/// - Historial, PRs, progresiones y apuntes (`sessions`, `exercise_prs`,
///   `progressions`, `exercise_notes`)
/// - "Mis ejercicios" y "Mis rutinas" (`custom_exercises`, `custom_routines`)
/// - Rutina activa y macro ciclo (`routines`, `macrocycles`)
/// - Vínculos de entrenador, como atleta y como entrenador (`trainer_links`)
/// - Pertenencia a un gimnasio (`gym_members`)
/// - Entrada del directorio por email (`user_directory`) y perfil (`profiles`)
/// - Los drafts de sesión guardados en el dispositivo
/// - La cuenta de Firebase Authentication
///
/// Las sesiones que registró como entrenador en el historial de un atleta
/// son del atleta y no se tocan.
class AccountDeletionService {
  /// Lanza [FirebaseAuthException] si [password] no es correcta; en ese caso
  /// no se borra nada.
  Future<void> deleteAccount({required String password}) async {
    final user = FirebaseAuth.instance.currentUser!;
    final uid = user.uid;
    final email = user.email;

    // Se reautentica antes de tocar nada: `user.delete()` exige un login
    // reciente y no debe fallar con los datos ya borrados.
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email!, password: password),
    );

    await Future.wait([
      deleteCollection(db.collection('sessions').doc(uid).collection('logs')),
      deleteCollection(
          db.collection('exercise_prs').doc(uid).collection('items')),
      deleteCollection(
          db.collection('progressions').doc(uid).collection('logs')),
      deleteCollection(
          db.collection('exercise_notes').doc(uid).collection('items')),
      deleteCollection(
          db.collection('custom_exercises').doc(uid).collection('items')),
      deleteCollection(
          db.collection('custom_routines').doc(uid).collection('items')),
      db.collection('routines').doc(uid).delete(),
      db.collection('macrocycles').doc(uid).delete(),
      _deleteTrainerLinks(uid),
      db.collection('gym_members').doc(uid).delete(),
      UserDirectoryService().deleteDirectoryEntry(uid, email),
    ]);
    // El perfil va de último: si algo de lo anterior falla, la cuenta sigue
    // usable y se puede reintentar.
    await db.collection('profiles').doc(uid).delete();
    await _clearLocalDrafts();

    await user.delete();
  }

  Future<void> _deleteTrainerLinks(String uid) async {
    final links = db.collection('trainer_links');
    final asTrainer = await links.where('trainerUid', isEqualTo: uid).get();
    await Future.wait([
      links.doc(uid).delete(),
      for (final doc in asTrainer.docs) doc.reference.delete(),
    ]);
  }

  Future<void> _clearLocalDrafts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys =
          prefs.getKeys().where((k) => k.startsWith('session_draft')).toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }
}
