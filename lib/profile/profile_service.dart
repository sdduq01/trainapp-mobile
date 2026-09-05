import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase/firestore_instance.dart';
import 'models/user_profile.dart';

class ProfileService {

  Future<UserProfile?> getProfile(String uid) async {
    final doc = await db.collection('profiles').doc(uid).get();

    if (!doc.exists) return null;

    return UserProfile.fromMap(uid, doc.data()!);
  }

  Future<void> saveProfile(UserProfile profile) async {
    await db
        .collection('profiles')
        .doc(profile.uid)
        .set(profile.toMap(), SetOptions(merge: true));
  }

  /// Marca el macro ciclo "Forjado por el Hierro" como completado, lo que
  /// desbloquea la pestaña Top Secret.
  Future<void> markForjadoHierroCompleted(String uid) async {
    await db
        .collection('profiles')
        .doc(uid)
        .set({'forjadoHierroCompletado': true}, SetOptions(merge: true));
  }
}
