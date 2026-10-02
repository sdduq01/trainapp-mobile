import 'package:flutter/material.dart';

import '../../workout/models/routine.dart';
import '../../workout/screens/edit_routine_page.dart';
import '../../workout/screens/history_page.dart';
import '../../workout/screens/workout_session_page.dart';
import '../../workout/services/routine_service.dart';
import '../../workout/services/session_service.dart';
import '../services/trainer_link_service.dart';

/// Detalle de un atleta aceptado, del lado entrenador: lanzar y registrar su
/// sesión desde el equipo del entrenador, ver/editar su rutina, ver su
/// historial y revocar el acceso.
class AthleteDetailPage extends StatefulWidget {
  final String athleteUid;
  final String athleteEmail;

  const AthleteDetailPage({
    required this.athleteUid,
    required this.athleteEmail,
    super.key,
  });

  @override
  State<AthleteDetailPage> createState() => _AthleteDetailPageState();
}

class _AthleteDetailPageState extends State<AthleteDetailPage> {
  String get athleteUid => widget.athleteUid;
  String get athleteEmail => widget.athleteEmail;

  Routine? _routine;
  bool _loadingRoutine = true;
  String? _routineError;

  @override
  void initState() {
    super.initState();
    _loadRoutine();
  }

  Future<void> _loadRoutine() async {
    setState(() { _loadingRoutine = true; _routineError = null; });
    try {
      final routine = await RoutineService().getRoutine(athleteUid);
      if (!mounted) return;
      setState(() { _routine = routine; _loadingRoutine = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _routineError = '$e'; _loadingRoutine = false; });
    }
  }

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
    _loadRoutine();
  }

  Future<void> _startSession(BuildContext context, RoutineDay day) async {
    int today = 0;
    try {
      today = await SessionService().countSessionsOnDay(athleteUid, DateTime.now());
    } catch (_) {}
    if (today >= 1 && context.mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Ya entrenó hoy'),
          content: Text(
            '$athleteEmail ya registró $today sesión${today == 1 ? '' : 'es'} hoy. '
            'Se recomienda una sola sesión por día. ¿Iniciar igual?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Iniciar igual'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }
    if (!context.mounted) return;
    final completed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutSessionPage(
          day: day,
          athleteUid: athleteUid,
          athleteLabel: athleteEmail,
        ),
      ),
    );
    // La progresión pudo cambiar los pesos de la rutina del atleta.
    if (completed == true) _loadRoutine();
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
          _TrainNowSection(
            routine: _routine,
            loading: _loadingRoutine,
            error: _routineError,
            onRetry: _loadRoutine,
            onStart: (day) => _startSession(context, day),
          ),
          const SizedBox(height: 16),
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

/// Sección "Entrenar ahora": los días de la rutina del atleta, cada uno con
/// su botón para lanzar la sesión y registrarla desde el equipo del entrenador.
class _TrainNowSection extends StatelessWidget {
  final Routine? routine;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final ValueChanged<RoutineDay> onStart;

  const _TrainNowSection({
    required this.routine,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget body;
    if (loading) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (error != null) {
      body = Column(
        children: [
          const Text('No se pudo cargar la rutina del atleta.'),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      );
    } else if (routine == null || routine!.days.isEmpty) {
      body = Text(
        'Este atleta todavía no tiene rutina.',
        style: TextStyle(color: Colors.grey[600]),
      );
    } else {
      body = Column(
        children: [
          for (final day in routine!.days)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: ListTile(
                  title: Text(
                    'Día ${day.dayNumber} · ${day.name}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('${day.exercises.length} ejercicios'),
                  trailing: FilledButton.icon(
                    onPressed: day.exercises.isEmpty ? null : () => onStart(day),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Iniciar'),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fitness_center, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Entrenar ahora',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Lanza la sesión del atleta y registra sus pesos y repeticiones '
            'desde tu equipo. Se guarda en su historial y aplica su progresión.',
            style: TextStyle(color: Colors.grey[700], fontSize: 12),
          ),
          const SizedBox(height: 12),
          body,
        ],
      ),
    );
  }
}
