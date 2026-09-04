import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../profile/profile_service.dart';
import '../data/muscle_groups.dart';
import '../models/exercise.dart';
import '../models/progression_type.dart';
import '../models/routine.dart';
import '../services/exercise_service.dart';
import '../services/routine_service.dart';

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
    int sets = ex.sets;
    int repsMin = ex.repsMin;
    int repsMax = ex.repsMax;
    int restSeconds = ex.restSeconds;
    String weightUnit = ex.weightUnit;
    double progressionStep = ex.progressionStep;
    ProgressionType progressionType = ex.progressionType;

    const steps = [1.0, 1.25, 2.5, 5.0, 10.0];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(ex.name, style: const TextStyle(fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Counter(
                  label: 'Series',
                  value: sets,
                  min: 1, max: 8,
                  onChanged: (v) => setDialogState(() => sets = v),
                ),
                const SizedBox(height: 16),
                _Counter(
                  label: 'Reps mínimas',
                  value: repsMin,
                  min: 1, max: 30,
                  onChanged: (v) => setDialogState(() => repsMin = v),
                ),
                const SizedBox(height: 16),
                _Counter(
                  label: 'Reps máximas',
                  value: repsMax,
                  min: 1, max: 30,
                  onChanged: (v) => setDialogState(() => repsMax = v),
                ),
                const SizedBox(height: 16),
                _Counter(
                  label: 'Descanso (seg)',
                  value: restSeconds,
                  min: 30, max: 300, step: 15,
                  onChanged: (v) => setDialogState(() => restSeconds = v),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 8),
                const Text('Unidad de peso', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'kg', label: Text('kg')),
                    ButtonSegment(value: 'lbs', label: Text('lbs')),
                    ButtonSegment(value: 'unidades', label: Text('Unidades')),
                  ],
                  selected: {weightUnit},
                  onSelectionChanged: (s) =>
                      setDialogState(() => weightUnit = s.first),
                ),
                if (weightUnit == 'unidades') ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Para máquinas con placas sin marcar: cada unidad equivale a una placa.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
                const SizedBox(height: 16),
                const Text('Incremento de progresión', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: steps.map((s) {
                    final label = s % 1 == 0 ? '${s.toInt()}' : '$s';
                    return ChoiceChip(
                      label: Text('$label ${_unitAbbrev(weightUnit)}'),
                      selected: progressionStep == s,
                      onSelected: (_) => setDialogState(() => progressionStep = s),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Tipo de progresión',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ProgressionType.values
                      .map((p) => ChoiceChip(
                            label: Text(p.label),
                            selected: progressionType == p,
                            onSelected: (_) =>
                                setDialogState(() => progressionType = p),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                _updateExercise(
                  dayIdx, exIdx,
                  RoutineExercise(
                    exerciseId: ex.exerciseId,
                    name: ex.name,
                    sets: sets,
                    repsMin: repsMin,
                    repsMax: repsMax < repsMin ? repsMin : repsMax,
                    currentWeight: ex.currentWeight,
                    restSeconds: restSeconds,
                    weightUnit: weightUnit,
                    progressionStep: progressionStep,
                    progressionType: progressionType,
                    isIsometric: ex.isIsometric,
                  ),
                );
                Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
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
    // Carga ejercicios de Firestore antes de abrir el sheet
    List<Exercise>? catalog;
    String? error;
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      final list = await ExerciseService().getExercises();
      final profile =
          userId == null ? null : await ProfileService().getProfile(userId);
      final showCardio = profile?.cardioEnabled ?? false;
      final showStretch = profile?.stretchingEnabled ?? false;
      catalog = list.where((e) {
        if (e.muscleGroup == 'cardio') return showCardio;
        if (e.muscleGroup == 'estiramiento') return showStretch;
        return true;
      }).toList();
    } catch (e) {
      error = e.toString();
    }

    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar ejercicios: $error')),
      );
      return;
    }

    final day = _routine.days[dayIdx];
    final existing = day.exercises.map((e) => e.exerciseId).toSet();

    final byGroupMap = <String, List<Exercise>>{};
    for (final e in catalog!) {
      byGroupMap.putIfAbsent(e.muscleGroup, () => []).add(e);
    }
    final groups = [
      for (final g in muscleGroupOrder)
        if ((byGroupMap[g] ?? []).isNotEmpty) g,
    ];

    // Grupo seleccionado dentro del sheet (null = mostrando la lista de grupos).
    // Vive fuera de los builders para persistir entre setSheetState.
    String? selectedGroup;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, controller) => StatefulBuilder(
          builder: (sheetCtx, setSheetState) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    if (selectedGroup != null)
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => setSheetState(() => selectedGroup = null),
                      ),
                    Expanded(
                      child: Text(
                        selectedGroup == null
                            ? 'Grupo muscular — ${day.name}'
                            : '${muscleGroupLabels[selectedGroup] ?? selectedGroup!} — ${day.name}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: selectedGroup == null
                    ? ListView(
                        controller: controller,
                        children: [
                          for (final g in groups)
                            ListTile(
                              title: Text(muscleGroupLabels[g] ?? g),
                              subtitle: Text('${byGroupMap[g]!.length} ejercicio(s)'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => setSheetState(() => selectedGroup = g),
                            ),
                        ],
                      )
                    : ListView.builder(
                        controller: controller,
                        itemCount: byGroupMap[selectedGroup]!.length,
                        itemBuilder: (_, i) {
                          final ex = byGroupMap[selectedGroup]![i];
                          final alreadyAdded = existing.contains(ex.id);
                          return ListTile(
                            title: Text(ex.name),
                            subtitle: Text(
                              '${ex.defaultSets}×${ex.defaultRepsMin}-${ex.defaultRepsMax} · ${ex.restSeconds}s',
                            ),
                            trailing: alreadyAdded
                                ? const Icon(Icons.check, color: Colors.green)
                                : const Icon(Icons.add),
                            enabled: !alreadyAdded,
                            onTap: alreadyAdded ? null : () {
                              _addExercise(
                                dayIdx,
                                RoutineExercise(
                                  exerciseId: ex.id,
                                  name: ex.name,
                                  sets: ex.defaultSets,
                                  repsMin: ex.defaultRepsMin,
                                  repsMax: ex.defaultRepsMax,
                                  restSeconds: ex.restSeconds,
                                  weightUnit: ex.defaultWeightUnit,
                                  progressionStep: ex.defaultProgressionStep,
                                  isIsometric: ex.isIsometric,
                                  progressionType: defaultProgressionTypeFor(ex),
                                ),
                              );
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
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

  String _unitAbbrev(String unit) => switch (unit) {
        'lbs' => 'lb',
        'unidades' => 'u',
        _ => 'kg',
      };
}

// ── Widget contador ──────────────────────────────────────────

class _Counter extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  const _Counter({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.step = 1,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: value > min
              ? () => onChanged((value - step).clamp(min, max))
              : null,
        ),
        SizedBox(
          width: 40,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: value < max
              ? () => onChanged((value + step).clamp(min, max))
              : null,
        ),
      ],
    );
  }
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
