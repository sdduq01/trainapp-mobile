import 'package:flutter/material.dart';
import '../data/muscle_groups.dart';
import '../models/exercise.dart';
import 'counter_field.dart';

/// Diálogo para crear un ejercicio propio desde cero, siempre catalogado
/// bajo [kCustomExerciseGroup] ("Mis ejercicios"). No lo persiste — solo
/// arma el [Exercise] (con `id` vacío, se asigna al guardarlo) y lo
/// devuelve, o `null` si se canceló.
Future<Exercise?> showCreateExerciseDialog(BuildContext context) {
  final nameCtrl = TextEditingController();
  int sets = 3;
  int repsMin = 8;
  int repsMax = 12;
  int restSeconds = 90;
  String weightUnit = 'kg';
  double progressionStep = 2.5;
  bool isIsometric = false;

  const steps = [1.0, 1.25, 2.5, 5.0, 10.0];

  return showDialog<Exercise>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('Nuevo ejercicio'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Ej: Curl concentrado con banda',
                ),
              ),
              const SizedBox(height: 20),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Isométrico (cronómetro)'),
                subtitle: const Text(
                  'Las series se miden en segundos sostenidos (ej: plancha), no en reps.',
                  style: TextStyle(fontSize: 12),
                ),
                value: isIsometric,
                onChanged: (v) => setDialogState(() => isIsometric = v),
              ),
              const SizedBox(height: 8),
              CounterField(
                label: 'Series',
                value: sets,
                min: 1, max: 8,
                onChanged: (v) => setDialogState(() => sets = v),
              ),
              const SizedBox(height: 16),
              CounterField(
                label: isIsometric ? 'Segundos mínimos' : 'Reps mínimas',
                value: repsMin,
                min: 1, max: 30,
                onChanged: (v) => setDialogState(() => repsMin = v),
              ),
              const SizedBox(height: 16),
              CounterField(
                label: isIsometric ? 'Segundos máximos' : 'Reps máximas',
                value: repsMax,
                min: 1, max: 30,
                onChanged: (v) => setDialogState(() => repsMax = v),
              ),
              const SizedBox(height: 16),
              CounterField(
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
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(
                ctx,
                Exercise(
                  id: '',
                  name: name,
                  muscle: 'custom',
                  muscleGroup: kCustomExerciseGroup,
                  defaultSets: sets,
                  defaultRepsMin: repsMin,
                  defaultRepsMax: repsMax < repsMin ? repsMin : repsMax,
                  restSeconds: restSeconds,
                  defaultWeightUnit: weightUnit,
                  defaultProgressionStep: progressionStep,
                  isIsometric: isIsometric,
                ),
              );
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    ),
  );
}

String _unitAbbrev(String unit) => switch (unit) {
      'lbs' => 'lb',
      'unidades' => 'u',
      _ => 'kg',
    };
