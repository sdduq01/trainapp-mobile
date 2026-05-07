import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../workout/services/progression_service.dart';
import '../workout/services/session_service.dart';

class WeeklyProgressChart extends StatefulWidget {
  final int plannedDaysPerWeek;
  final int totalRoutineExercises;

  const WeeklyProgressChart({
    required this.plannedDaysPerWeek,
    required this.totalRoutineExercises,
    super.key,
  });

  @override
  State<WeeklyProgressChart> createState() => _WeeklyProgressChartState();
}

class _WeeklyProgressChartState extends State<WeeklyProgressChart> {
  final _userId = FirebaseAuth.instance.currentUser!.uid;
  final _scrollCtrl = ScrollController();

  List<_WeekStat>? _stats;
  int _streak = 0;

  static const double _barMaxHeight = 72;
  static const double _barWidth = 20;
  static const double _barGap = 5;
  static const double _itemWidth = _barWidth + _barGap;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // Semana del año basada en días transcurridos desde el 1 de enero
  static int _weekNumber(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    return (date.difference(startOfYear).inDays / 7).floor() + 1;
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentWeek = _weekNumber(now);
    final planned = widget.plannedDaysPerWeek;

    final sessions = await SessionService().getSessionsForUser(_userId);
    Map<int, int> progressionsByWeek = {};
    try {
      progressionsByWeek =
          await ProgressionService().getProgressionsByWeek(_userId, currentYear);
    } catch (_) {
      // Colección aún sin reglas o sin datos — el chart carga igual sin progresos
    }

    // Agrupar sesiones por semana (solo año actual)
    final Map<int, int> byWeek = {};
    for (final s in sessions) {
      if (s.date.year == currentYear) {
        final w = _weekNumber(s.date);
        byWeek[w] = (byWeek[w] ?? 0) + 1;
      }
    }

    final stats = List.generate(
      currentWeek,
      (i) => _WeekStat(
        week: i + 1,
        done: byWeek[i + 1] ?? 0,
        planned: planned,
        progressions: progressionsByWeek[i + 1] ?? 0,
      ),
    );

    // Racha: semanas completas consecutivas hacia atrás
    // La semana actual incompleta no corta la racha
    int streak = 0;
    for (int i = stats.length - 1; i >= 0; i--) {
      final s = stats[i];
      if (s.done >= s.planned) {
        streak++;
      } else if (s.week != currentWeek) {
        break;
      }
    }

    if (!mounted) return;
    setState(() {
      _stats = stats;
      _streak = streak;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      final target = (currentWeek - 5) * _itemWidth;
      _scrollCtrl.animateTo(
        target.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStreakHeader(),
        const SizedBox(height: 4),
        Text(
          'Consistencia ${DateTime.now().year}',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        _buildChart(),
        const SizedBox(height: 8),
        _buildLegend(),
      ],
    );
  }

  Widget _buildStreakHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text('🔥', style: TextStyle(fontSize: 26)),
        const SizedBox(width: 10),
        RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(context).style,
            children: [
              TextSpan(
                text: '$_streak ',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text: _streak == 1 ? 'semana' : 'semanas',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              TextSpan(
                text: ' de racha',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChart() {
    if (_stats == null) {
      return const SizedBox(
        height: _barMaxHeight + 32,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final currentWeek = _weekNumber(DateTime.now());
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: _barMaxHeight + 32,
      child: ListView.builder(
        controller: _scrollCtrl,
        scrollDirection: Axis.horizontal,
        itemCount: _stats!.length,
        itemBuilder: (ctx, i) {
          final stat = _stats![i];
          final isCurrentWeek = stat.week == currentWeek;
          final ratio = stat.planned > 0
              ? (stat.done / stat.planned).clamp(0.0, 1.0)
              : 0.0;
          final barHeight = stat.done == 0
              ? 4.0
              : (ratio * _barMaxHeight).clamp(4.0, _barMaxHeight);

          final Color barColor;
          if (stat.done == 0) {
            barColor = Colors.grey.shade300;
          } else if (ratio >= 0.75) {
            barColor = Colors.green;
          } else if (ratio >= 0.50) {
            barColor = Colors.amber;
          } else {
            barColor = Colors.red.shade400;
          }

          final isProgressionWeek =
              stat.progressions > widget.totalRoutineExercises * 0.3;
          final Border? border;
          if (isProgressionWeek) {
            border = Border.all(color: const Color(0xFFFFD700), width: 2.5);
          } else if (isCurrentWeek) {
            border = Border.all(color: colorScheme.primary, width: 2);
          } else {
            border = null;
          }

          return Padding(
            padding: const EdgeInsets.only(right: _barGap),
            child: SizedBox(
              width: _barWidth,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (isProgressionWeek) ...[
                    const Text('⚡', style: TextStyle(fontSize: 9)),
                  ] else if (stat.done > 0) ...[
                    Text(
                      '${stat.done}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: barColor,
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  // Barra
                  Container(
                    width: _barWidth,
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(4),
                      border: border,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Número de semana
                  Text(
                    '${stat.week}',
                    style: TextStyle(
                      fontSize: 9,
                      color: isCurrentWeek ? colorScheme.primary : Colors.grey[400],
                      fontWeight:
                          isCurrentWeek ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLegend() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _LegendDot(color: Colors.green, label: '≥75%'),
            const SizedBox(width: 12),
            _LegendDot(color: Colors.amber, label: '≥50%'),
            const SizedBox(width: 12),
            _LegendDot(color: Colors.red.shade400, label: '<50%'),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFFFD700), width: 2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '>30% de ejercicios con progresión',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }
}

class _WeekStat {
  final int week;
  final int done;
  final int planned;
  final int progressions;

  const _WeekStat({
    required this.week,
    required this.done,
    required this.planned,
    this.progressions = 0,
  });
}
