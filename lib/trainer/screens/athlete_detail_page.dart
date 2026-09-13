import 'package:flutter/material.dart';

import '../../workout/screens/edit_routine_page.dart';
import '../../workout/screens/history_page.dart';
import '../../workout/services/routine_service.dart';
import '../services/trainer_link_service.dart';

/// Detalle de un atleta aceptado, del lado entrenador: ver/editar su rutina,
/// ver su historial (solo lectura) y revocar el acceso.
class AthleteDetailPage extends StatelessWidget {
  final String athleteUid;
  final String athleteEmail;

  const AthleteDetailPage({
    required this.athleteUid,
    required this.athleteEmail,
    super.key,
  });

  Future<void> _openRoutine(BuildContext context) async {
    final routine = await RoutineService().getRoutine(athleteUid);
    if (!context.mounted) return;
    if (routine == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este atleta todavía no tiene rutina.')),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditRoutinePage(routine: routine)),
    );
  }

  void _openHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistoryPage(
          athleteUid: athleteUid,
          athleteLabel: athleteEmail,
        ),
      ),
    );
  }

  Future<void> _revoke(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Revocar acceso'),
        content: Text(
          'Vas a dejar de tener acceso a la rutina e historial de $athleteEmail. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revocar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await TrainerLinkService().deleteLink(athleteUid);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(athleteEmail)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Ver / editar rutina'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openRoutine(context),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Ver historial'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openHistory(context),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _revoke(context),
            icon: const Icon(Icons.link_off),
            label: const Text('Revocar acceso'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }
}
