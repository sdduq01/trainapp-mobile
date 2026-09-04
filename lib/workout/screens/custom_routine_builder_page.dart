import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../profile/profile_service.dart';
import '../data/muscle_groups.dart';
import '../models/exercise.dart';
import '../models/routine.dart';
import '../services/exercise_service.dart';
import '../services/routine_service.dart';
import '../widgets/create_exercise_dialog.dart';

/// Constructor de rutina personalizada desde cero.
/// El usuario define nombre, días (1-6), focus de cada día y agrega
/// ejercicios desde el catálogo agrupados por grupo muscular.
///
/// Pop con `true` si activó la rutina.
class CustomRoutineBuilderPage extends StatefulWidget {
  const CustomRoutineBuilderPage({super.key});

  @override
  State<CustomRoutineBuilderPage> createState() =>
      _CustomRoutineBuilderPageState();
}

class _CustomRoutineBuilderPageState extends State<CustomRoutineBuilderPage> {
  final _nameCtrl = TextEditingController(text: 'Mi rutina personalizada');
  final List<RoutineDay> _days = [
    const RoutineDay(dayNumber: 1, name: 'Día 1', focus: 'push', exercises: []),
  ];
  bool _saving = false;
  List<Exercise>? _catalog;

  static const Map<String, String> _focusLabels = {
    'push': 'Empuje (pecho/hombro/tríceps)',
    'pull': 'Tracción (espalda/bíceps)',
    'legs': 'Piernas',
    'upper': 'Tren superior completo',
    'lower': 'Tren inferior completo',
  };

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      final list = await ExerciseService().getExercises();
      final profile = userId == null
          ? null
          : await ProfileService().getProfile(userId);
      final showCardio = profile?.cardioEnabled ?? false;
      final showStretch = profile?.stretchingEnabled ?? false;
      final filtered = list.where((e) {
        if (e.muscleGroup == 'cardio') return showCardio;
        if (e.muscleGroup == 'estiramiento') return showStretch;
        return true;
      }).toList();
      if (mounted) setState(() => _catalog = filtered);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cargar catálogo: $e')),
        );
      }
    }
  }

  // ── Mutaciones ───────────────────────────────────────────────────────────

  void _addDay() {
    if (_days.length >= 6) return;
    final n = _days.length + 1;
    setState(
      () => _days.add(
        RoutineDay(
          dayNumber: n,
          name: 'Día $n',
          focus: 'push',
          exercises: const [],
        ),
      ),
    );
  }

  void _removeDay(int idx) {
    setState(() {
      _days.removeAt(idx);
      // Renumera
      for (var i = 0; i < _days.length; i++) {
        _days[i] = _copyDay(_days[i], dayNumber: i + 1);
      }
    });
  }

  void _updateDay(
    int idx, {
    String? name,
    String? focus,
    List<RoutineExercise>? exercises,
  }) {
    setState(() {
      _days[idx] = _copyDay(
        _days[idx],
        name: name,
        focus: focus,
        exercises: exercises,
      );
    });
  }

  RoutineDay _copyDay(
    RoutineDay d, {
    int? dayNumber,
    String? name,
    String? focus,
    List<RoutineExercise>? exercises,
  }) => RoutineDay(
    dayNumber: dayNumber ?? d.dayNumber,
    name: name ?? d.name,
    focus: focus ?? d.focus,
    exercises: exercises ?? d.exercises,
  );

  void _addExerciseToDay(int dayIdx, Exercise ex) {
    final current = List<RoutineExercise>.from(_days[dayIdx].exercises);
    if (current.any((e) => e.exerciseId == ex.id)) return;
    current.add(
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
    _updateDay(dayIdx, exercises: current);
  }

  void _removeExerciseFromDay(int dayIdx, int exIdx) {
    final current = List<RoutineExercise>.from(_days[dayIdx].exercises)
      ..removeAt(exIdx);
    _updateDay(dayIdx, exercises: current);
  }

  // ── Sheet de selección de ejercicios agrupados por músculo ──────────────

  Future<void> _showExercisePicker(int dayIdx) async {
    if (_catalog == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Catálogo aún no cargado')));
      return;
    }
    final existing = _days[dayIdx].exercises.map((e) => e.exerciseId).toSet();
    final byGroupMap = <String, List<Exercise>>{};
    for (final e in _catalog!) {
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
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, controller) => StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            void addAndRefresh(Exercise ex) {
              _addExerciseToDay(dayIdx, ex);
              setSheetState(() {}); // refresca el sheet para marcar el check
            }

            Future<void> createAndPick() async {
              final created = await showCreateExerciseDialog(sheetCtx);
              if (created == null) return;
              try {
                final saved = await ExerciseService().createExercise(created);
                _catalog = [...?_catalog, saved];
                byGroupMap.putIfAbsent(saved.muscleGroup, () => []).add(saved);
                groups
                  ..clear()
                  ..addAll([
                    for (final g in muscleGroupOrder)
                      if ((byGroupMap[g] ?? []).isNotEmpty) g,
                  ]);
                existing.add(saved.id);
                addAndRefresh(saved);
              } catch (e) {
                if (sheetCtx.mounted) {
                  ScaffoldMessenger.of(sheetCtx).showSnackBar(
                    SnackBar(
                      content: Text('No se pudo crear el ejercicio: $e'),
                    ),
                  );
                }
              }
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      if (selectedGroup != null)
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () =>
                              setSheetState(() => selectedGroup = null),
                        ),
                      Expanded(
                        child: Text(
                          selectedGroup == null
                              ? 'Grupo muscular — ${_days[dayIdx].name}'
                              : '${muscleGroupLabels[selectedGroup] ?? selectedGroup!} — ${_days[dayIdx].name}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        child: const Text('Listo'),
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
                            ListTile(
                              leading: const Icon(
                                Icons.add_circle_outline,
                                color: Colors.blue,
                              ),
                              title: const Text('Crear mi propio ejercicio'),
                              subtitle: const Text(
                                'Se guarda en "Mis ejercicios"',
                              ),
                              onTap: createAndPick,
                            ),
                            const Divider(height: 1),
                            for (final g in groups)
                              ListTile(
                                title: Text(muscleGroupLabels[g] ?? g),
                                subtitle: Text(
                                  '${byGroupMap[g]!.length} ejercicio(s)',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () =>
                                    setSheetState(() => selectedGroup = g),
                              ),
                          ],
                        )
                      : ListView(
                          controller: controller,
                          children: [
                            for (final ex in byGroupMap[selectedGroup]!)
                              ListTile(
                                dense: true,
                                title: Text(ex.name),
                                subtitle: Text(
                                  '${ex.defaultSets}×${ex.defaultRepsMin}-${ex.defaultRepsMax} · ${ex.restSeconds}s',
                                ),
                                trailing: existing.contains(ex.id)
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.green,
                                      )
                                    : const Icon(Icons.add_circle_outline),
                                onTap: existing.contains(ex.id)
                                    ? null
                                    : () {
                                        existing.add(ex.id);
                                        addAndRefresh(ex);
                                      },
                              ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Editar nombre del día ───────────────────────────────────────────────

  Future<void> _editDayName(int idx) async {
    final ctrl = TextEditingController(text: _days[idx].name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nombre del día'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ej: Día de pecho'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) _updateDay(idx, name: result);
  }

  // ── Activar (guardar) ────────────────────────────────────────────────────

  Future<void> _activate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ponle un nombre a tu rutina')),
      );
      return;
    }
    if (_days.any((d) => d.exercises.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cada día debe tener al menos 1 ejercicio'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    bool saved = false;
    try {
      final routine = Routine(
        userId: user.uid,
        type: 'Custom',
        name: _nameCtrl.text.trim(),
        weekNumber: 1,
        createdAt: DateTime.now(),
        days: _days,
      );
      final hydrated = await RoutineService().hydrateWithPRs(routine);
      await RoutineService().saveRoutine(hydrated);
      saved = true;
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    }

    if (saved && mounted) Navigator.pop(context, true);
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rutina personalizada'),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : TextButton(onPressed: _activate, child: const Text('Activar')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nombre de la rutina',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Días (${_days.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _days.length >= 6 ? null : _addDay,
                icon: const Icon(Icons.add),
                label: const Text('Agregar día'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          for (var i = 0; i < _days.length; i++)
            _DayBuilderCard(
              key: ValueKey(
                'day_${_days[i].dayNumber}_${_days[i].exercises.length}',
              ),
              day: _days[i],
              focusOptions: _focusLabels,
              onEditName: () => _editDayName(i),
              onChangeFocus: (f) => _updateDay(i, focus: f),
              onAddExercise: () => _showExercisePicker(i),
              onRemoveExercise: (exIdx) => _removeExerciseFromDay(i, exIdx),
              onRemoveDay: _days.length > 1 ? () => _removeDay(i) : null,
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//   Card de día en construcción
// ═══════════════════════════════════════════════════════════════════════════

class _DayBuilderCard extends StatelessWidget {
  final RoutineDay day;
  final Map<String, String> focusOptions;
  final VoidCallback onEditName;
  final ValueChanged<String> onChangeFocus;
  final VoidCallback onAddExercise;
  final ValueChanged<int> onRemoveExercise;
  final VoidCallback? onRemoveDay;

  const _DayBuilderCard({
    super.key,
    required this.day,
    required this.focusOptions,
    required this.onEditName,
    required this.onChangeFocus,
    required this.onAddExercise,
    required this.onRemoveExercise,
    required this.onRemoveDay,
  });

  @override
  Widget build(BuildContext context) {
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
                  child: GestureDetector(
                    onTap: onEditName,
                    child: Row(
                      children: [
                        Text(
                          'Día ${day.dayNumber} · ${day.name}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.edit, size: 14, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                if (onRemoveDay != null)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    onPressed: onRemoveDay,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<String>(
              initialValue: day.focus,
              decoration: const InputDecoration(
                labelText: 'Enfoque',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: [
                for (final entry in focusOptions.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (v) {
                if (v != null) onChangeFocus(v);
              },
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),

          if (day.exercises.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Sin ejercicios. Toca "Agregar" abajo.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            for (var i = 0; i < day.exercises.length; i++)
              ListTile(
                dense: true,
                title: Text(day.exercises[i].name),
                subtitle: Text(
                  '${day.exercises[i].sets}×${day.exercises[i].repsMin}-${day.exercises[i].repsMax}'
                  ' · ${day.exercises[i].restSeconds}s',
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                  onPressed: () => onRemoveExercise(i),
                ),
              ),

          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: onAddExercise,
                icon: const Icon(Icons.add),
                label: const Text('Agregar ejercicio'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
