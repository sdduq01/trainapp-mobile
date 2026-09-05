import '../../core/firebase/firestore_instance.dart';
import '../models/custom_routine.dart';
import '../models/routine.dart';

/// Rutinas personalizadas guardadas del usuario ("Mis rutinas"),
/// en `custom_routines/{uid}/items/{id}`.
class CustomRoutineService {
  Future<List<CustomRoutine>> list(String userId) async {
    final snap = await db
        .collection('custom_routines')
        .doc(userId)
        .collection('items')
        .get();
    return snap.docs
        .map((d) => CustomRoutine.fromMap(d.id, d.data()))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Guarda una rutina en "Mis rutinas". Devuelve el id asignado.
  Future<String> save(
    String userId, {
    required String name,
    required String type,
    required List<RoutineDay> days,
  }) async {
    final ref = db
        .collection('custom_routines')
        .doc(userId)
        .collection('items')
        .doc();
    await ref.set(
      CustomRoutine(
        id: ref.id,
        name: name,
        type: type,
        days: days,
        createdAt: DateTime.now(),
      ).toMap(),
    );
    return ref.id;
  }

  Future<void> delete(String userId, String id) async {
    await db
        .collection('custom_routines')
        .doc(userId)
        .collection('items')
        .doc(id)
        .delete();
  }
}
