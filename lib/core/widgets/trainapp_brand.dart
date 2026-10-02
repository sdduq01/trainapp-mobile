import 'package:flutter/material.dart';

/// Sello de marca (silueta del logo + "TrainApp") para las pantallas de
/// celebración sobre fondo negro — son las que la gente captura y comparte en
/// redes, así que la marca debe quedar en la foto.
///
/// La silueta y "App" del logo son negros, así que la silueta va sobre una
/// insignia blanca y el nombre se dibuja como texto con "App" en blanco.
class TrainAppBrand extends StatelessWidget {
  final double markSize;

  const TrainAppBrand({this.markSize = 34, super.key});

  static const Color blue = Color(0xFF1E7BE6);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: markSize,
          height: markSize,
          padding: EdgeInsets.all(markSize * 0.08),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(markSize * 0.24),
          ),
          // Recorta de logo.jpeg (1024×1024) solo la silueta con el escudo,
          // sin el nombre de abajo.
          child: FittedBox(
            child: ClipRect(
              child: Align(
                alignment: const Alignment(0, -0.245),
                widthFactor: 0.58,
                heightFactor: 0.47,
                child: Image.asset('assets/icon/logo.jpeg'),
              ),
            ),
          ),
        ),
        SizedBox(width: markSize * 0.3),
        Text.rich(
          TextSpan(
            style: TextStyle(
              fontSize: markSize * 0.62,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              height: 1,
            ),
            children: const [
              TextSpan(text: 'Train', style: TextStyle(color: blue)),
              TextSpan(text: 'App', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }
}
