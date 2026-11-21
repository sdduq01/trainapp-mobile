import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart' show SetOptions;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/firebase/firestore_instance.dart';
import '../core/utils/iso_week.dart';
import '../premium/premium_widgets.dart';
import '../workout/models/workout_session.dart';
import '../workout/services/progression_service.dart';
import '../workout/services/session_service.dart';
import 'streak.dart';

class WeeklyProgressChart extends StatefulWidget {
  final int plannedDaysPerWeek;
  final int totalRoutineExercises;

  /// Sin premium: se muestra con datos de ejemplo, difuminada y sin
  /// interacción; al tocarla explica cómo obtener el premium.
  final bool locked;

  const WeeklyProgressChart({
    required this.plannedDaysPerWeek,
    required this.totalRoutineExercises,
    this.locked = false,
    super.key,
  });

  @override
  State<WeeklyProgressChart> createState() => _WeeklyProgressChartState();
}

class _WeeklyProgressChartState extends State<WeeklyProgressChart> {
  late final _userId = FirebaseAuth.instance.currentUser!.uid;
  final _scrollCtrl = ScrollController();

  List<_WeekStat>? _stats;
  int _streak = 0;
  // Días que faltan esta semana para salvar la racha en riesgo (0 = no lo está).
  int _daysToSave = 0;

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

  static int _weekNumber(DateTime date) => IsoWeek.weekNumber(date);

  static int _isoYear(DateTime date) => IsoWeek.year(date);

  static DateTime _mondayOf(DateTime date) =>
      DateTime(date.year, date.month, date.day - (date.weekday - 1));

  /// Objetivo de las sesiones anteriores a `plannedDays`: los días de la
  /// rutina activa la primera vez que se calcula, guardado en el perfil para
  /// que un cambio de rutina posterior no reescriba esas semanas.
  Future<int> _legacyGoal(List<WorkoutSession> sessions, int planned) async {
    if (sessions.every((s) => s.plannedDays != null)) return planned;
    final ref = db.collection('profiles').doc(_userId);
    try {
      final saved = (await ref.get()).data()?['streakLegacyGoal'];
      if (saved is int) return saved;
      await ref.set({'streakLegacyGoal': planned}, SetOptions(merge: true));
    } catch (_) {
      // Sin red: se usa la rutina actual y se guarda en otra ocasión.
    }
    return planned;
  }

  /// Datos de ejemplo para la vista bloqueada: no consulta nada del usuario.
  static List<_WeekStat> _demoStats(int currentWeek, int planned) {
    const pattern = [1.0, 0.75, 1.0, 1.0, 0.5, 1.0, 0.75, 1.0];
    const progs = [2, 1, 3, 2, 0, 4, 1, 3];
    return List.generate(currentWeek, (i) {
      final k = i % pattern.length;
      return _WeekStat(
        week: i + 1,
        done: (planned * pattern[k]).round(),
        planned: planned,
        progressions: progs[k],
      );
    });
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final currentYear = _isoYear(now);
    final currentWeek = _weekNumber(now);
    final planned = widget.plannedDaysPerWeek;

    if (widget.locked) {
      setState(() {
        _stats = _demoStats(currentWeek, planned);
        _streak = 3;
      });
      _scrollToCurrent(currentWeek);
      return;
    }

    List<WorkoutSession> sessions = const [];
    try {
      sessions = await SessionService().getSessionsForUser(_userId);
    } catch (_) {
      // Sin permisos o sin red: el chart carga igual (vacío) en vez de
      // quedarse girando para siempre.
    }
    Map<int, int> progressionsByWeek = {};
    try {
      progressionsByWeek =
          await ProgressionService().getProgressionsByWeek(_userId, currentYear);
    } catch (_) {
      // Colección aún sin reglas o sin datos — el chart carga igual sin progresos
    }
    final legacyGoal = await _legacyGoal(sessions, planned);

    // Semanas desde la primera sesión hasta la actual (cruzando años, para
    // que la racha no se reinicie en enero), con el objetivo que tenía la
    // rutina en cada una: el de su primera sesión que lo guarde; si no
    // tiene, el de la semana anterior. La semana en curso sin sesiones con
    // objetivo usa la rutina actual.
    final thisMonday = _mondayOf(now);
    final byMonday = <DateTime, List<WorkoutSession>>{};
    for (final s in sessions) {
      byMonday.putIfAbsent(_mondayOf(s.date), () => []).add(s);
    }
    var monday = byMonday.keys.fold<DateTime>(
        thisMonday, (min, m) => m.isBefore(min) ? m : min);
    final records = <DateTime, WeekRecord>{};
    var goal = legacyGoal;
    while (!monday.isAfter(thisMonday)) {
      final week = byMonday[monday] ?? const <WorkoutSession>[];
      final stamped = week.where((s) => s.plannedDays != null).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      if (stamped.isNotEmpty) {
        goal = stamped.first.plannedDays!;
      } else if (monday == thisMonday) {
        goal = planned;
      }
      records[monday] = WeekRecord(done: week.length, planned: goal);
      monday = DateTime(monday.year, monday.month, monday.day + 7);
    }
    final streak = Streak.compute(records.values.toList());

    // La gráfica muestra las semanas del año en curso.
    final firstMonday = IsoWeek.firstMonday(currentYear);
    final stats = List.generate(currentWeek, (i) {
      final m = DateTime(
          firstMonday.year, firstMonday.month, firstMonday.day + 7 * i);
      final r = records[m];
      return _WeekStat(
        week: i + 1,
        done: r?.done ?? 0,
        planned: r?.planned ?? legacyGoal,
        progressions: progressionsByWeek[i + 1] ?? 0,
      );
    });

    if (!mounted) return;
    setState(() {
      _stats = stats;
      _streak = streak.weeks;
      _daysToSave = streak.atRisk ? streak.daysToSave : 0;
    });

    _scrollToCurrent(currentWeek);
  }

  void _scrollToCurrent(int currentWeek) {
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
    final chart = _buildContent(context);
    if (!widget.locked) return chart;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () =>
          showPremiumRequired(context, feature: 'El progreso semanal'),
      child: Stack(
        alignment: Alignment.center,
        children: [
          IgnorePointer(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
              child: Opacity(opacity: 0.6, child: chart),
            ),
          ),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PremiumBadge(),
                  const SizedBox(height: 6),
                  Text(
                    'Tu consistencia y progresión\nsemana a semana',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
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

  void _showStreakRules() {
    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('¿Cómo funciona la racha?'),
        content: const Text(
          'Cada semana cuenta para tu racha si entrenas al menos los días de '
          'tu rutina menos uno.\n\n'
          'Si una semana te faltan dos días, la racha queda en riesgo: la '
          'salvas cumpliendo todos los días de tu rutina la semana '
          'siguiente.\n\n'
          'El objetivo de cada semana es el de la rutina que tenías en ese '
          'momento; cambiar de rutina no modifica las semanas pasadas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            _buildStreakCount(),
            IconButton(
              icon: Icon(Icons.info_outline, size: 18, color: Colors.grey[500]),
              tooltip: '¿Cómo funciona la racha?',
              visualDensity: VisualDensity.compact,
              onPressed: widget.locked ? null : _showStreakRules,
            ),
          ],
        ),
        if (_daysToSave > 0)
          Text(
            _daysToSave == 1
                ? 'Tu racha está en riesgo: entrena 1 día más esta semana '
                    'para salvarla.'
                : 'Tu racha está en riesgo: entrena $_daysToSave días más '
                    'esta semana para salvarla.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.orange[800],
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  Widget _buildStreakCount() {
    return RichText(
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
