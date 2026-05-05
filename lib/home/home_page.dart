import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/auth_service.dart';
import '../auth/auth_gate.dart';
import '../workout/models/routine.dart';
import '../workout/services/routine_service.dart';
import '../workout/screens/edit_routine_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Routine? _routine;
  bool _loading = true;
  final _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadRoutine();
  }

  Future<void> _loadRoutine() async {
    final routine = await RoutineService().getRoutine(_user!.uid);
    if (mounted) setState(() { _routine = routine; _loading = false; });
  }

  Future<void> _openEdit() async {
    if (_routine == null) return;
    final updated = await Navigator.push<Routine>(
      context,
      MaterialPageRoute(builder: (_) => EditRoutinePage(routine: _routine!)),
    );
    if (updated != null) {
      setState(() => _routine = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TrainApp'),
        actions: [
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
              : _RoutineView(routine: _routine!),
    );
  }
}

class _RoutineView extends StatelessWidget {
  final Routine routine;

  const _RoutineView({required this.routine});

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

        for (final day in routine.days) ...[
          _DayCard(day: day),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  final RoutineDay day;

  const _DayCard({required this.day});

  IconData get _icon {
    return switch (day.focus) {
      'push'  => Icons.fitness_center,
      'pull'  => Icons.sports_gymnastics,
      'legs'  => Icons.directions_run,
      'upper' => Icons.accessibility_new,
      'lower' => Icons.directions_walk,
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
        ],
      ),
    );
  }
}
