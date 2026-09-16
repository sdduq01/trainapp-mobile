import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/workout_session.dart';
import '../services/session_service.dart';

class HistoryPage extends StatefulWidget {
  /// uid del atleta cuyo historial se quiere ver. Si es null, se muestra el
  /// del usuario actual (uso normal, no entrenador).
  final String? athleteUid;
  /// Texto para identificar de quién es el historial (ej. su email),
  /// mostrado en el título cuando lo abre un entrenador.
  final String? athleteLabel;

  const HistoryPage({this.athleteUid, this.athleteLabel, super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late final _userId =
      widget.athleteUid ?? FirebaseAuth.instance.currentUser!.uid;

  // Nº de semanas recientes (con datos) que se muestran en el resumen.
  static const int _summaryWeeks = 4;

  List<WorkoutSession>? _sessions;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sessions = await SessionService().getSessionsForUser(_userId);
    if (mounted) setState(() => _sessions = sessions);
  }

  static String _formatDate(DateTime d) {
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]}';
  }

  static String _trimDouble(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  static DateTime _mondayOf(DateTime d) {
    final date = DateTime(d.year, d.month, d.day);
    return date.subtract(Duration(days: date.weekday - 1));
  }

  List<_WeekSummary> _buildWeeklySummaries(List<WorkoutSession> sessions) {
    final buckets = <DateTime, List<WorkoutSession>>{};
    for (final s in sessions) {
      final monday = _mondayOf(s.date);
      buckets.putIfAbsent(monday, () => []).add(s);
    }
    final weeks = buckets.entries.map((e) {
      final weekSessions = e.value..sort((a, b) => a.date.compareTo(b.date));
      return _WeekSummary(
        weekStart: e.key,
        weekEnd: e.key.add(const Duration(days: 6)),
        sessions: weekSessions,
      );
    }).toList()
      ..sort((a, b) => b.weekStart.compareTo(a.weekStart));
    return weeks.take(_summaryWeeks).toList();
  }

  List<_HistoryRow> _buildRows(List<WorkoutSession> sessions) {
    final rows = <_HistoryRow>[];
    for (final session in sessions) {
      for (final exercise in session.exercises) {
        for (final set in exercise.sets) {
          rows.add(_HistoryRow(
            date: session.date,
            dayName: session.dayName,
            exerciseName: exercise.name,
            setNumber: set.setNumber,
            repsDone: set.repsDone,
            weight: set.weight,
            weightUnit: set.weightUnit,
          ));
        }
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _sessions;
    final title = widget.athleteLabel != null
        ? 'Historial de ${widget.athleteLabel}'
        : 'Historial';

    if (sessions == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (sessions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: Text('No hay sesiones registradas aún.')),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Resumen'),
              Tab(text: 'Detalle'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildSummary(_buildWeeklySummaries(sessions)),
            _buildTable(_buildRows(sessions)),
          ],
        ),
      ),
    );
  }

  // ── Tab: resumen semanal ──────────────────────────────────

  Widget _buildSummary(List<_WeekSummary> weeks) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: weeks.length,
      itemBuilder: (_, i) => _WeekSummaryCard(
        week: weeks[i],
        formatDate: _formatDate,
        trimDouble: _trimDouble,
      ),
    );
  }

  // ── Tab: tabla detallada ──────────────────────────────────

  Widget _buildTable(List<_HistoryRow> rows) {
    final colorScheme = Theme.of(context).colorScheme;

    // Colorea filas alternando por sesión (cambio de fecha+día)
    String? lastKey;
    int sessionIdx = 0;
    final sessionIndices = rows.map((row) {
      final key = '${row.date.year}-${row.date.dayOfYear}-${row.dayName}';
      if (key != lastKey) { lastKey = key; sessionIdx++; }
      return sessionIdx;
    }).toList();

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(
            colorScheme.primaryContainer,
          ),
          dividerThickness: 0.5,
          columnSpacing: 20,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 40,
          headingTextStyle: const TextStyle(fontWeight: FontWeight.bold),
          columns: const [
            DataColumn(label: Text('Fecha')),
            DataColumn(label: Text('Día')),
            DataColumn(label: Text('Ejercicio')),
            DataColumn(label: Text('Serie'), numeric: true),
            DataColumn(label: Text('Reps'), numeric: true),
            DataColumn(label: Text('Peso'), numeric: true),
          ],
          rows: List.generate(rows.length, (i) {
            final row = rows[i];
            final isOdd = sessionIndices[i] % 2 == 1;
            return DataRow(
              color: WidgetStatePropertyAll(
                isOdd
                    ? Colors.transparent
                    : colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.35),
              ),
              cells: [
                DataCell(Text(_formatDate(row.date),
                    style: const TextStyle(fontSize: 13))),
                DataCell(Text(row.dayName,
                    style: const TextStyle(fontSize: 13))),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      row.exerciseName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                DataCell(Text('${row.setNumber}')),
                DataCell(Text('${row.repsDone}')),
                DataCell(Text(
                  row.weight > 0
                      ? '${row.weight} ${row.weightUnit}'
                      : '—',
                )),
              ],
            );
          }),
        ),
      ),
    );
  }
}

// ── Modelo de resumen semanal ─────────────────────────────────

class _WeekSummary {
  final DateTime weekStart;
  final DateTime weekEnd;
  final List<WorkoutSession> sessions;

  _WeekSummary({
    required this.weekStart,
    required this.weekEnd,
    required this.sessions,
  });

  int get sessionCount => sessions.length;

  int get totalSets {
    var n = 0;
    for (final s in sessions) {
      for (final ex in s.exercises) {
        n += ex.sets.length;
      }
    }
    return n;
  }

  /// Volumen (peso × reps) sumado por unidad — no se mezclan kg/lbs, y se
  /// ignoran ejercicios en 'unidades' (bandas/máquinas sin peso real).
  Map<String, double> get volumeByUnit {
    final map = <String, double>{};
    for (final s in sessions) {
      for (final ex in s.exercises) {
        for (final set in ex.sets) {
          if (set.weight <= 0 || set.weightUnit == 'unidades') continue;
          map[set.weightUnit] =
              (map[set.weightUnit] ?? 0) + set.weight * set.repsDone;
        }
      }
    }
    return map;
  }

  List<String> get exerciseNames {
    final seen = <String>{};
    final names = <String>[];
    for (final s in sessions) {
      for (final ex in s.exercises) {
        if (seen.add(ex.exerciseId)) names.add(ex.name);
      }
    }
    return names;
  }
}

class _WeekSummaryCard extends StatelessWidget {
  final _WeekSummary week;
  final String Function(DateTime) formatDate;
  final String Function(double) trimDouble;

  const _WeekSummaryCard({
    required this.week,
    required this.formatDate,
    required this.trimDouble,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final volume = week.volumeByUnit;
    final names = week.exerciseNames;
    const maxChips = 6;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Semana del ${formatDate(week.weekStart)} '
                    'al ${formatDate(week.weekEnd)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    week.sessionCount == 1
                        ? '1 sesión'
                        : '${week.sessionCount} sesiones',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatChip(
                  icon: Icons.repeat,
                  label: '${week.totalSets} series',
                ),
                for (final entry in volume.entries)
                  _StatChip(
                    icon: Icons.fitness_center,
                    label: '${trimDouble(entry.value)} ${entry.key}',
                  ),
              ],
            ),
            if (names.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final name in names.take(maxChips))
                    _ExerciseChip(name: name),
                  if (names.length > maxChips)
                    _ExerciseChip(label: '+${names.length - maxChips}'),
                ],
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            for (final session in week.sessions.reversed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(
                        formatDate(session.date),
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        session.dayName,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      '${session.exercises.length} ejerc. · '
                      '${session.exercises.fold(0, (n, e) => n + e.sets.length)} series',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ExerciseChip extends StatelessWidget {
  final String? name;
  final String? label;

  const _ExerciseChip({this.name, this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label ?? name!,
        style: const TextStyle(fontSize: 11),
      ),
    );
  }
}

class _HistoryRow {
  final DateTime date;
  final String dayName;
  final String exerciseName;
  final int setNumber;
  final int repsDone;
  final double weight;
  final String weightUnit;

  const _HistoryRow({
    required this.date,
    required this.dayName,
    required this.exerciseName,
    required this.setNumber,
    required this.repsDone,
    required this.weight,
    required this.weightUnit,
  });
}

extension on DateTime {
  int get dayOfYear =>
      difference(DateTime(year, 1, 1)).inDays;
}
