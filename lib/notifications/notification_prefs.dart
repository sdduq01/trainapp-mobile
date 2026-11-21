import 'package:cloud_firestore/cloud_firestore.dart' show SetOptions;

import '../core/firebase/firestore_instance.dart';

/// Categorías de notificación. El `id` es la clave en
/// `profiles/{uid}.notificationPrefs`, el canal de Android y la `category`
/// que mandan las Cloud Functions (`functions/notify.js`): deben coincidir.
enum NotifCategory {
  streak('streak', 'Racha', 'Aviso cuando estás por perder tu racha semanal.'),
  classes('classes', 'Mis clases',
      'Recordatorios de tus clases y avisos si se cancelan o cambian de hora.'),
  gymNews('gym_news', 'Novedades del gimnasio',
      'Nuevas clases publicadas por tu gimnasio.'),
  invites('invites', 'Invitaciones',
      'Invitaciones de gimnasios y entrenadores, y cuando aceptan las tuyas.'),
  trainer('trainer', 'Mi entrenador', 'Cuando tu entrenador cambia tu rutina.'),
  premium('premium', 'Premium',
      'Fin de la prueba gratis y cambios en el premium de tu gimnasio.');

  final String id;
  final String label;
  final String description;

  const NotifCategory(this.id, this.label, this.description);
}

class NotificationPrefs {
  static const defaultStreakHour = 18;

  final Map<NotifCategory, bool> enabled;

  /// Hora (0–23, Bogotá) del aviso de racha.
  final int streakHour;

  const NotificationPrefs({required this.enabled, required this.streakHour});

  bool isOn(NotifCategory c) => enabled[c] ?? true;

  factory NotificationPrefs.fromMap(Map<String, dynamic>? m) =>
      NotificationPrefs(
        enabled: {
          for (final c in NotifCategory.values) c: m?[c.id] as bool? ?? true,
        },
        streakHour: (m?['streakHour'] as num?)?.toInt() ?? defaultStreakHour,
      );

  Map<String, dynamic> toMap() => {
        for (final e in enabled.entries) e.key.id: e.value,
        'streakHour': streakHour,
      };

  NotificationPrefs copyWith({NotifCategory? toggle, bool? value, int? streakHour}) =>
      NotificationPrefs(
        enabled: {...enabled, if (toggle != null) toggle: value ?? true},
        streakHour: streakHour ?? this.streakHour,
      );
}

/// Preferencias en el perfil (las leen también las Cloud Functions).
/// Se guardan en memoria unos minutos: el inicio las consulta para la racha
/// y para las clases en la misma apertura.
class NotificationPrefsService {
  static const _ttl = Duration(minutes: 10);
  static final _cache = <String, (DateTime, NotificationPrefs)>{};

  Future<NotificationPrefs> get(String uid) async {
    final cached = _cache[uid];
    if (cached != null && DateTime.now().difference(cached.$1) < _ttl) {
      return cached.$2;
    }
    try {
      final doc = await db.collection('profiles').doc(uid).get();
      final prefs = NotificationPrefs.fromMap(
          doc.data()?['notificationPrefs'] as Map<String, dynamic>?);
      _cache[uid] = (DateTime.now(), prefs);
      return prefs;
    } catch (_) {
      return NotificationPrefs.fromMap(null); // sin red: todo activo
    }
  }

  Future<void> save(String uid, NotificationPrefs prefs) async {
    await db
        .collection('profiles')
        .doc(uid)
        .set({'notificationPrefs': prefs.toMap()}, SetOptions(merge: true));
    _cache[uid] = (DateTime.now(), prefs);
  }
}
