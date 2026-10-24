import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/firebase/firestore_instance.dart';
import '../models/gym.dart';
import '../models/gym_request.dart';
import 'gym_service.dart';

class GymRequestService {
  CollectionReference<Map<String, dynamic>> get _col =>
      db.collection('gym_requests');

  /// La solicitud de [uid], si envió una.
  Future<GymRequest?> getMyRequest(String uid) async {
    final doc = await _col.doc(uid).get();
    if (!doc.exists) return null;
    return GymRequest.fromMap(uid, doc.data()!);
  }

  /// Crea la solicitud, o la reenvía corregida si estaba rechazada.
  Future<void> submit(GymRequest request) async {
    await _col.doc(request.uid).set(request.toMap());
  }

  /// Solicitudes pendientes (solo admin), las más antiguas primero.
  Future<List<GymRequest>> getPending() async {
    final query = await _col
        .where('status', isEqualTo: GymRequestStatus.pending.name)
        .get();
    final requests =
        query.docs.map((d) => GymRequest.fromMap(d.id, d.data())).toList();
    requests.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return requests;
  }

  /// Crea el gimnasio y marca la solicitud como aprobada, en una sola
  /// escritura atómica (solo admin). Lanza [Exception] si el solicitante ya
  /// administra un gimnasio.
  Future<void> approve(GymRequest request) async {
    final existing = await GymService().getOwnedGym(request.uid);
    if (existing != null) {
      throw Exception(
        '${request.email} ya administra el gimnasio "${existing.name}".',
      );
    }

    final gymRef = db.collection('gyms').doc();
    final batch = db.batch();
    batch.set(gymRef, {
      'name': request.gymName,
      'ownerUid': request.uid,
      'logoUrl': null,
      'city': request.city,
      'address': request.address,
      'phone': request.phone,
      'cancelWindowHours': Gym.kDefaultCancelWindowHours,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_col.doc(request.uid), {
      'status': GymRequestStatus.approved.name,
      'gymId': gymRef.id,
      'rejectionReason': null,
      'reviewedAt': DateTime.now().toIso8601String(),
    });
    await batch.commit();
  }

  /// Rechaza la solicitud con un motivo que el solicitante verá (solo admin).
  Future<void> reject(GymRequest request, String reason) async {
    await _col.doc(request.uid).update({
      'status': GymRequestStatus.rejected.name,
      'rejectionReason': reason.trim(),
      'reviewedAt': DateTime.now().toIso8601String(),
    });
  }
}
