import 'package:flutter/material.dart';

import 'premium_service.dart';

const Color kPremiumColor = Color(0xFFB8860B);

/// Texto único para explicar cómo se obtiene el premium. En la app nunca se
/// cobra ni se enlaza a un pago (políticas de Play): lo activa el gimnasio.
const String kPremiumHowTo =
    'El premium de TrainApp lo activa tu gimnasio. Pídele a tu gimnasio que '
    'te lo active desde su panel de TrainApp.';

/// Reconstruye [builder] cada vez que cambia el premium del usuario.
class PremiumBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, bool premium) builder;
  const PremiumBuilder({required this.builder, super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: PremiumService.instance.isPremium,
      builder: (context, premium, _) => builder(context, premium),
    );
  }
}

/// Etiqueta "Premium" junto a una función bloqueada.
class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kPremiumColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium, size: 13, color: kPremiumColor),
          SizedBox(width: 3),
          Text(
            'Premium',
            style: TextStyle(
              color: kPremiumColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso al tocar una función premium sin tenerlo.
Future<void> showPremiumRequired(BuildContext context, {String? feature}) {
  return showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      icon: const Icon(Icons.workspace_premium, color: kPremiumColor, size: 40),
      title: const Text('Función premium'),
      content: Text(
        feature == null ? kPremiumHowTo : '$feature es premium.\n\n$kPremiumHowTo',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
}

/// Pantalla completa (o pestaña) bloqueada sin premium.
class PremiumLockedPanel extends StatelessWidget {
  final String title;
  final String description;

  const PremiumLockedPanel({
    required this.title,
    required this.description,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.workspace_premium, color: kPremiumColor, size: 64),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(description, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Text(
              kPremiumHowTo,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
