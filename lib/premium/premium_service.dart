import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/firebase/firestore_instance.dart';

/// Premium del usuario, leído de `entitlements/{uid}`. Ese doc lo escribe
/// solo una Cloud Function (`functions/premium.js`): el premium lo otorga el
/// gimnasio del usuario (dueño y entrenadores de planta lo tienen siempre;
/// los atletas, cuando el dueño se lo activa).
class PremiumService {
  PremiumService._();
  static final PremiumService instance = PremiumService._();

  /// Premium del usuario con sesión iniciada, actualizado en vivo.
  final ValueNotifier<bool> isPremium = ValueNotifier(false);

  StreamSubscription<dynamic>? _sub;
  String? _uid;

  /// Empieza a escuchar el premium de [uid] (idempotente).
  void start(String uid) {
    if (_uid == uid && _sub != null) return;
    _sub?.cancel();
    _uid = uid;
    _sub = db.collection('entitlements').doc(uid).snapshots().listen(
      (doc) => isPremium.value = doc.data()?['premium'] == true,
      onError: (_) {}, // sin acceso o sin red: se queda con el último valor
    );
  }

  /// Deja de escuchar (al cerrar sesión).
  void stop() {
    _sub?.cancel();
    _sub = null;
    _uid = null;
    isPremium.value = false;
  }

  /// Consulta puntual del premium de [uid]: el propio usuario, o un atleta
  /// para el entrenador que registra su sesión. Ante un error, no premium.
  Future<bool> fetch(String uid) async {
    try {
      final doc = await db.collection('entitlements').doc(uid).get();
      final premium = doc.data()?['premium'] == true;
      if (uid == _uid) isPremium.value = premium;
      return premium;
    } catch (_) {
      return uid == _uid ? isPremium.value : false;
    }
  }
}
