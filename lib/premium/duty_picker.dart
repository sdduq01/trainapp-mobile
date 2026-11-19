import 'package:flutter/material.dart';

import '../workout/models/routine.dart';
import '../workout/models/routine_template.dart';
import '../workout/services/macrocycle_service.dart';
import '../workout/services/routine_service.dart';
import '../workout/services/routine_template_service.dart';
import 'free_tier.dart';

/// Las tres rutinas gratis, en el orden Light → Duty → Hard.
Future<List<RoutineTemplate>> loadFreeTemplates() async {
  final service = RoutineTemplateService();
  final found = await Future.wait([
    for (final id in [
      FreeTier.lightDutyId,
      FreeTier.dutyId,
      FreeTier.hardDutyId,
    ])
      service.getById(id),
  ]);
  return found.whereType<RoutineTemplate>().toList();
}

/// Activa la plantilla [template] como rutina de [uid] (con sus PRs) y
/// abandona el macro ciclo si había uno.
Future<Routine> activateFreeTemplate(String uid, RoutineTemplate template) async {
  final routine =
      await RoutineService().hydrateWithPRs(template.toRoutine(uid));
  await RoutineService().saveRoutine(routine);
  await MacrocycleService().abandon(uid);
  return routine;
}

/// Pide al usuario sin premium elegir una de las rutinas gratis para
/// reemplazar su rutina actual, que es premium. No se puede cerrar sin
/// elegir. Devuelve la rutina activada.
Future<Routine?> showDutyPicker(BuildContext context, String uid) {
  return showDialog<Routine>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DutyPickerDialog(uid: uid),
  );
}

class _DutyPickerDialog extends StatefulWidget {
  final String uid;
  const _DutyPickerDialog({required this.uid});

  @override
  State<_DutyPickerDialog> createState() => _DutyPickerDialogState();
}

class _DutyPickerDialogState extends State<_DutyPickerDialog> {
  late Future<List<RoutineTemplate>> _future = loadFreeTemplates();
  String? _activatingId;

  Future<void> _choose(RoutineTemplate t) async {
    setState(() => _activatingId = t.id);
    try {
      final routine = await activateFreeTemplate(widget.uid, t);
      if (mounted) Navigator.pop(context, routine);
    } catch (e) {
      if (!mounted) return;
      setState(() => _activatingId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo activar la rutina: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Elige tu rutina'),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<List<RoutineTemplate>>(
            future: _future,
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final items = snap.data ?? [];
              if (snap.hasError || items.isEmpty) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No se pudieron cargar las rutinas.'),
                    TextButton(
                      onPressed: () =>
                          setState(() => _future = loadFreeTemplates()),
                      child: const Text('Reintentar'),
                    ),
                  ],
                );
              }
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tu rutina actual es premium. Sin premium puedes '
                      'entrenar con una de las rutinas TrainApp; tus pesos '
                      'registrados se mantienen.',
                    ),
                    const SizedBox(height: 12),
                    for (final t in items)
                      Card(
                        child: ListTile(
                          title: Text(t.name),
                          subtitle: Text('${t.days.length} días por semana'),
                          trailing: _activatingId == t.id
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.chevron_right),
                          onTap: _activatingId == null ? () => _choose(t) : null,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
