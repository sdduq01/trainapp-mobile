import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/firebase/firestore_instance.dart';
import '../../trainer/services/user_directory_service.dart';
import '../models/gym.dart';
import '../models/gym_member.dart';

class GymService {
  CollectionReference<Map<String, dynamic>> get _gyms => db.collection('gyms');
  CollectionReference<Map<String, dynamic>> get _members =>
      db.collection('gym_members');

  Future<Gym?> getGym(String gymId) async {
    final doc = await _gyms.doc(gymId).get();
    if (!doc.exists) return null;
    return Gym.fromMap(doc.id, doc.data()!);
  }

  /// El gimnasio que administra [ownerUid], si tiene uno.
  Future<Gym?> getOwnedGym(String ownerUid) async {
    final query =
        await _gyms.where('ownerUid', isEqualTo: ownerUid).limit(1).get();
    if (query.docs.isEmpty) return null;
    final doc = query.docs.first;
    return Gym.fromMap(doc.id, doc.data());
  }

  /// La pertenencia (pending o accepted) de [uid] a un gimnasio, si existe.
  Future<GymMember?> getMembership(String uid) async {
    final doc = await _members.doc(uid).get();
    if (!doc.exists) return null;
    return GymMember.fromMap(uid, doc.data()!);
  }

  /// Todos los miembros (e invitaciones) de [gymId]. Lo pueden leer el dueño
  /// y los entrenadores aceptados del gimnasio.
  Future<List<GymMember>> getMembers(String gymId) async {
    final query = await _members.where('gymId', isEqualTo: gymId).get();
    final members =
        query.docs.map((d) => GymMember.fromMap(d.id, d.data())).toList();
    members.sort((a, b) => a.email.compareTo(b.email));
    return members;
  }

  /// Atletas aceptados de [gymId], para la vista del entrenador de planta.
  Future<List<GymMember>> getAcceptedAthletes(String gymId) async {
    final members = await getMembers(gymId);
    return members
        .where((m) => m.isAccepted && m.role == GymRole.athlete)
        .toList();
  }

  /// El dueño invita al usuario con email [emailInput] como [role]. Lanza
  /// [Exception] con un mensaje amigable si el email no está registrado o si
  /// la persona ya pertenece (o está invitada) a un gimnasio.
  Future<void> invite({
    required Gym gym,
    required String emailInput,
    required GymRole role,
  }) async {
    final uid = await UserDirectoryService().findUidByEmail(emailInput);
    if (uid == null) {
      throw Exception('No existe ninguna cuenta registrada con ese email.');
    }

    final member = GymMember(
      uid: uid,
      gymId: gym.id,
      gymName: gym.name,
      role: role,
      status: GymMemberStatus.pending,
      email: emailInput.trim().toLowerCase(),
      invitedAt: DateTime.now(),
    );

    try {
      await _members.doc(uid).set(member.toMap());
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception(
          'Esa persona ya pertenece a un gimnasio o tiene una invitación pendiente.',
        );
      }
      rethrow;
    }
  }

  /// El usuario acepta la invitación pendiente.
  Future<void> acceptInvitation(String uid) async {
    await _members.doc(uid).update({
      'status': GymMemberStatus.accepted.name,
      'respondedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Rechaza o sale (el propio usuario) o retira/cancela (el dueño).
  Future<void> deleteMembership(String uid) async {
    await _members.doc(uid).delete();
  }

  Future<void> renameGym(String gymId, String name) async {
    await _gyms.doc(gymId).update({'name': name.trim()});
  }

  /// Guarda los datos editables del gimnasio (portal, "Perfil del gimnasio").
  Future<void> updateProfile(Gym gym) async {
    await _gyms.doc(gym.id).update({
      'name': gym.name.trim(),
      'city': gym.city.trim(),
      'address': gym.address.trim(),
      'phone': gym.phone.trim(),
      'cancelWindowHours': gym.cancelWindowHours,
    });
  }

  /// Abre la galería (o el selector de archivos en la web) y sube la imagen
  /// elegida como logo de [gym]. Devuelve la URL nueva, o null si el usuario
  /// no eligió nada.
  Future<String?> pickAndUploadLogo(Gym gym) async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (image == null) return null;
    return uploadLogo(gym, image);
  }

  /// Sube [image] como nuevo logo de [gym] y devuelve su URL. Cada logo va
  /// con un nombre nuevo para que la caché de imágenes de los teléfonos no
  /// siga mostrando el anterior; el anterior se borra.
  Future<String> uploadLogo(Gym gym, XFile image) async {
    final bytes = await image.readAsBytes();
    final mime = image.mimeType ??
        (image.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
    final ref = FirebaseStorage.instance.ref(
      'gym_logos/${gym.ownerUid}/logo_${DateTime.now().millisecondsSinceEpoch}',
    );
    await ref.putData(bytes, SettableMetadata(contentType: mime));
    final url = await ref.getDownloadURL();

    await _gyms.doc(gym.id).update({'logoUrl': url});

    if (gym.logoUrl != null) {
      try {
        await FirebaseStorage.instance.refFromURL(gym.logoUrl!).delete();
      } catch (_) {
        // silencioso: un logo viejo huérfano no afecta a nadie
      }
    }
    return url;
  }
}
