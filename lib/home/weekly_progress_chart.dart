import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/utils/iso_week.dart';
import '../premium/premium_widgets.dart';
import '../notifications/local_reminders.dart';
import 'streak_service.dart';

class WeeklyProgressChart extends StatefulWidget {
  final int plannedDaysPerWeek;
  final int totalRoutineExercises;

  /// Sin premium: se muestra con datos de ejemplo, difuminada y sin
  /// interacción; al tocarla explica cómo obtener el premium.
  final bool locked;

  /// Forja en curso (activa o guardada): la racha también la pone en juego.
  /// Ver [MacrocycleProgress.atStakeLabel].
  final String? forgeAtStake;

  /// Con la racha ya calculada (para revisar si la forja se enfrió sin
  /// volver a leer las sesiones).
  final void Function(StreakData data)? onLoaded;

  const WeeklyProgressChart({
    required this.plannedDaysPerWeek,
    required this.totalRoutineExercises,
    this.locked = false,
    this.forgeAtStake,
    this.onLoaded,
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
      LocalReminders.cancelStreak();
      setState(() {
        _stats = _demoStats(currentWeek, planned);
        _streak = 3;
      });
      _scrollToCurrent(currentWeek);
      return;
    }

    final data = await StreakService().load(_userId, planned, now: now);
    final records = data.weeks;
    final legacyGoal = data.legacyGoal;
    final streak = data.streak;
    // Aviso local "vas a perder tu racha" con el mismo cálculo.
    LocalReminders.updateStreak(
      uid: _userId,
      premium: true,
      streak: streak,
      current: data.current,
      forge: widget.forgeAtStake,
    );
    widget.onLoaded?.call(data);

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
        progressions: data.progressions[m] ?? 0,
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
          'momento; cambiar de rutina no modifica las semanas pasadas.\n\n'
          'Tu forja de Forjado por el Hierro, activa o guardada, vive de tu '
          'racha: si la racha se pierde, la forja se enfría y pierdes su avance.',
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
            'Tu racha está en riesgo: entrena '
            '${_daysToSave == 1 ? '1 día' : '$_daysToSave días'} más esta '
            'semana para salvarla'
            '${widget.forgeAtStake == null ? '' : ', o ${widget.forgeAtStake} se enfría'}.',
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
