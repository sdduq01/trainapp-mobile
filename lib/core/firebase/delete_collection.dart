import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_instance.dart';

/// Borra todos los documentos de [col].
Future<void> deleteCollection(
    CollectionReference<Map<String, dynamic>> col) async {
  // Firestore limita los batch a 500 operaciones — se pagina por si acaso.
  const pageSize = 300;
  while (true) {
    final snap = await col.limit(pageSize).get();
    if (snap.docs.isEmpty) return;
    final batch = db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    if (snap.docs.length < pageSize) return;
  }
}
