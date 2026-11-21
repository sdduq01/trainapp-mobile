import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../core/firebase/firestore_instance.dart';

/// Token FCM del dispositivo en `push_tokens/{uid}/tokens/{token}`: ahí lo
/// buscan las Cloud Functions para mandar los push a todos sus dispositivos.
class PushTokenService {
  static StreamSubscription<String>? _refreshSub;

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static CollectionReference<Map<String, dynamic>> _tokens(String uid) =>
      db.collection('push_tokens').doc(uid).collection('tokens');

  static Future<void> _save(String uid, String token) =>
      _tokens(uid).doc(token).set({
        'token': token,
        'platform': 'android',
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// Al entrar al inicio. Silencioso si falla (sin red o sin Play Services).
  static Future<void> register(String uid) async {
    if (!_supported) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _save(uid, token);
      await _refreshSub?.cancel();
      _refreshSub = FirebaseMessaging.instance.onTokenRefresh
          .listen((t) => _save(uid, t).catchError((_) {}));
    } catch (e) {
      debugPrint('No se pudo registrar el token: $e');
    }
  }

  /// Antes de cerrar sesión: este dispositivo deja de recibir los push de la
  /// cuenta (si otra persona entra después, no le llegan los del anterior).
  static Future<void> unregister(String uid) async {
    if (!_supported) return;
    await _refreshSub?.cancel();
    _refreshSub = null;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _tokens(uid).doc(token).delete();
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {
      // Sin red: el token viejo se limpia solo cuando FCM lo marque inválido.
    }
  }
}
