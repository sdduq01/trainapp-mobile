import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firebase/firestore_instance.dart';
import '../gym/models/gym.dart';
import '../gym/models/gym_class.dart';
import '../home/streak.dart';
import 'notification_prefs.dart';
import 'notification_service.dart';
import 'reminder_plans.dart';

/// Avisos locales programados en el teléfono: racha y clases inscritas.
/// Nunca lanzan: si algo falla, simplemente no hay aviso.
abstract final class LocalReminders {
  static final _notifs = NotificationService.instance;

  /// Reprograma el aviso de racha con el resultado recién calculado. Solo
  /// premium (la racha es premium).
  static Future<void> updateStreak({
    required String uid,
    required bool premium,
    required StreakResult streak,
    required WeekRecord current,
    String? forge,
  }) async {
    try {
      await _notifs.cancel(NotifIds.streak);
      if (!premium) return;
      final prefs = await NotificationPrefsService().get(uid);
      if (!prefs.isOn(NotifCategory.streak)) return;
      final plan = ReminderPlans.streak(
        streak: streak,
        current: current,
        now: DateTime.now(),
        hour: prefs.streakHour,
        forge: forge,
      );
      if (plan == null) return;
      await _notifs.schedule(
        id: NotifIds.streak,
        at: plan.at,
        title: plan.title,
        body: plan.body,
        category: NotifCategory.streak,
        route: NotifRoute.home,
      );
    } catch (_) {}
  }

  static Future<void> cancelStreak() async {
    try {
      await _notifs.cancel(NotifIds.streak);
    } catch (_) {}
  }

  /// Reprograma los recordatorios de todas las clases futuras en las que el
  /// usuario está inscrito (y borra los de las que ya no). Se llama al abrir
  /// la app, al inscribirse y al cancelar.
  static Future<void> syncClasses(String uid) async {
    try {
      final prefs = await NotificationPrefsService().get(uid);
      final wanted = <int, ReminderPlan>{};
      if (prefs.isOn(NotifCategory.classes)) {
        final now = DateTime.now().toUtc();
        final enrollments = await db
            .collectionGroup('enrollments')
            .where('uid', isEqualTo: uid)
            .where('startsAt', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
            .get();
        final windows = <String, int>{};
        for (final e in enrollments.docs) {
          final gymId = e.data()['gymId'] as String?;
          final classId = e.data()['classId'] as String?;
          if (gymId == null || classId == null) continue;
          final classDoc = await db
              .collection('gyms').doc(gymId)
              .collection('classes').doc(classId)
              .get();
          if (!classDoc.exists) continue;
          final gymClass = GymClass.fromMap(gymId, classId, classDoc.data()!);
          windows[gymId] ??= await _cancelWindow(gymId);
          final plan = ReminderPlans.classReminder(
            gymClass: gymClass,
            cancelWindowHours: windows[gymId]!,
            now: now,
          );
          if (plan != null) wanted[NotifIds.forClass(classId)] = plan;
        }
      }

      for (final id in await _notifs.pendingIds()) {
        if (NotifIds.isClass(id) && !wanted.containsKey(id)) {
          await _notifs.cancel(id);
        }
      }
      for (final e in wanted.entries) {
        await _notifs.schedule(
          id: e.key,
          at: e.value.at,
          title: e.value.title,
          body: e.value.body,
          category: NotifCategory.classes,
          route: NotifRoute.gymClasses,
        );
      }
    } catch (_) {}
  }

  /// Al cerrar sesión: los avisos de la cuenta no siguen sonando.
  static Future<void> cancelAll() async {
    try {
      await _notifs.plugin.cancelAll();
    } catch (_) {}
  }

  static Future<int> _cancelWindow(String gymId) async {
    try {
      final doc = await db.collection('gyms').doc(gymId).get();
      return (doc.data()?['cancelWindowHours'] as num?)?.toInt() ??
          Gym.kDefaultCancelWindowHours;
    } catch (_) {
      return Gym.kDefaultCancelWindowHours;
    }
  }
}
