import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/firebase/firestore_instance.dart';

/// Demostración de cómo se hace un ejercicio: WebP animado en Storage
/// (`exercise_demos/{exerciseId}.webp`), referenciado desde el catálogo
/// `exercises/{id}` con `demoUrl` y `demoCredit`. Ver
/// `scripts/build_exercise_demos.js`.
class ExerciseDemo {
  final String url;

  /// Atribución a mostrar ('' si el clip es propio).
  final String credit;

  const ExerciseDemo(this.url, this.credit);
}

/// Carga una vez por sesión las demostraciones del catálogo.
class ExerciseDemoService {
  ExerciseDemoService._();
  static final ExerciseDemoService instance = ExerciseDemoService._();

  Future<Map<String, ExerciseDemo>>? _demos;

  Future<Map<String, ExerciseDemo>> all() {
    return _demos ??= _load().catchError((Object e) {
      _demos = null; // sin red: se reintenta la próxima vez
      throw e;
    });
  }

  Future<Map<String, ExerciseDemo>> _load() async {
    final snap = await db.collection('exercises').get();
    return {
      for (final d in snap.docs)
        if ((d.data()['demoUrl'] as String?)?.isNotEmpty == true)
          d.id: ExerciseDemo(
            d.data()['demoUrl'] as String,
            d.data()['demoCredit'] as String? ?? '',
          ),
    };
  }

  Future<ExerciseDemo?> demoFor(String exerciseId) async {
    try {
      return (await all())[exerciseId];
    } catch (_) {
      return null;
    }
  }

  /// Descarga de antemano las demostraciones de [exerciseIds] (al empezar
  /// la sesión, por si en el gimnasio hay mala señal).
  Future<void> prefetch(BuildContext context, Iterable<String> exerciseIds) async {
    final Map<String, ExerciseDemo> demos;
    try {
      demos = await all();
    } catch (_) {
      return;
    }
    for (final id in exerciseIds) {
      final demo = demos[id];
      if (demo == null || !context.mounted) continue;
      precacheImage(CachedNetworkImageProvider(demo.url), context)
          .catchError((_) {});
    }
  }
}

/// Muestra en un diálogo la demostración de un ejercicio.
Future<void> showExerciseDemo(
  BuildContext context, {
  required String exerciseName,
  required ExerciseDemo demo,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(exerciseName, style: const TextStyle(fontSize: 16)),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 400,
        child: ExerciseDemoView(demo: demo),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}

/// La animación con su atribución debajo.
class ExerciseDemoView extends StatelessWidget {
  final ExerciseDemo demo;
  final double? height;

  const ExerciseDemoView({required this.demo, this.height, super.key});

  static final Uri _licenseUrl =
      Uri.parse('https://creativecommons.org/licenses/by-sa/4.0/deed.es');

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ColoredBox(
            color: Colors.white, // los dibujos son líneas negras sobre blanco
            child: SizedBox(
              height: height,
              width: double.infinity,
              child: AspectRatio(
                aspectRatio: 480 / 420,
                child: CachedNetworkImage(
                  imageUrl: demo.url,
                  fit: BoxFit.contain,
                  placeholder: (_, _) => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  errorWidget: (_, _, _) => const Center(
                    child: Text('No se pudo cargar la demostración.',
                        style: TextStyle(color: Colors.grey)),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (demo.credit.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(fontSize: 11),
                foregroundColor: Colors.grey[600],
              ),
              onPressed: () => launchUrl(_licenseUrl,
                  mode: LaunchMode.externalApplication),
              child: Text(demo.credit),
            ),
          ),
      ],
    );
  }
}

/// Botón ▶ que abre la demostración del ejercicio, si tiene una. Si no, no
/// ocupa espacio.
class ExerciseDemoButton extends StatelessWidget {
  final String exerciseId;
  final String exerciseName;

  const ExerciseDemoButton({
    required this.exerciseId,
    required this.exerciseName,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ExerciseDemo?>(
      future: ExerciseDemoService.instance.demoFor(exerciseId),
      builder: (context, snap) {
        final demo = snap.data;
        if (demo == null) return const SizedBox.shrink();
        return IconButton(
          icon: const Icon(Icons.play_circle_outline),
          tooltip: 'Ver cómo se hace',
          visualDensity: VisualDensity.compact,
          onPressed: () => showExerciseDemo(context,
              exerciseName: exerciseName, demo: demo),
        );
      },
    );
  }
}

/// Demostración plegable para la pantalla de entrenamiento: una franja
/// "Cómo se hace" que se abre en la animación. Recuerda si el usuario la dejó
/// abierta o cerrada mientras dure la sesión.
class ExerciseDemoPanel extends StatefulWidget {
  final String exerciseId;

  const ExerciseDemoPanel({required this.exerciseId, super.key});

  @override
  State<ExerciseDemoPanel> createState() => _ExerciseDemoPanelState();
}

class _ExerciseDemoPanelState extends State<ExerciseDemoPanel> {
  static bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ExerciseDemo?>(
      future: ExerciseDemoService.instance.demoFor(widget.exerciseId),
      builder: (context, snap) {
        final demo = snap.data;
        if (demo == null) return const SizedBox.shrink();
        return Card(
          margin: const EdgeInsets.only(top: 12),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.play_circle_outline, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Cómo se hace',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                    ],
                  ),
                ),
              ),
              if (_expanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  child: ExerciseDemoView(demo: demo, height: 200),
                ),
            ],
          ),
        );
      },
    );
  }
}
