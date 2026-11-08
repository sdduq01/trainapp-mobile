import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/firebase/firestore_instance.dart';
import '../models/gym_class.dart';
import '../models/gym_schedule.dart';

/// Clases grupales: horarios y clases (staff, desde el portal) e
/// inscripciones (atletas, desde la app). Cupo, ventana de cancelación y
/// permisos los hacen cumplir las reglas de Firestore.
class GymClassService {
  /// Días de clases que ve el atleta (la función genera lo mismo).
  static const daysAhead = 14;

  DocumentReference<Map<String, dynamic>> _gym(String gymId) =>
      db.collection('gyms').doc(gymId);

  CollectionReference<Map<String, dynamic>> _classes(String gymId) =>
      _gym(gymId).collection('classes');

  CollectionReference<Map<String, dynamic>> _schedules(String gymId) =>
      _gym(gymId).collection('schedules');

  DocumentReference<Map<String, dynamic>> _enrollment(
          String gymId, String classId, String uid) =>
      _classes(gymId).doc(classId).collection('enrollments').doc(uid);

  // ── Horarios (staff) ───────────────────────────────────────────────────

  Stream<List<GymSchedule>> watchSchedules(String gymId) =>
      _schedules(gymId).snapshots().map((q) {
        final list =
            q.docs.map((d) => GymSchedule.fromMap(d.id, d.data())).toList();
        list.sort((a, b) {
          final byTime = a.startTime.compareTo(b.startTime);
          return byTime != 0 ? byTime : a.name.compareTo(b.name);
        });
        return list;
      });

  /// Crea ([schedule].id vacío) o reemplaza un horario.
  Future<void> saveSchedule(String gymId, GymSchedule schedule) async {
    if (schedule.id.isEmpty) {
      await _schedules(gymId).add(schedule.toMap());
    } else {
      await _schedules(gymId).doc(schedule.id).set(schedule.toMap());
    }
  }

  Future<void> deleteSchedule(String gymId, String scheduleId) =>
      _schedules(gymId).doc(scheduleId).delete();

  // ── Clases ─────────────────────────────────────────────────────────────

  /// Clases que empiezan desde [from] (por defecto, desde hace una hora,
  /// para seguir viendo la que está en curso) durante [days] días.
  Stream<List<GymClass>> watchClasses(String gymId,
      {DateTime? from, int days = daysAhead + 1}) {
    final start =
        from ?? DateTime.now().toUtc().subtract(const Duration(hours: 1));
    final end = start.add(Duration(days: days));
    return _classes(gymId)
        .where('startsAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startsAt', isLessThan: Timestamp.fromDate(end))
        .orderBy('startsAt')
        .snapshots()
        .map((q) => q.docs
            .map((d) => GymClass.fromMap(gymId, d.id, d.data()))
            .toList());
  }

  /// Clase suelta (no viene de un horario).
  Future<void> createClass(GymClass gymClass) =>
      _classes(gymClass.gymId).add(gymClass.toMap());

  /// Guarda los cambios del staff. La clase queda marcada como editada para
  /// que los cambios del horario no la sobrescriban. No toca el conteo de
  /// inscritos (lo maneja cada inscripción).
  Future<void> updateClass(GymClass gymClass) {
    final data = gymClass.copyWith(edited: true).toMap()
      ..remove('enrolledCount');
    return _classes(gymClass.gymId).doc(gymClass.id).update(data);
  }

  Future<void> setCancelled(GymClass gymClass, bool cancelled) =>
      _classes(gymClass.gymId).doc(gymClass.id).update({
        'status':
            cancelled ? GymClass.statusCancelled : GymClass.statusScheduled,
        'edited': true,
      });

  /// Solo si no tiene inscritos (si los tiene, se cancela).
  Future<void> deleteClass(GymClass gymClass) =>
      _classes(gymClass.gymId).doc(gymClass.id).delete();

  // ── Inscripciones ──────────────────────────────────────────────────────

  /// Lista de inscritos de una clase (staff).
  Stream<List<GymEnrollment>> watchEnrollments(String gymId, String classId) =>
      _classes(gymId).doc(classId).collection('enrollments').snapshots().map(
          (q) => q.docs.map((d) => GymEnrollment.fromMap(d.data())).toList()
            ..sort((a, b) => a.email.compareTo(b.email)));

  /// El staff retira a un atleta de una clase y libera su cupo.
  Future<void> removeEnrollment(GymClass gymClass, String uid) async {
    final batch = db.batch()
      ..delete(_enrollment(gymClass.gymId, gymClass.id, uid))
      ..update(_classes(gymClass.gymId).doc(gymClass.id),
          {'enrolledCount': FieldValue.increment(-1)});
    await batch.commit();
  }

  /// Inscripciones futuras del usuario actual (en cualquier gimnasio), por
  /// id de clase.
  Stream<Set<String>> watchMyEnrolledClassIds(String uid) {
    final since = DateTime.now().toUtc().subtract(const Duration(days: 1));
    return db
        .collectionGroup('enrollments')
        .where('uid', isEqualTo: uid)
        .where('startsAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .snapshots()
        .map((q) => {for (final d in q.docs) d.data()['classId'] as String});
  }

  /// Inscribe al usuario actual. El incremento atómico más las reglas
  /// garantizan que nunca se pase del cupo, aunque se inscriban varios a la
  /// vez. Lanza [Exception] con un mensaje amigable.
  Future<void> enroll(GymClass gymClass) async {
    final user = FirebaseAuth.instance.currentUser!;
    final batch = db.batch()
      ..set(_enrollment(gymClass.gymId, gymClass.id, user.uid), {
        'uid': user.uid,
        'gymId': gymClass.gymId,
        'classId': gymClass.id,
        'startsAt': Timestamp.fromDate(gymClass.startsAt),
        'email': user.email,
        'enrolledAt': FieldValue.serverTimestamp(),
      })
      ..update(_classes(gymClass.gymId).doc(gymClass.id),
          {'enrolledCount': FieldValue.increment(1)});
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception(
            'No se pudo inscribir: la clase se llenó, fue cancelada o ya no '
            'admite inscripciones.');
      }
      rethrow;
    }
  }

  /// Cancela la inscripción del usuario actual (antes de la ventana de
  /// cancelación del gimnasio).
  Future<void> unenroll(GymClass gymClass) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final batch = db.batch()
      ..delete(_enrollment(gymClass.gymId, gymClass.id, uid))
      ..update(_classes(gymClass.gymId).doc(gymClass.id),
          {'enrolledCount': FieldValue.increment(-1)});
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception(
            'Ya no puedes cancelar: pasó el plazo de cancelación de esta clase.');
      }
      rethrow;
    }
  }
}
