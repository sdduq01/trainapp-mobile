import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Logo del gimnasio en un recuadro redondeado. Se guarda en caché de disco,
/// así que el home no lo vuelve a descargar en cada apertura. Sin logo (o si
/// falla la descarga) muestra un ícono genérico.
class GymLogo extends StatelessWidget {
  final String? url;
  final double size;

  const GymLogo({required this.url, this.size = 48, super.key});

  @override
  Widget build(BuildContext context) {
    final placeholder = Icon(
      Icons.fitness_center,
      size: size * 0.5,
      color: Colors.grey,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.2),
      child: Container(
        width: size,
        height: size,
        color: Colors.grey.withValues(alpha: 0.12),
        alignment: Alignment.center,
        child: url == null
            ? placeholder
            : CachedNetworkImage(
                imageUrl: url!,
                width: size,
                height: size,
                fit: BoxFit.contain,
                placeholder: (_, _) => const SizedBox.shrink(),
                errorWidget: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}
