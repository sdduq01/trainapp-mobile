import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../profile/profile_service.dart';
import '../data/muscle_groups.dart';
import '../models/exercise.dart';
import '../services/exercise_service.dart';
import 'create_exercise_dialog.dart';

/// Carga el catálogo de ejercicios (filtrado por los toggles de
/// cardio/estiramiento del perfil) y muestra el sheet de selección en dos
/// pasos (grupo muscular → ejercicio). Devuelve el [Exercise] elegido, o
/// `null` si se canceló o hubo un error al cargar (mostrando un SnackBar).
///
/// Compartido entre la edición de rutina completa (`EditRoutinePage`) y la
/// edición de ejercicios restantes desde una sesión activa
/// (`WorkoutSessionPage`).
Future<Exercise?> showAddExerciseSheet(
  BuildContext context, {
  required String dayLabel,
  required Set<String> existingExerciseIds,
}) async {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  List<Exercise>? catalog;
  String? error;
  try {
    final list = await ExerciseService().getExercisesWithCustom(userId);
    final profile = userId == null
        ? null
        : await ProfileService().getProfile(userId);
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

  if (!context.mounted) return null;

  if (error != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No se pudieron cargar ejercicios: $error')),
    );
    return null;
  }

  final byGroupMap = <String, List<Exercise>>{};
  for (final e in catalog!) {
    byGroupMap.putIfAbsent(e.muscleGroup, () => []).add(e);
  }
  List<String> groups = [
    for (final g in muscleGroupOrder)
      if ((byGroupMap[g] ?? []).isNotEmpty) g,
  ];

  // Grupo seleccionado dentro del sheet (null = mostrando la lista de grupos).
  // Vive fuera de los builders para persistir entre setSheetState.
  String? selectedGroup;

  return showModalBottomSheet<Exercise>(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, controller) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          Future<void> confirmDelete(Exercise ex) async {
            if (userId == null) return;
            final ok = await showDialog<bool>(
              context: sheetCtx,
              builder: (dctx) => AlertDialog(
                title: const Text('¿Eliminar ejercicio?'),
                content: Text(
                  '"${ex.name}" se borrará de Mis ejercicios. Las rutinas que '
                  'ya lo usan no se ven afectadas.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dctx, false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => Navigator.pop(dctx, true),
                    child: const Text('Eliminar'),
                  ),
                ],
              ),
            );
            if (ok != true) return;
            try {
              await ExerciseService().deleteCustomExercise(userId, ex.id);
              byGroupMap[kCustomExerciseGroup]?.removeWhere((e) => e.id == ex.id);
              catalog?.removeWhere((e) => e.id == ex.id);
              final stillHas =
                  (byGroupMap[kCustomExerciseGroup] ?? []).isNotEmpty;
              setSheetState(() {
                if (!stillHas) {
                  byGroupMap.remove(kCustomExerciseGroup);
                  groups = [
                    for (final g in muscleGroupOrder)
                      if ((byGroupMap[g] ?? []).isNotEmpty) g,
                  ];
                  selectedGroup = null;
                }
              });
            } catch (e) {
              if (sheetCtx.mounted) {
                ScaffoldMessenger.of(sheetCtx).showSnackBar(
                  SnackBar(content: Text('No se pudo eliminar: $e')),
                );
              }
            }
          }

          Future<void> createAndPick() async {
            if (userId == null) {
              ScaffoldMessenger.of(sheetCtx).showSnackBar(
                const SnackBar(
                  content: Text('Inicia sesión para crear ejercicios propios'),
                ),
              );
              return;
            }
            final created = await showCreateExerciseDialog(sheetCtx);
            if (created == null) return;
            try {
              final saved =
                  await ExerciseService().createCustomExercise(userId, created);
              if (sheetCtx.mounted) Navigator.pop(sheetCtx, saved);
            } catch (e) {
              if (sheetCtx.mounted) {
                ScaffoldMessenger.of(sheetCtx).showSnackBar(
                  SnackBar(content: Text('No se pudo crear el ejercicio: $e')),
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
                            ? 'Grupo muscular — $dayLabel'
                            : '${muscleGroupLabels[selectedGroup] ?? selectedGroup!} — $dayLabel',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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
                    : ListView.builder(
                        controller: controller,
                        itemCount: byGroupMap[selectedGroup]!.length,
                        itemBuilder: (_, i) {
                          final ex = byGroupMap[selectedGroup]![i];
                          final alreadyAdded = existingExerciseIds.contains(
                            ex.id,
                          );
                          final isCustom =
                              selectedGroup == kCustomExerciseGroup;
                          return ListTile(
                            title: Text(ex.name),
                            subtitle: Text(
                              '${ex.defaultSets}×${ex.defaultRepsMin}-${ex.defaultRepsMax} · ${ex.restSeconds}s',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isCustom && userId != null)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    tooltip: 'Eliminar',
                                    onPressed: () => confirmDelete(ex),
                                  ),
                                alreadyAdded
                                    ? const Icon(Icons.check,
                                        color: Colors.green)
                                    : const Icon(Icons.add),
                              ],
                            ),
                            enabled: !alreadyAdded,
                            onTap: alreadyAdded
                                ? null
                                : () => Navigator.pop(context, ex),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
