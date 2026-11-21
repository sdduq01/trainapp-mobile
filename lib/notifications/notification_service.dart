import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../firebase_options.dart';
import 'notification_prefs.dart';

/// Pantalla a la que lleva tocar una notificación (`data.route` de los push y
/// `payload` de las locales). Las maneja HomePage.
abstract final class NotifRoute {
  static const home = 'home';
  static const profile = 'profile';
  static const gymClasses = 'gym_classes';
}

/// Ids de los avisos locales. Los de clase son [classBase] + hash del id.
abstract final class NotifIds {
  static const streak = 1000;
  static const classBase = 2000000;
  static const classRange = 1000000000;

  /// FNV-1a de 32 bits: estable entre ejecuciones (String.hashCode no lo
  /// garantiza).
  static int stableHash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xffffffff;
    }
    return h;
  }

  static int forClass(String classId) =>
      classBase + stableHash(classId) % classRange;

  /// Push mostrados con la app abierta: mismo `tag` → misma notificación
  /// (Android solo reemplaza si coinciden tag e id). Rango aparte de los
  /// avisos programados.
  static const _pushBase = 1100000000;

  static int forPush(String? tag) =>
      _pushBase +
      (tag == null
          ? DateTime.now().millisecondsSinceEpoch % classRange
          : stableHash(tag) % classRange);

  static bool isClass(int id) => id >= classBase && id < classBase + classRange;
}

/// Push que piden cancelar el recordatorio local de una clase (la cancelaron,
/// cambió de hora o retiraron al atleta), también con la app cerrada.
const _cancelReminderTypes = {'class_cancelled', 'class_moved', 'enrollment_removed'};

@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  final classId = message.data['classId'];
  if (!_cancelReminderTypes.contains(message.data['type']) || classId == null) {
    return;
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(settings: NotificationService._initSettings);
  await plugin.cancel(id: NotifIds.forClass(classId));
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  static const _initSettings = InitializationSettings(
    android: AndroidInitializationSettings('ic_notification'),
  );

  final plugin = FlutterLocalNotificationsPlugin();

  /// Ruta pendiente de abrir (toque en una notificación). HomePage la escucha
  /// y la consume.
  final pendingRoute = ValueNotifier<String?>(null);

  bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static tz.Location get bogota => tz.getLocation('America/Bogota');

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Antes de runApp. No falla nunca: sin notificaciones la app sigue igual.
  Future<void> init() async {
    if (!_supported) return;
    try {
      tzdata.initializeTimeZones();
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
      await plugin.initialize(
        settings: _initSettings,
        onDidReceiveNotificationResponse: (r) => _open(r.payload),
      );
      await _createChannels();

      final launch = await plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _open(launch!.notificationResponse?.payload);
      }
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _open(initial.data['route']);
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _open(m.data['route']));
      FirebaseMessaging.onMessage.listen(_showForeground);
    } catch (e) {
      debugPrint('Notificaciones no disponibles: $e');
    }
  }

  void _open(String? route) {
    if (route != null && route.isNotEmpty) pendingRoute.value = route;
  }

  Future<void> _createChannels() async {
    final android = _android;
    if (android == null) return;
    await android.createNotificationChannel(const AndroidNotificationChannel(
      'general',
      'General',
      importance: Importance.high,
    ));
    for (final c in NotifCategory.values) {
      await android.createNotificationChannel(AndroidNotificationChannel(
        c.id,
        c.label,
        description: c.description,
        importance: Importance.high,
      ));
    }
  }

  static NotificationDetails detailsFor(String channelId, {String? tag}) {
    final category = NotifCategory.values.where((c) => c.id == channelId);
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        category.isEmpty ? 'General' : category.first.label,
        importance: Importance.high,
        priority: Priority.high,
        tag: tag,
        styleInformation: const BigTextStyleInformation(''),
      ),
    );
  }

  /// Con la app abierta Android no muestra los push solo: se muestran como
  /// locales en su canal.
  Future<void> _showForeground(RemoteMessage m) async {
    final classId = m.data['classId'];
    if (_cancelReminderTypes.contains(m.data['type']) && classId != null) {
      await plugin.cancel(id: NotifIds.forClass(classId));
    }
    final n = m.notification;
    if (n == null) return; // push de datos (silencioso)
    final tag = m.data['tag'];
    await plugin.show(
      id: NotifIds.forPush(tag),
      title: n.title,
      body: n.body,
      notificationDetails:
          detailsFor(m.data['category'] ?? 'general', tag: tag),
      payload: m.data['route'],
    );
  }

  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required NotifCategory category,
    required String route,
  }) async {
    if (!_supported) return;
    await plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(at, bogota),
      notificationDetails: detailsFor(category.id),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      payload: route,
    );
  }

  Future<void> cancel(int id) async {
    if (_supported) await plugin.cancel(id: id);
  }

  Future<List<int>> pendingIds() async {
    if (!_supported) return const [];
    return (await plugin.pendingNotificationRequests()).map((r) => r.id).toList();
  }

  /// Ajustes de notificaciones de TrainApp en Android.
  Future<void> openSystemSettings() async {
    try {
      await plugin.openAppNotificationSettings();
    } catch (_) {}
  }

  /// La primera vez en el inicio (una vez por cuenta) explica para qué sirven
  /// y pide el permiso de Android 13+.
  Future<void> maybeAskPermission(BuildContext context, String uid) async {
    final android = _android;
    if (!_supported || android == null) return;
    try {
      if (await android.areNotificationsEnabled() ?? true) return;
      final prefs = await SharedPreferences.getInstance();
      final key = 'notif_permission_asked_$uid';
      if (prefs.getBool(key) ?? false) return;
      await prefs.setBool(key, true);
      if (!context.mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (dctx) => AlertDialog(
          title: const Text('¿Activar notificaciones?'),
          content: const Text(
            'Te avisamos cuando estés por perder tu racha, antes de tus clases '
            'y cuando un gimnasio o un entrenador te invite. Puedes elegir '
            'cuáles recibir en tu perfil.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('Activar'),
            ),
          ],
        ),
      );
      if (ok == true) await android.requestNotificationsPermission();
    } catch (_) {
      // Sin permiso la app funciona igual.
    }
  }
}
