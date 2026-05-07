import '../../core/firebase/firestore_instance.dart';
import '../models/routine_template.dart';

class RoutineTemplateService {
  Future<List<RoutineTemplate>> getByCategory(String category) async {
    final snap = await db
        .collection('routine_templates')
        .where('category', isEqualTo: category)
        .get();
    final list = snap.docs
        .map((d) => RoutineTemplate.fromMap(d.id, d.data()))
        .toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }
}
