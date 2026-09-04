import 'package:flutter/material.dart';
import '../models/progression_type.dart';
import '../models/routine.dart';
import 'counter_field.dart';

/// Diálogo de edición de parámetros de un [RoutineExercise] (series, reps,
/// descanso, unidad de peso, progresión). Devuelve el ejercicio actualizado
/// (conservando `exerciseId`, `name`, `currentWeight` e `isIsometric` del
/// original), o `null` si se canceló.
///
/// Compartido entre la edición de rutina completa (`EditRoutinePage`) y la
/// edición de ejercicios restantes desde una sesión activa
/// (`WorkoutSessionPage`).
Future<RoutineExercise?> showExerciseEditDialog(
  BuildContext context,
  RoutineExercise ex,
) {
  int sets = ex.sets;
  int repsMin = ex.repsMin;
  int repsMax = ex.repsMax;
  int restSeconds = ex.restSeconds;
  String weightUnit = ex.weightUnit;
  double progressionStep = ex.progressionStep;
  ProgressionType progressionType = ex.progressionType;

  const steps = [1.0, 1.25, 2.5, 5.0, 10.0];

  return showDialog<RoutineExercise>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(ex.name, style: const TextStyle(fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CounterField(
                label: 'Series',
                value: sets,
                min: 1, max: 8,
                onChanged: (v) => setDialogState(() => sets = v),
              ),
              const SizedBox(height: 16),
              CounterField(
                label: 'Reps mínimas',
                value: repsMin,
                min: 1, max: 30,
                onChanged: (v) => setDialogState(() => repsMin = v),
              ),
              const SizedBox(height: 16),
              CounterField(
                label: 'Reps máximas',
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
              Navigator.pop(
                ctx,
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
            },
            child: const Text('Guardar'),
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
