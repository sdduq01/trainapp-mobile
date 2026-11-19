import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firebase/firestore_instance.dart';
import 'premium_service.dart';

enum TrialStatus { available, pending, active, expired, rejected }

/// Estado de la prueba gratis del usuario (`trial_requests/{uid}`).
class Trial {
  final TrialStatus status;
  final DateTime? endsAt;

  const Trial(this.status, {this.endsAt});

  static const available = Trial(TrialStatus.available);

  factory Trial.fromMap(Map<String, dynamic>? m) {
    if (m == null) return available;
    final endsAt = (m['endsAt'] as Timestamp?)?.toDate();
    final status = switch (m['status']) {
      'active' => endsAt != null && endsAt.isAfter(DateTime.now())
          ? TrialStatus.active
          : TrialStatus.expired,
      'expired' => TrialStatus.expired,
      'rejected' => TrialStatus.rejected,
      _ => TrialStatus.pending,
    };
    return Trial(status, endsAt: endsAt);
  }

  /// Días que le quedan (redondeado hacia arriba), si está activa.
  int? get daysLeft {
    final e = endsAt;
    if (status != TrialStatus.active || e == null) return null;
    final h = e.difference(DateTime.now()).inHours;
    return (h / 24).ceil().clamp(1, 7);
  }
}

/// Prueba gratis de premium: 7 días, una sola vez por persona. La activa la
/// Cloud Function `startTrial` (ver `functions/premium.js`).
class TrialService {
  static const int days = 7;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      db.collection('trial_requests').doc(uid);

  Future<Trial> get(String uid) async {
    final snap = await _doc(uid).get();
    return Trial.fromMap(snap.data());
  }

  /// Pide la prueba y espera a que el servidor la procese (y a que llegue el
  /// premium). Devuelve el estado final, o `pending` si tarda demasiado.
  Future<Trial> start(String uid,
      {Duration timeout = const Duration(seconds: 20)}) async {
    await _doc(uid).set({'requestedAt': FieldValue.serverTimestamp()});
    final completer = Completer<Trial>();
    late final StreamSubscription<dynamic> sub;
    sub = _doc(uid).snapshots().listen((snap) async {
      final trial = Trial.fromMap(snap.data());
      if (trial.status == TrialStatus.pending || completer.isCompleted) return;
      if (trial.status == TrialStatus.active) {
        // Espera a que entitlements refleje la prueba.
        for (var i = 0; i < 10; i++) {
          if (await PremiumService.instance.fetch(uid)) break;
          await Future<void>.delayed(const Duration(milliseconds: 700));
        }
      }
      if (!completer.isCompleted) completer.complete(trial);
    }, onError: (_) {});
    try {
      return await completer.future
          .timeout(timeout, onTimeout: () => const Trial(TrialStatus.pending));
    } finally {
      await sub.cancel();
    }
  }
}
