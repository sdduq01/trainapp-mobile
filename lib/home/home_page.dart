import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/auth_service.dart';
import '../auth/auth_gate.dart';
import '../workout/data/macrocycle_forjado.dart';
import '../workout/models/macrocycle_progress.dart';
import '../workout/models/routine.dart';
import '../workout/services/macrocycle_service.dart';
import '../workout/services/progression_service.dart';
import '../workout/services/routine_service.dart';
import '../workout/services/session_service.dart';
import '../profile/screens/profile_page.dart';
import '../workout/screens/edit_routine_page.dart';
import '../workout/screens/workout_session_page.dart';
import '../workout/screens/history_page.dart';
import '../workout/screens/routine_catalog_page.dart';
import 'weekly_progress_chart.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Routine? _routine;
  MacrocycleProgress? _macro;
  bool _loading = true;
  int _chartKey = 0;
  final _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadRoutine();
  }

  Future<void> _loadRoutine() async {
    final routine = await RoutineService().getRoutine(_user!.uid);
    MacrocycleProgress? macro;
    try {
      macro = await MacrocycleService().get(_user.uid);
    } catch (_) {
      macro = null;
    }
    if (mounted) {
      setState(() { _routine = routine; _macro = macro; _loading = false; });
    }
  }

  Future<void> _openEdit() async {
    if (_routine == null) return;
    final updated = await Navigator.push<Routine>(
      context,
      MaterialPageRoute(builder: (_) => EditRoutinePage(routine: _routine!)),
    );
    if (updated != null) setState(() => _routine = updated);
  }

  static int _weekOfYear(DateTime date) =>
      (date.difference(DateTime(date.year, 1, 1)).inDays / 7).floor() + 1;

  Future<void> _onSessionCompleted() async {
    setState(() => _chartKey++);
    await _loadRoutine(); // refresca pesos actualizados por progresión

    // Los hitos (Séneca / Yeah Buddy) no deben romper el flujo si Firestore
    // falla puntualmente: se reintentan al terminar la próxima sesión.
    try {
      final now = DateTime.now();
      final currentWeek = _weekOfYear(now);

      final totalExercises = _routine?.days
              .fold(0, (sum, d) => sum + d.exercises.length) ??
          0;
      final showSeneca = await ProgressionService().checkAndMarkSenecaMilestone(
        _user!.uid, now.year, currentWeek, totalExercises,
      );
      if (mounted && showSeneca) {
        _showSenecaDialog();
        return;
      }

      if (_routine == null) return;
      final sessions = await SessionService().getSessionsForUser(_user.uid);
      final sessionsThisWeek = sessions
          .where((s) => s.date.year == now.year && _weekOfYear(s.date) == currentWeek)
          .length;

      if (sessionsThisWeek >= _routine!.days.length) {
        final showYeahBuddy = await ProgressionService()
            .checkAndMarkYeahBuddyMilestone(_user.uid, currentWeek);
        if (mounted && showYeahBuddy) _showYeahBuddyDialog(currentWeek);
      }
    } catch (_) {
      // silencioso: los hitos se recalculan la próxima vez
    }
  }

  void _showYeahBuddyDialog(int weekNumber) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              const Text(
                'YEAHHHH\nBUDDY!!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Semana $weekNumber COMPLETADA 💪',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Ain't nothing but a peanut!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'LIGHT WEIGHT BABY! 🏋️',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSenecaDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              const Text(
                '¡MÁS DEL 30%\nDE PROGRESOS!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '"Una gema no puede ser pulida\nsin fricción, ni un hombre\nperfeccionado sin pruebas"',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '— Séneca',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'SEGUIR PULIENDO 💎',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TrainApp'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Mi perfil',
            onPressed: () async {
              final regenerated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              );
              if (regenerated == true) {
                setState(() { _loading = true; _chartKey++; });
                await _loadRoutine();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historial',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.menu_book),
            tooltip: 'Catálogo de rutinas',
            onPressed: () async {
              final activated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const RoutineCatalogPage()),
              );
              if (activated == true) {
                setState(() => _loading = true);
                await _loadRoutine();
              }
            },
          ),
          if (_routine != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar rutina',
              onPressed: _openEdit,
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthGate()),
                  (_) => false,
                );
              }
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _routine == null
              ? const Center(child: Text('No tienes una rutina asignada aún.'))
              : _RoutineView(
                  routine: _routine!,
                  macro: _macro,
                  chartKey: _chartKey,
                  onSessionCompleted: _onSessionCompleted,
                ),
    );
  }
}

class _RoutineView extends StatelessWidget {
  final Routine routine;
  final MacrocycleProgress? macro;
  final int chartKey;
  final VoidCallback onSessionCompleted;

  const _RoutineView({
    required this.routine,
    required this.macro,
    required this.chartKey,
    required this.onSessionCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    routine.name,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Semana ${routine.weekNumber} · ${routine.days.length} días',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (macro != null && !macro!.completed) ...[
          _MacrocycleBanner(macro: macro!),
          const SizedBox(height: 16),
        ],

        for (final day in routine.days) ...[
          _DayCard(day: day, onSessionCompleted: onSessionCompleted),
          const SizedBox(height: 12),
        ],

        const Divider(height: 32),
        WeeklyProgressChart(
          key: ValueKey(chartKey),
          plannedDaysPerWeek: routine.days.length,
          totalRoutineExercises:
              routine.days.fold(0, (sum, d) => sum + d.exercises.length),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Banner del macro ciclo activo: fase, énfasis y progreso por día.
class _MacrocycleBanner extends StatelessWidget {
  final MacrocycleProgress macro;
  const _MacrocycleBanner({required this.macro});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department,
                  color: Color(0xFFC41E3A), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  macro.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                'Fase ${macro.currentPhaseNumber}/${macro.totalPhases}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Día 4 · Énfasis ${macro.currentEmphasis}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final d in ForjadoPorElHierro.trackedDays)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: d == ForjadoPorElHierro.trackedDays.last ? 0 : 6),
                    child: Column(
                      children: [
                        Text('D$d',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 10)),
                        const SizedBox(height: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: macro.countFor(d) /
                                ForjadoPorElHierro.sessionsPerDay,
                            minHeight: 5,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation(
                                Color(0xFFC41E3A)),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${macro.countFor(d)}/${ForjadoPorElHierro.sessionsPerDay}',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final RoutineDay day;
  final VoidCallback onSessionCompleted;

  const _DayCard({required this.day, required this.onSessionCompleted});

  IconData get _icon {
    return switch (day.focus) {
      'push'  => Icons.fitness_center,
      'pull'  => Icons.sports_gymnastics,
      'legs'  => Icons.directions_run,
      'upper' => Icons.accessibility_new,
      'lower' => Icons.directions_walk,
      'core'  => Icons.self_improvement,
      _       => Icons.fitness_center,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(_icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(
          'Día ${day.dayNumber} · ${day.name}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${day.exercises.length} ejercicios'),
        children: [
          for (final ex in day.exercises)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              title: Text(ex.name),
              subtitle: Text(
                '${ex.sets} series · ${ex.repsMin}–${ex.repsMax} reps · ${ex.restSeconds}s descanso',
              ),
              trailing: ex.currentWeight > 0
                  ? Text(
                      '${ex.currentWeight} kg',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : const Text('— kg', style: TextStyle(color: Colors.grey)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Iniciar sesión'),
                onPressed: () async {
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid != null) {
                    int today = 0;
                    try {
                      today = await SessionService()
                          .countSessionsOnDay(uid, DateTime.now());
                    } catch (_) {}
                    if (today >= 1 && context.mounted) {
                      final proceed = await _showRestAdvisory(context);
                      if (proceed != true) return;
                    }
                  }
                  if (!context.mounted) return;
                  final completed = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WorkoutSessionPage(day: day),
                    ),
                  );
                  if (completed == true) onSessionCompleted();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso al iniciar una 2ª (o más) sesión el mismo día. No bloquea: el usuario
/// puede entrenar igual, pero se le recuerda que el descanso es progreso.
/// Devuelve `true` si decide entrenar de todas formas.
Future<bool?> _showRestAdvisory(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('El descanso también forja'),
      content: const SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Se recomienda una sola sesión por día. El descanso no es una '
              'pausa del progreso: es cuando el músculo se reconstruye más '
              'fuerte.',
            ),
            SizedBox(height: 16),
            Text(
              '"Ninguna cosa grande se crea de repente, como tampoco un '
              'racimo de uvas o un higo."',
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
            ),
            SizedBox(height: 4),
            Text(
              '— Epicteto',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 12,
                color: Color(0xFFC41E3A),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Mejor descanso'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Entrenar igual'),
        ),
      ],
    ),
  );
}
