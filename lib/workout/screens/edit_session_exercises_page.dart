import 'package:flutter/material.dart';
import '../data/muscle_groups.dart';
import '../models/routine.dart';
import '../widgets/add_exercise_sheet.dart';
import '../widgets/exercise_edit_dialog.dart';

/// Edición de los ejercicios restantes de una sesión activa (los que faltan
/// por hacer hoy, incluyendo el actual). Devuelve la lista actualizada por
/// [Navigator.pop] si hubo cambios, o `null` si se salió sin modificar nada.
///
/// El primer elemento de [exercises] siempre corresponde al ejercicio en
/// curso — solo se puede quitar si [canRemoveCurrent] es true (sin series
/// ni calentamiento ya registrados para él).
class EditSessionExercisesPage extends StatefulWidget {
  final String dayName;
  final List<RoutineExercise> exercises;
  final bool canRemoveCurrent;

  const EditSessionExercisesPage({
    required this.dayName,
    required this.exercises,
    required this.canRemoveCurrent,
    super.key,
  });

  @override
  State<EditSessionExercisesPage> createState() =>
      _EditSessionExercisesPageState();
}

class _EditSessionExercisesPageState extends State<EditSessionExercisesPage> {
  late List<RoutineExercise> _exercises;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _exercises = List.of(widget.exercises);
  }

  bool _canRemove(int idx) =>
      idx == 0 ? widget.canRemoveCurrent : true;

  Future<void> _editExercise(int idx) async {
    final updated = await showExerciseEditDialog(context, _exercises[idx]);
    if (updated == null) return;
    setState(() {
      _exercises[idx] = updated;
      _changed = true;
    });
  }

  Future<void> _removeExercise(int idx) async {
    if (_exercises.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe quedar al menos un ejercicio hoy.')),
      );
      return;
    }
    final ex = _exercises[idx];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Quitar ejercicio?'),
        content: Text('Se quitará "${ex.name}" de hoy y de la rutina.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _exercises.removeAt(idx);
      _changed = true;
    });
  }

  Future<void> _addExercise() async {
    final picked = await showAddExerciseSheet(
      context,
      dayLabel: widget.dayName,
      existingExerciseIds: _exercises.map((e) => e.exerciseId).toSet(),
    );
    if (picked == null) return;
    setState(() {
      _exercises.add(routineExerciseFromCatalog(picked));
      _changed = true;
    });
  }

  void _done() => Navigator.of(context).pop(_changed ? _exercises : null);

  String _stepLabel(double step) =>
      step % 1 == 0 ? '${step.toInt()}' : '$step';

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Ejercicios de hoy · ${widget.dayName}'),
          actions: [
            TextButton(onPressed: _done, child: const Text('Listo')),
          ],
        ),
        body: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
          itemCount: _exercises.length,
          itemBuilder: (_, idx) {
            final ex = _exercises[idx];
            final isCurrent = idx == 0;
            return Card(
              key: ValueKey(ex.exerciseId),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: isCurrent
                    ? const Icon(Icons.play_circle_fill, color: Colors.green)
                    : const Icon(Icons.fitness_center, color: Colors.grey),
                title: Text(ex.name),
                subtitle: Text(
                  '${ex.sets} series · ${ex.repsMin}–${ex.repsMax}'
                  '${ex.isIsometric ? ' s' : ' reps'}'
                  ' · ${ex.restSeconds}s descanso'
                  ' · +${_stepLabel(ex.progressionStep)} ${ex.weightUnit}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _editExercise(idx),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: _canRemove(idx) ? Colors.red : Colors.grey.shade400,
                      ),
                      onPressed: _canRemove(idx) ? () => _removeExercise(idx) : null,
                      tooltip: _canRemove(idx)
                          ? null
                          : 'Ya tiene series registradas hoy',
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addExercise,
          icon: const Icon(Icons.add),
          label: const Text('Agregar ejercicio'),
        ),
      ),
    );
  }
}
