import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'coach_marks.dart';

/// Pantallas con tutorial de primer uso.
enum TutorialScreen { home, session, sessionRest, editRoutine, editExercise }

/// Recuerda, por usuario y dispositivo, qué tutoriales ya vio. Cada uno se
/// muestra solo la primera vez; desde el perfil se pueden volver a ver todos.
class TutorialService {
  static String _key(String uid, TutorialScreen s) =>
      // `tutorial_home_done_` se mantiene por compatibilidad.
      s == TutorialScreen.home
          ? 'tutorial_home_done_$uid'
          : 'tutorial_${s.name}_done_$uid';

  static String? get _uid {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null; // Firebase sin inicializar (tests)
    }
  }

  Future<bool> shouldShow(TutorialScreen screen) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      return !(prefs.getBool(_key(uid, screen)) ?? false);
    } catch (_) {
      return false;
    }
  }

  Future<void> markDone(TutorialScreen screen) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key(uid, screen), true);
    } catch (_) {}
  }

  /// "Ver los tutoriales de nuevo": cada uno vuelve a salir la próxima vez
  /// que se abra su pantalla.
  Future<void> resetAll() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final s in TutorialScreen.values) {
        await prefs.remove(_key(uid, s));
      }
    } catch (_) {}
  }

  /// Muestra el tutorial de [screen] si aún no se ha visto. Espera [delay]
  /// para que la pantalla termine de dibujarse. Visto u omitido, no se
  /// vuelve a mostrar solo.
  static Future<void> runOnce(
    BuildContext context,
    TutorialScreen screen,
    List<CoachMarkStep> Function() steps, {
    Duration delay = const Duration(milliseconds: 500),
  }) async {
    final service = TutorialService();
    if (!await service.shouldShow(screen)) return;
    await Future<void>.delayed(delay);
    if (!context.mounted) return;
    await service.markDone(screen); // antes: si se cierra la app, no se repite
    if (!context.mounted) return;
    await CoachMarks.show(context, steps());
  }
}
