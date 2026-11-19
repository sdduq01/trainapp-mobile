import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/firebase/firestore_instance.dart';
import '../models/billing.dart';
import '../models/gym.dart';

/// Lectura de la facturación (dueño del gimnasio y admin) y registro de pagos
/// (solo admin). Las facturas y los periodos los escribe el servidor.
class BillingService {
  DocumentReference<Map<String, dynamic>> _gym(String gymId) =>
      db.collection('gyms').doc(gymId);

  Future<List<BillingAthlete>> getBillingAthletes(String gymId) async {
    final snap = await _gym(gymId).collection('billing_athletes').get();
    return snap.docs
        .map((d) => BillingAthlete.fromMap(d.id, d.data()))
        .toList();
  }

  /// Facturas del gimnasio, de la más reciente a la más antigua.
  Future<List<GymInvoice>> getInvoices(String gymId) async {
    final snap = await _gym(gymId).collection('invoices').get();
    final list =
        snap.docs.map((d) => GymInvoice.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => b.id.compareTo(a.id));
    return list;
  }

  Future<GymInvoice?> getInvoice(String gymId, String monthId) async {
    final doc = await _gym(gymId).collection('invoices').doc(monthId).get();
    if (!doc.exists) return null;
    return GymInvoice.fromMap(doc.id, doc.data()!);
  }

  /// Admin: todos los gimnasios.
  Future<List<Gym>> getAllGyms() async {
    final snap = await db.collection('gyms').get();
    final gyms = snap.docs.map((d) => Gym.fromMap(d.id, d.data())).toList();
    gyms.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return gyms;
  }

  /// Admin: registra (o deshace) el pago de una factura.
  Future<void> setPaid(GymInvoice invoice, {required bool paid, String note = ''}) {
    return _gym(invoice.gymId).collection('invoices').doc(invoice.id).update({
      'status': paid ? 'paid' : 'pending',
      'paidAt': paid ? FieldValue.serverTimestamp() : null,
      'paidNote': paid ? note.trim() : '',
    });
  }

  /// Admin: exime (o deja de eximir) a un gimnasio del cobro: aliados y
  /// pruebas gratuitas. Sus atletas siguen pudiendo tener premium.
  Future<void> setBillingExempt(String gymId, bool exempt) {
    return _gym(gymId).update({'billingExempt': exempt});
  }

  /// Admin: suspende o reactiva un gimnasio. Suspendido, nadie del gimnasio
  /// tiene premium (y no se factura) hasta reactivarlo.
  Future<void> setGymSuspended(String gymId, bool suspended) {
    return _gym(gymId).update({'status': suspended ? 'suspended' : 'active'});
  }
}
