import 'package:flutter/material.dart';

/// Un paso del tutorial: resalta el widget de [target] y explica qué hace.
class CoachMarkStep {
  final GlobalKey target;
  final String title;
  final String body;

  /// Resaltado circular (íconos de la barra) o rectangular (tarjetas).
  final bool circle;

  const CoachMarkStep({
    required this.target,
    required this.title,
    required this.body,
    this.circle = false,
  });
}

/// Tutorial con "foco": oscurece la pantalla, ilumina un elemento a la vez y
/// muestra una tarjeta con su explicación. Se puede omitir en cualquier paso.
/// Los pasos cuyo elemento no está en pantalla se saltan.
class CoachMarks {
  CoachMarks._();

  /// Muestra [steps] sobre la pantalla actual. Termina con `true` si el
  /// usuario lo completó y `false` si lo omitió.
  static Future<bool> show(BuildContext context, List<CoachMarkStep> steps) async {
    final visible =
        steps.where((s) => s.target.currentContext != null).toList();
    if (visible.isEmpty) return true;
    // Ruta transparente (no una OverlayEntry suelta): "atrás" cierra el
    // tutorial como si se omitiera, en vez de cerrar la pantalla de abajo.
    final completed = await Navigator.of(context, rootNavigator: true).push<bool>(
      PageRouteBuilder<bool>(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (routeContext, _, _) => _CoachMarksOverlay(
          steps: visible,
          onDone: (completed) => Navigator.of(routeContext).pop(completed),
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
    return completed ?? false;
  }
}

class _CoachMarksOverlay extends StatefulWidget {
  final List<CoachMarkStep> steps;
  final ValueChanged<bool> onDone;

  const _CoachMarksOverlay({required this.steps, required this.onDone});

  @override
  State<_CoachMarksOverlay> createState() => _CoachMarksOverlayState();
}

class _CoachMarksOverlayState extends State<_CoachMarksOverlay> {
  static const _padding = 6.0;

  int _index = 0;
  Rect? _hole;

  CoachMarkStep get _step => widget.steps[_index];

  @override
  void initState() {
    super.initState();
    _go(0);
  }

  /// Lleva el elemento del paso [i] a la vista y mide dónde quedó.
  Future<void> _go(int i) async {
    setState(() => _index = i);
    final ctx = widget.steps[i].target.currentContext;
    if (ctx == null) return _next();
    if (Scrollable.maybeOf(ctx) != null) {
      await Scrollable.ensureVisible(
        ctx,
        alignment: 0.4,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    // El elemento pudo reconstruirse durante el desplazamiento.
    if (!mounted || _index != i) return;
    final box = widget.steps[i].target.currentContext?.findRenderObject()
        as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return _next();
    final topLeft = box.localToGlobal(Offset.zero);
    setState(() => _hole = (topLeft & box.size).inflate(_padding));
  }

  void _next() {
    if (_index + 1 >= widget.steps.length) {
      widget.onDone(true);
    } else {
      _go(_index + 1);
    }
  }

  void _back() {
    if (_index > 0) _go(_index - 1);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final hole = _hole;
    final theme = Theme.of(context);
    final last = _index == widget.steps.length - 1;

    // La tarjeta va debajo del foco si cabe; si no, encima.
    final below = hole == null || hole.center.dy < size.height * 0.55;
    const margin = 16.0;

    final card = Material(
      color: theme.colorScheme.surface,
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(_step.title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text('${_index + 1}/${widget.steps.length}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(_step.body, style: theme.textTheme.bodyMedium),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => widget.onDone(false),
                  child: const Text('Omitir'),
                ),
                // Si no caben en una línea, se apilan.
                Expanded(
                  child: OverflowBar(
                    alignment: MainAxisAlignment.end,
                    overflowAlignment: OverflowBarAlignment.end,
                    spacing: 4,
                    children: [
                      if (_index > 0)
                        TextButton(onPressed: _back, child: const Text('Atrás')),
                      FilledButton(
                        onPressed: _next,
                        child: Text(last ? 'Terminar' : 'Siguiente'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Oscurece todo menos el foco; tocar fuera avanza.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _next,
              child: TweenAnimationBuilder<Rect?>(
                tween: RectTween(end: hole ?? Rect.zero),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
                builder: (_, rect, _) => CustomPaint(
                  painter: _SpotlightPainter(
                    hole: hole == null ? null : rect,
                    circle: _step.circle,
                    color: Colors.black.withValues(alpha: 0.78),
                  ),
                ),
              ),
            ),
          ),
          if (hole != null)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              left: margin,
              right: margin,
              top: below ? hole.bottom + 12 : null,
              bottom: below ? null : size.height - hole.top + 12,
              child: SafeArea(
                top: false,
                bottom: false,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: card,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect? hole;
  final bool circle;
  final Color color;

  _SpotlightPainter({required this.hole, required this.circle, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Path()..addRect(Offset.zero & size);
    final h = hole;
    if (h == null || h.isEmpty) {
      canvas.drawPath(screen, Paint()..color = color);
      return;
    }
    final spot = Path();
    if (circle) {
      spot.addOval(Rect.fromCircle(
          center: h.center, radius: h.longestSide / 2));
    } else {
      spot.addRRect(RRect.fromRectAndRadius(h, const Radius.circular(14)));
    }
    canvas.drawPath(
      Path.combine(PathOperation.difference, screen, spot),
      Paint()..color = color,
    );
    // Halo alrededor del foco.
    canvas.drawPath(
      spot,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.hole != hole || old.circle != circle || old.color != color;
}
