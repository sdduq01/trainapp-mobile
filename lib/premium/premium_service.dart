import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/firebase/firestore_instance.dart';

/// Premium del usuario, leído de `entitlements/{uid}`. Ese doc lo escribe
/// solo una Cloud Function (`functions/premium.js`): el premium lo otorga el
/// gimnasio del usuario (dueño y entrenadores de planta lo tienen siempre;
/// los atletas, cuando el dueño se lo activa) o la prueba gratis de 7 días,
/// que trae `expiresAt`.
class PremiumService {
  PremiumService._();
  static final PremiumService instance = PremiumService._();

  /// Premium del usuario con sesión iniciada, actualizado en vivo.
  final ValueNotifier<bool> isPremium = ValueNotifier(false);

  /// Origen del premium actual ('gym_owner', 'gym_trainer', 'gym_athlete',
  /// 'trial') y su vencimiento (solo la prueba vence).
  String? source;
  DateTime? expiresAt;

  StreamSubscription<dynamic>? _sub;
  Timer? _expiryTimer;
  String? _uid;

  /// ¿El doc de entitlements da premium ahora mismo?
  static bool premiumFrom(Map<String, dynamic>? data, [DateTime? now]) {
    if (data?['premium'] != true) return false;
    final exp = (data!['expiresAt'] as Timestamp?)?.toDate();
    return exp == null || exp.isAfter(now ?? DateTime.now());
  }

  void _apply(Map<String, dynamic>? data) {
    _expiryTimer?.cancel();
    final premium = premiumFrom(data);
    source = premium ? data!['source'] as String? : null;
    expiresAt = premium ? (data!['expiresAt'] as Timestamp?)?.toDate() : null;
    isPremium.value = premium;
    final exp = expiresAt;
    if (exp != null) {
      // La prueba vence aunque el servidor tarde en limpiar el doc.
      _expiryTimer = Timer(exp.difference(DateTime.now()), () {
        source = null;
        expiresAt = null;
        isPremium.value = false;
      });
    }
  }

  /// true cuando el listener ya entregó al menos un snapshot del servidor.
  bool _listening = false;

  /// Empieza a escuchar el premium de [uid] (idempotente).
  void start(String uid) {
    if (_uid == uid && _sub != null) return;
    _sub?.cancel();
    _uid = uid;
    _listening = false;
    _sub = db.collection('entitlements').doc(uid).snapshots().listen(
      (doc) {
        // Un snapshot de la caché local puede estar viejo.
        if (!doc.metadata.isFromCache) _listening = true;
        _apply(doc.data());
      },
      onError: (_) {}, // sin acceso o sin red: se queda con el último valor
    );
  }

  /// Deja de escuchar (al cerrar sesión).
  void stop() {
    _sub?.cancel();
    _sub = null;
    _listening = false;
    _expiryTimer?.cancel();
    _uid = null;
    source = null;
    expiresAt = null;
    isPremium.value = false;
  }

  /// Consulta puntual del premium de [uid]: el propio usuario, o un atleta
  /// para el entrenador que registra su sesión. Ante un error, no premium.
  Future<bool> fetch(String uid) async {
    // El listener ya tiene el valor al día: no hace falta otra lectura.
    if (uid == _uid && _listening) return isPremium.value;
    try {
      final doc = await db.collection('entitlements').doc(uid).get();
      if (uid == _uid) _apply(doc.data());
      return premiumFrom(doc.data());
    } catch (_) {
      return uid == _uid ? isPremium.value : false;
    }
  }
}
