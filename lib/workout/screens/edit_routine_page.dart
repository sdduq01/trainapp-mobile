import 'package:flutter/material.dart';
import '../data/muscle_groups.dart';
import '../models/routine.dart';
import '../services/routine_service.dart';
import '../widgets/add_exercise_sheet.dart';
import '../widgets/exercise_edit_dialog.dart';

class EditRoutinePage extends StatefulWidget {
  final Routine routine;
  const EditRoutinePage({required this.routine, super.key});

  @override
  State<EditRoutinePage> createState() => _EditRoutinePageState();
}

class _EditRoutinePageState extends State<EditRoutinePage> {
  late Routine _routine;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _routine = widget.routine;
  }

  // ── Mutaciones de rutina ─────────────────────────────────

  void _removeExercise(int dayIdx, int exIdx) {
    final days = _copyDays();
    final exercises = List<RoutineExercise>.from(days[dayIdx].exercises)
      ..removeAt(exIdx);
    days[dayIdx] = _copyDay(days[dayIdx], exercises: exercises);
    setState(() => _routine = _copyRoutine(days));
  }

  void _updateExercise(int dayIdx, int exIdx, RoutineExercise updated) {
    final days = _copyDays();
    final exercises = List<RoutineExercise>.from(days[dayIdx].exercises);
    exercises[exIdx] = updated;
    days[dayIdx] = _copyDay(days[dayIdx], exercises: exercises);
    setState(() => _routine = _copyRoutine(days));
  }

  void _addExercise(int dayIdx, RoutineExercise exercise) {
    final days = _copyDays();
    final exercises = List<RoutineExercise>.from(days[dayIdx].exercises)
      ..add(exercise);
    days[dayIdx] = _copyDay(days[dayIdx], exercises: exercises);
    setState(() => _routine = _copyRoutine(days));
  }

  void _removeDay(int dayIdx) {
    final days = _copyDays()..removeAt(dayIdx);
    setState(() => _routine = _copyRoutine(_renumber(days)));
  }

  void _addDay(String name, String focus) {
    final days = _copyDays()
      ..add(RoutineDay(
        dayNumber: _routine.days.length + 1,
        name: name,
        focus: focus,
        exercises: const [],
      ));
    setState(() => _routine = _copyRoutine(_renumber(days)));
  }

  List<RoutineDay> _renumber(List<RoutineDay> days) => [
        for (int i = 0; i < days.length; i++)
          RoutineDay(
            dayNumber: i + 1,
            name: days[i].name,
            focus: days[i].focus,
            exercises: days[i].exercises,
          ),
      ];

  // ── Helpers de copia inmutable ───────────────────────────

  List<RoutineDay> _copyDays() => List<RoutineDay>.from(_routine.days);

  RoutineDay _copyDay(RoutineDay day, {required List<RoutineExercise> exercises}) =>
      RoutineDay(dayNumber: day.dayNumber, name: day.name, focus: day.focus, exercises: exercises);

  Routine _copyRoutine(List<RoutineDay> days) => Routine(
        userId: _routine.userId,
        type: _routine.type,
        name: _routine.name,
        weekNumber: _routine.weekNumber,
        createdAt: _routine.createdAt,
        days: days,
      );

  // ── Guardar ──────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await RoutineService().saveRoutine(_routine);
      if (mounted) Navigator.pop(context, _routine);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
  }

  // ── Diálogo de edición ───────────────────────────────────

  Future<void> _showEditDialog(int dayIdx, int exIdx) async {
    final ex = _routine.days[dayIdx].exercises[exIdx];
    final updated = await showExerciseEditDialog(context, ex);
    if (updated != null) _updateExercise(dayIdx, exIdx, updated);
  }

  // ── Diálogos de día ──────────────────────────────────────

  Future<void> _confirmAndRemoveDay(int dayIdx) async {
    final day = _routine.days[dayIdx];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar día?'),
        content: Text(
          'Se eliminará "Día ${day.dayNumber} · ${day.name}" '
          'con sus ${day.exercises.length} ejercicios.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) _removeDay(dayIdx);
  }

  Future<void> _showAddDayDialog() async {
    final result = await showDialog<({String name, String focus})>(
      context: context,
      builder: (_) => const _AddDayDialog(),
    );
    if (result != null) _addDay(result.name, result.focus);
  }

  // ── Sheet de agregar ejercicio (desde Firestore) ─────────

  Future<void> _showAddExerciseSheet(int dayIdx) async {
    final day = _routine.days[dayIdx];
    final picked = await showAddExerciseSheet(
      context,
      dayLabel: day.name,
      existingExerciseIds: day.exercises.map((e) => e.exerciseId).toSet(),
    );
    if (picked != null) {
      _addExercise(dayIdx, routineExerciseFromCatalog(picked));
    }
  }

  // ── UI ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar rutina'),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : TextButton(
                  onPressed: _save,
                  child: const Text('Guardar'),
                ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _routine.days.length + 1,
        itemBuilder: (_, dayIdx) {
          if (dayIdx == _routine.days.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: OutlinedButton.icon(
                onPressed: _showAddDayDialog,
                icon: const Icon(Icons.add),
                label: const Text('Agregar día'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            );
          }
          final day = _routine.days[dayIdx];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Día ${day.dayNumber} · ${day.name}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _showAddExerciseSheet(dayIdx),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Agregar'),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        tooltip: 'Eliminar día',
                        onPressed: () => _confirmAndRemoveDay(dayIdx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: day.exercises.length,
                  onReorder: (oldIdx, newIdx) {
                    final days = _copyDays();
                    final exercises = List<RoutineExercise>.from(days[dayIdx].exercises);
                    if (newIdx > oldIdx) newIdx--;
                    final item = exercises.removeAt(oldIdx);
                    exercises.insert(newIdx, item);
                    days[dayIdx] = _copyDay(days[dayIdx], exercises: exercises);
                    setState(() => _routine = _copyRoutine(days));
                  },
                  itemBuilder: (_, exIdx) {
                    final ex = day.exercises[exIdx];
                    return ListTile(
                      key: ValueKey('${dayIdx}_$exIdx'),
                      title: Text(ex.name),
                      subtitle: Text(
                        '${ex.sets} series · ${ex.repsMin}–${ex.repsMax} reps'
                        ' · ${ex.restSeconds}s descanso'
                        ' · +${_stepLabel(ex.progressionStep)} ${ex.weightUnit}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () => _showEditDialog(dayIdx, exIdx),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                            onPressed: () => _removeExercise(dayIdx, exIdx),
                          ),
                          const Icon(Icons.drag_handle, color: Colors.grey),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _stepLabel(double step) =>
      step % 1 == 0 ? '${step.toInt()}' : '$step';
}

// ── Dialog: agregar día ─────────────────────────────────────

class _AddDayDialog extends StatefulWidget {
  const _AddDayDialog();

  @override
  State<_AddDayDialog> createState() => _AddDayDialogState();
}

class _AddDayDialogState extends State<_AddDayDialog> {
  final _nameCtrl = TextEditingController();
  String _focus = 'push';

  static const Map<String, String> _focusOptions = {
    'push': 'Push',
    'pull': 'Pull',
    'legs': 'Legs',
    'upper': 'Upper',
    'lower': 'Lower',
    'full': 'Full body',
    'other': 'Otro',
  };

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo día'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nombre del día',
                hintText: 'Ej: Push, Brazos, Cardio…',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Enfoque',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _focusOptions.entries
                  .map((e) => ChoiceChip(
                        label: Text(e.value),
                        selected: _focus == e.key,
                        onSelected: (_) => setState(() => _focus = e.key),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(context, (name: name, focus: _focus));
          },
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}
