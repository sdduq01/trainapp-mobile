import '../../core/firebase/firestore_instance.dart';
import '../data/macrocycle_forjado.dart';
import '../models/macrocycle_progress.dart';
import '../models/routine.dart';

enum MacroAdvanceKind {
  /// Se registró una sesión pero la fase sigue abierta.
  progress,

  /// Se completó la fase y se pasó a la siguiente (hay [MacrocycleAdvance.newDay4]).
  phaseAdvanced,

  /// Se completó la última fase: el macro ciclo entero está terminado.
  macrocycleComplete,

  /// La sesión no contó: ya se alcanzó el tope diario
  /// ([ForjadoPorElHierro.maxCountedSessionsPerDay]) para la forja.
  dailyCapReached,
}

class MacrocycleAdvance {
  final MacroAdvanceKind kind;

  /// Fase vigente tras registrar la sesión (0-based).
  final int phaseIndex;

  /// Día 4 de la nueva fase, solo cuando [kind] es [MacroAdvanceKind.phaseAdvanced].
  final RoutineDay? newDay4;

  /// Conteo de sesiones por día de la fase vigente.
  final Map<int, int> counts;

  const MacrocycleAdvance({
    required this.kind,
    required this.phaseIndex,
    required this.counts,
    this.newDay4,
  });

  String get emphasis => ForjadoPorElHierro.emphases[phaseIndex];
}

/// Fecha local como `YYYY-MM-DD`, clave del tope diario anti-trampa.
String _dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class MacrocycleService {
  Future<MacrocycleProgress?> get(String userId) async {
    final doc = await db.collection('macrocycles').doc(userId).get();
    if (!doc.exists) return null;
    return MacrocycleProgress.fromMap(doc.data()!);
  }

  /// Arranca el macro ciclo "Forjado por el Hierro" desde la fase 1.
  Future<void> start(String userId) async {
    await db
        .collection('macrocycles')
        .doc(userId)
        .set(MacrocycleProgress.initial().toMap());
  }

  /// Descarta el macro ciclo activo (p. ej. al activar otra rutina normal).
  Future<void> abandon(String userId) async {
    await db.collection('macrocycles').doc(userId).delete();
  }

  /// Registra una sesión completa del [dayNumber] dado y evalúa si se cierra la
  /// fase o el macro ciclo entero. Devuelve `null` si no hay macro ciclo activo
  /// o si el día no cuenta para el avance. Persiste el nuevo estado.
  Future<MacrocycleAdvance?> registerCompletedSession(
    String userId,
    int dayNumber,
  ) async {
    if (!ForjadoPorElHierro.trackedDays.contains(dayNumber)) return null;

    final mc = await get(userId);
    if (mc == null || mc.completed) return null;

    final ref = db.collection('macrocycles').doc(userId);

    // Tope diario anti-trampa: como máximo N sesiones por día del calendario
    // suman a la forja.
    final today = _dayKey(DateTime.now());
    final countedToday = mc.countedDate == today ? mc.countedToday : 0;
    if (countedToday >= ForjadoPorElHierro.maxCountedSessionsPerDay) {
      return MacrocycleAdvance(
        kind: MacroAdvanceKind.dailyCapReached,
        phaseIndex: mc.phaseIndex,
        counts: {
          for (final d in ForjadoPorElHierro.trackedDays) d: mc.countFor(d),
        },
      );
    }
    final dailyFields = <String, dynamic>{
      'countedDate': today,
      'countedToday': countedToday + 1,
    };

    final counts = {
      for (final d in ForjadoPorElHierro.trackedDays) d: mc.countFor(d),
    };
    counts[dayNumber] = (counts[dayNumber] ?? 0) + 1;

    final countsMap = counts.map((k, v) => MapEntry('$k', v));

    final phaseCleared = ForjadoPorElHierro.trackedDays.every(
      (d) => (counts[d] ?? 0) >= ForjadoPorElHierro.sessionsPerDay,
    );

    if (!phaseCleared) {
      await ref.update({...dailyFields, 'phaseCounts': countsMap});
      return MacrocycleAdvance(
        kind: MacroAdvanceKind.progress,
        phaseIndex: mc.phaseIndex,
        counts: counts,
      );
    }

    final isLastPhase = mc.phaseIndex >= ForjadoPorElHierro.totalPhases - 1;
    if (isLastPhase) {
      await ref.update({
        ...dailyFields,
        'phaseCounts': countsMap,
        'completed': true,
        'completedAt': DateTime.now().toIso8601String(),
      });
      return MacrocycleAdvance(
        kind: MacroAdvanceKind.macrocycleComplete,
        phaseIndex: mc.phaseIndex,
        counts: counts,
      );
    }

    final nextPhase = mc.phaseIndex + 1;
    final reset = {for (final d in ForjadoPorElHierro.trackedDays) d: 0};
    await ref.update({
      ...dailyFields,
      'phaseIndex': nextPhase,
      'phaseCounts': reset.map((k, v) => MapEntry('$k', v)),
    });
    return MacrocycleAdvance(
      kind: MacroAdvanceKind.phaseAdvanced,
      phaseIndex: nextPhase,
      newDay4: ForjadoPorElHierro.day4ForPhase(nextPhase),
      counts: reset,
    );
  }
}
