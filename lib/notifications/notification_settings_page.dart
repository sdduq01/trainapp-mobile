import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'local_reminders.dart';
import 'notification_prefs.dart';
import 'notification_service.dart';

/// Perfil → Notificaciones: qué categorías recibir y la hora del aviso de
/// racha. Se guarda en el perfil (lo leen también las Cloud Functions).
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  final _service = NotificationPrefsService();
  NotificationPrefs? _prefs;

  @override
  void initState() {
    super.initState();
    _service.get(_uid).then((p) {
      if (mounted) setState(() => _prefs = p);
    });
  }

  Future<void> _update(NotificationPrefs prefs) async {
    final before = _prefs;
    setState(() => _prefs = prefs);
    try {
      await _service.save(_uid, prefs);
      // Los avisos locales se recalculan con las preferencias nuevas (la
      // racha se reprograma al volver al inicio).
      if (!prefs.isOn(NotifCategory.streak)) await LocalReminders.cancelStreak();
      await LocalReminders.syncClasses(_uid);
    } catch (_) {
      if (!mounted) return;
      setState(() => _prefs = before);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar. Revisa tu conexión.')),
      );
    }
  }

  Future<void> _pickHour(NotificationPrefs prefs) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: prefs.streakHour, minute: 0),
      helpText: 'Hora del aviso de racha',
      initialEntryMode: TimePickerEntryMode.dialOnly,
    );
    if (picked != null) await _update(prefs.copyWith(streakHour: picked.hour));
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: prefs == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final c in NotifCategory.values) ...[
                  SwitchListTile.adaptive(
                    title: Text(c.label),
                    subtitle: Text(
                      c == NotifCategory.streak
                          ? '${c.description} Solo con premium.'
                          : c.description,
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: prefs.isOn(c),
                    onChanged: (v) =>
                        _update(prefs.copyWith(toggle: c, value: v)),
                  ),
                  if (c == NotifCategory.streak && prefs.isOn(c))
                    ListTile(
                      contentPadding: const EdgeInsets.only(left: 32, right: 16),
                      leading: const Icon(Icons.schedule, size: 20),
                      title: const Text('Hora del aviso'),
                      trailing: Text(
                        '${prefs.streakHour.toString().padLeft(2, '0')}:00',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onTap: () => _pickHour(prefs),
                    ),
                ],
                const Divider(height: 32),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Ajustes de notificaciones del teléfono'),
                  subtitle: const Text(
                    'Si no te llega ninguna, revisa que estén permitidas para TrainApp.',
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: NotificationService.instance.openSystemSettings,
                ),
              ],
            ),
    );
  }
}
