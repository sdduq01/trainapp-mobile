import '../models/progression_type.dart';
import '../models/routine.dart';

/// Objetivo sugerido para una serie específica.
class SetTarget {
  final double weight;
  final int reps;
  final int? rir;       // null cuando no aplica (none o intensidad off)
  final bool isFailure; // último set con RIR 0 + intensidad ON

  const SetTarget({
    required this.weight,
    required this.reps,
    this.rir,
    this.isFailure = false,
  });
}

class ProgressionLogic {
  /// Semana de la rutina (1-indexada) según `createdAt`. Sem 1 cubre los
  /// primeros 7 días desde la creación.
  static int weekIndexFor(Routine routine, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final days = ref.difference(routine.createdAt).inDays;
    if (days < 0) return 1;
    return (days ~/ 7) + 1;
  }

  /// True si la semana es de FALLO según la cadencia configurada (sem N, 2N…).
  static bool isFailureWeek(int weekIndex, int cadence) {
    if (cadence <= 0) return false;
    return weekIndex % cadence == 0;
  }

  /// Mapa de RIR objetivo por set para piramidal: descendente desde 3, cap en 0.
  /// 2s: [3,2] · 3s: [3,2,1] · 4s: [3,2,1,0] · 5s: [3,2,1,0,0] · …
  static List<int> pyramidRirMap(int sets) {
    return [for (var i = 0; i < sets; i++) (3 - i).clamp(0, 3)];
  }

  /// Mapa de RIR para piramidal invertida: primera mitad (ceil) RIR 1, resto 0.
  /// 2s: [1,0] · 3s: [1,1,0] · 4s: [1,1,0,0] · 5s: [1,1,1,0,0] · …
  static List<int> reversePyramidRirMap(int sets) {
    final ones = (sets + 1) ~/ 2;
    return [
      for (var i = 0; i < sets; i++) i < ones ? 1 : 0,
    ];
  }

  /// Calcula el target de una serie dada una progresión, sin mirar lo que el
  /// usuario hizo en sets anteriores (lo dinámico — set N+1 cuando el set N
  /// no llegó a repsMax — se decide al avanzar la serie en la UI).
  static SetTarget targetForSet({
    required RoutineExercise exercise,
    required int setIndex,
    required int weekIndex,
    required bool intensityEnabled,
    required int failureCadence,
  }) {
    final isLastSet = setIndex == exercise.sets - 1;

    switch (exercise.progressionType) {
      case ProgressionType.none:
        return SetTarget(
          weight: exercise.currentWeight,
          reps: exercise.repsMax,
          rir: null,
        );

      case ProgressionType.doubleLinear:
        final deload = isFailureWeek(weekIndex, failureCadence);
        final isFailureSet = deload && isLastSet;
        return SetTarget(
          weight: exercise.currentWeight,
          reps: exercise.repsMax,
          rir: intensityEnabled ? (isFailureSet ? 0 : 1) : null,
          isFailure: isFailureSet && intensityEnabled,
        );

      case ProgressionType.pyramid:
        final rirMap = pyramidRirMap(exercise.sets);
        final rir = rirMap[setIndex];
        return SetTarget(
          weight: exercise.currentWeight + setIndex * exercise.progressionStep,
          reps: exercise.repsMax,
          rir: intensityEnabled ? rir : null,
          isFailure: intensityEnabled && isLastSet && rir == 0,
        );

      case ProgressionType.reversePyramid:
        final rirMap = reversePyramidRirMap(exercise.sets);
        final rir = rirMap[setIndex];
        final reps = exercise.repsMin + setIndex;
        return SetTarget(
          weight: exercise.currentWeight - setIndex * exercise.progressionStep,
          reps: reps,
          rir: intensityEnabled ? rir : null,
          isFailure: intensityEnabled && isLastSet && rir == 0,
        );
    }
  }

  // ── Overload triggers ────────────────────────────────────────────────────

  /// Pyramid: sube currentWeight si TODOS los sets se completaron con su peso
  /// planeado (currentWeight + i·step) y al menos repsMax repeticiones.
  /// Devuelve `null` si no procede progresión.
  static double? evalPyramidOverload(
    RoutineExercise exercise,
    List<(int, double)?> logs,
  ) {
    if (logs.length < exercise.sets) return null;
    for (int i = 0; i < exercise.sets; i++) {
      final log = logs[i];
      if (log == null) return null;
      final expectedWeight =
          exercise.currentWeight + i * exercise.progressionStep;
      // Tolerancia para comparaciones de double.
      if (log.$2 + 0.001 < expectedWeight) return null;
      if (log.$1 < exercise.repsMax) return null;
    }
    return exercise.currentWeight + exercise.progressionStep;
  }

  /// Pyramid invertida: sube currentWeight si el set 1 alcanzó el peso base
  /// (currentWeight) con al menos repsMin repeticiones. Sets 2..N no influyen
  /// en el trigger (son acumulación; el set más pesado es el indicador).
  static double? evalReversePyramidOverload(
    RoutineExercise exercise,
    List<(int, double)?> logs,
  ) {
    if (logs.isEmpty) return null;
    final first = logs[0];
    if (first == null) return null;
    if (first.$2 + 0.001 < exercise.currentWeight) return null;
    if (first.$1 < exercise.repsMin) return null;
    return exercise.currentWeight + exercise.progressionStep;
  }
}
