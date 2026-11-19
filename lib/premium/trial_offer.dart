import 'package:flutter/material.dart';

import 'premium_widgets.dart';
import 'trial_service.dart';

/// Oferta de la prueba gratis de premium (perfil y onboarding). Si ya se usó
/// muestra su estado; si el usuario ya tiene premium por su gimnasio no
/// muestra nada.
class TrialOffer extends StatefulWidget {
  final String uid;

  /// El usuario ya tiene premium (no se ofrece la prueba).
  final bool premium;

  /// Se llama cuando la prueba quedó activa.
  final VoidCallback? onActivated;

  const TrialOffer({
    required this.uid,
    required this.premium,
    this.onActivated,
    super.key,
  });

  @override
  State<TrialOffer> createState() => _TrialOfferState();
}

class _TrialOfferState extends State<TrialOffer> {
  Trial? _trial;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final trial = await TrialService().get(widget.uid);
      if (mounted) setState(() => _trial = trial);
    } catch (_) {
      // sin red: no se muestra la oferta
    }
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _start() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Prueba premium gratis'),
        content: const Text(
          'Tendrás todo TrainApp premium durante ${TrialService.days} días: '
          'todo el catálogo, rutinas personalizadas, RIR, calentamiento, '
          'estiramientos y cardio, progresión automática, historial completo '
          'y tu progreso semanal.\n\n'
          'Es gratis, no se cobra nada y se activa una sola vez por persona. '
          'Al terminar vuelves a la versión gratis.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Activar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _starting = true);
    try {
      final trial = await TrialService().start(widget.uid);
      if (!mounted) return;
      setState(() => _trial = trial);
      switch (trial.status) {
        case TrialStatus.active:
          _snack('¡Listo! Tienes premium por ${TrialService.days} días.');
          widget.onActivated?.call();
        case TrialStatus.rejected:
          _snack('Esta cuenta ya usó su prueba gratis.');
        default:
          _snack('Tu prueba se está activando. Revisa en unos minutos.');
      }
    } catch (e) {
      if (mounted) _snack('No se pudo activar la prueba: $e');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trial = _trial;
    if (trial == null) return const SizedBox.shrink();
    switch (trial.status) {
      case TrialStatus.available:
        if (widget.premium) return const SizedBox.shrink();
        return Card(
          color: kPremiumColor.withValues(alpha: 0.10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.workspace_premium, color: kPremiumColor),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Prueba premium gratis ${TrialService.days} días',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Todo el catálogo, rutinas personalizadas, RIR, extras, '
                  'progresión automática y tu progreso completo. Sin costo, '
                  'una sola vez.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _starting ? null : _start,
                  icon: _starting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.bolt),
                  label: Text(_starting
                      ? 'Activando…'
                      : 'Activar prueba gratis'),
                ),
              ],
            ),
          ),
        );
      case TrialStatus.pending:
        return const _Note('Tu prueba gratis se está activando…');
      case TrialStatus.active:
        return const SizedBox.shrink(); // la tarjeta "Plan" muestra cuándo termina
      case TrialStatus.expired:
      case TrialStatus.rejected:
        if (widget.premium) return const SizedBox.shrink();
        return const _Note('Ya usaste tu prueba gratis de premium.');
    }
  }
}

class _Note extends StatelessWidget {
  final String text;
  const _Note(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(text,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
      );
}
