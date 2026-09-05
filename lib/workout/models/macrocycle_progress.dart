import '../data/macrocycle_forjado.dart';

/// Estado del macro ciclo activo del usuario — doc `macrocycles/{uid}`.
///
/// La definición de fases y de cada Día 4 vive en [ForjadoPorElHierro]; este
/// doc solo guarda el avance: en qué fase va y cuántas sesiones de cada día
/// lleva registradas en esa fase.
class MacrocycleProgress {
  final String templateId;
  final String name;
  final int phaseIndex; // 0-based
  final Map<int, int> phaseCounts; // dayNumber -> sesiones completas en la fase
  final DateTime startedAt;
  final bool completed;
  final DateTime? completedAt;

  /// Anti-trampa: fecha local (YYYY-MM-DD) y nº de sesiones que ya contaron
  /// para la forja ese día. Tope diario en [ForjadoPorElHierro.maxCountedSessionsPerDay].
  final String? countedDate;
  final int countedToday;

  const MacrocycleProgress({
    required this.templateId,
    required this.name,
    required this.phaseIndex,
    required this.phaseCounts,
    required this.startedAt,
    required this.completed,
    this.completedAt,
    this.countedDate,
    this.countedToday = 0,
  });

  factory MacrocycleProgress.initial() => MacrocycleProgress(
    templateId: ForjadoPorElHierro.templateId,
    name: ForjadoPorElHierro.routineName,
    phaseIndex: 0,
    phaseCounts: {for (final d in ForjadoPorElHierro.trackedDays) d: 0},
    startedAt: DateTime.now(),
    completed: false,
  );

  int get currentPhaseNumber => phaseIndex + 1;
  int get totalPhases => ForjadoPorElHierro.totalPhases;
  String get currentEmphasis => ForjadoPorElHierro.emphases[phaseIndex];
  int countFor(int day) => phaseCounts[day] ?? 0;

  int get sessionsThisPhase => phaseCounts.values.fold(0, (a, b) => a + b);
  int get sessionsGoalPerPhase => ForjadoPorElHierro.sessionsPerPhase;
  int get totalSessionsDone =>
      phaseIndex * sessionsGoalPerPhase + sessionsThisPhase;
  int get totalSessionsGoal => ForjadoPorElHierro.totalSessions;

  Map<String, dynamic> toMap() => {
    'templateId': templateId,
    'name': name,
    'phaseIndex': phaseIndex,
    'phaseCounts': phaseCounts.map((k, v) => MapEntry('$k', v)),
    'startedAt': startedAt.toIso8601String(),
    'completed': completed,
    'completedAt': completedAt?.toIso8601String(),
    'countedDate': countedDate,
    'countedToday': countedToday,
  };

  factory MacrocycleProgress.fromMap(Map<String, dynamic> m) {
    final rawCounts = (m['phaseCounts'] as Map?) ?? const {};
    final counts = <int, int>{};
    for (final d in ForjadoPorElHierro.trackedDays) {
      counts[d] = (rawCounts['$d'] as num?)?.toInt() ?? 0;
    }
    return MacrocycleProgress(
      templateId: m['templateId'] as String? ?? ForjadoPorElHierro.templateId,
      name: m['name'] as String? ?? ForjadoPorElHierro.routineName,
      phaseIndex: (m['phaseIndex'] as num?)?.toInt() ?? 0,
      phaseCounts: counts,
      startedAt:
          DateTime.tryParse(m['startedAt'] as String? ?? '') ?? DateTime.now(),
      completed: m['completed'] as bool? ?? false,
      completedAt: m['completedAt'] != null
          ? DateTime.tryParse(m['completedAt'] as String)
          : null,
      countedDate: m['countedDate'] as String?,
      countedToday: (m['countedToday'] as num?)?.toInt() ?? 0,
    );
  }
}
