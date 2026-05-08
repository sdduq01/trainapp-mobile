import '../../core/firebase/firestore_instance.dart';

/// Apuntes personales del usuario para un ejercicio (ajustes de máquina, cues
/// técnicos, recordatorios). Persistidos por exerciseId, así que sobreviven al
/// cambio de rutina (el ejercicio sigue siendo el mismo).
class ExerciseNotesService {
  static const _root = 'exercise_notes';
  static const _items = 'items';

  Future<Map<String, String>> getForExercises(
    String userId,
    List<String> exerciseIds,
  ) async {
    final result = <String, String>{};
    if (exerciseIds.isEmpty) return result;

    // Lee documentos individuales en paralelo. Más simple y predecible que
    // whereIn, que limita a 30 ids por consulta.
    final col = db.collection(_root).doc(userId).collection(_items);
    final snapshots = await Future.wait(exerciseIds.map((id) => col.doc(id).get()));
    for (final snap in snapshots) {
      if (!snap.exists) continue;
      final note = (snap.data()?['note'] as String?)?.trim();
      if (note == null || note.isEmpty) continue;
      result[snap.id] = note;
    }
    return result;
  }

  Future<void> upsert(String userId, String exerciseId, String note) async {
    final trimmed = note.trim();
    final ref = db.collection(_root).doc(userId).collection(_items).doc(exerciseId);
    if (trimmed.isEmpty) {
      await ref.delete();
      return;
    }
    await ref.set({
      'note': trimmed,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }
}
