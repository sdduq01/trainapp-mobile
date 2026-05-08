import '../../core/firebase/firestore_instance.dart';

/// PR (peso de referencia) por ejercicio para un usuario.
/// Se persiste fuera de la rutina activa para que sobreviva a cambios de rutina.
class ExercisePr {
  final double weight;
  final String unit;
  ExercisePr({required this.weight, required this.unit});
}

class ExercisePrService {
  static const _root = 'exercise_prs';
  static const _items = 'items';

  Future<Map<String, ExercisePr>> getAll(String userId) async {
    final snap = await db.collection(_root).doc(userId).collection(_items).get();
    final result = <String, ExercisePr>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final weight = (data['weight'] as num?)?.toDouble();
      final unit = data['unit'] as String?;
      if (weight == null || weight <= 0 || unit == null) continue;
      result[doc.id] = ExercisePr(weight: weight, unit: unit);
    }
    return result;
  }

  Future<void> upsert(
    String userId,
    String exerciseId,
    double weight,
    String unit,
  ) async {
    if (weight <= 0) return;
    await db.collection(_root).doc(userId).collection(_items).doc(exerciseId).set({
      'weight': weight,
      'unit': unit,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> upsertMany(
    String userId,
    Map<String, ExercisePr> prs,
  ) async {
    if (prs.isEmpty) return;
    final batch = db.batch();
    final col = db.collection(_root).doc(userId).collection(_items);
    final now = DateTime.now().toIso8601String();
    prs.forEach((exerciseId, pr) {
      if (pr.weight <= 0) return;
      batch.set(col.doc(exerciseId), {
        'weight': pr.weight,
        'unit': pr.unit,
        'updatedAt': now,
      });
    });
    await batch.commit();
  }
}
