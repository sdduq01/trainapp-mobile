import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase/firestore_instance.dart';
import '../models/trainer_link.dart';
import 'user_directory_service.dart';

class TrainerLinkService {
  CollectionReference<Map<String, dynamic>> get _col =>
      db.collection('trainer_links');

  /// La relación (pending o accepted) del atleta [athleteUid], si existe.
  Future<TrainerLink?> getLinkForAthlete(String athleteUid) async {
    final doc = await _col.doc(athleteUid).get();
    if (!doc.exists) return null;
    return TrainerLink.fromMap(athleteUid, doc.data()!);
  }

  /// Atletas aceptados y solicitudes pendientes enviadas por [trainerUid],
  /// en una sola lectura (query de un solo campo, sin índice compuesto).
  Future<({List<TrainerLink> accepted, List<TrainerLink> pending})>
      getMyLinks(String trainerUid) async {
    final query =
        await _col.where('trainerUid', isEqualTo: trainerUid).get();
    final links = query.docs
        .map((d) => TrainerLink.fromMap(d.id, d.data()))
        .toList();
    return (
      accepted: links.where((l) => l.status == TrainerLinkStatus.accepted).toList(),
      pending: links.where((l) => l.status == TrainerLinkStatus.pending).toList(),
    );
  }

  /// Envía una solicitud del entrenador [trainerUid]/[trainerEmail] al
  /// atleta cuyo email es [athleteEmailInput]. Lanza [Exception] con un
  /// mensaje amigable si el email no está registrado, si es una
  /// auto-solicitud, o si el atleta ya tiene un entrenador activo/pendiente
  /// (permission-denied de la regla de `create`).
  Future<void> sendRequest({
    required String trainerUid,
    required String trainerEmail,
    required String athleteEmailInput,
  }) async {
    final athleteUid =
        await UserDirectoryService().findUidByEmail(athleteEmailInput);
    if (athleteUid == null) {
      throw Exception('No existe ninguna cuenta registrada con ese email.');
    }
    if (athleteUid == trainerUid) {
      throw Exception('No podés enviarte una solicitud a vos mismo.');
    }

    final link = TrainerLink(
      athleteUid: athleteUid,
      trainerUid: trainerUid,
      status: TrainerLinkStatus.pending,
      trainerEmail: trainerEmail,
      athleteEmail: athleteEmailInput.trim().toLowerCase(),
      createdAt: DateTime.now(),
    );

    try {
      await _col.doc(athleteUid).set(link.toMap());
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception(
          'Ese atleta ya tiene un entrenador activo o una solicitud pendiente.',
        );
      }
      rethrow;
    }
  }

  /// El atleta acepta la solicitud pendiente.
  Future<void> acceptRequest(String athleteUid) async {
    await _col.doc(athleteUid).update({
      'status': TrainerLinkStatus.accepted.id,
      'respondedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Rechaza (atleta, pending), revoca (atleta, accepted) o cancela
  /// (entrenador) la relación. Mismo método para los tres casos.
  Future<void> deleteLink(String athleteUid) async {
    await _col.doc(athleteUid).delete();
  }
}
