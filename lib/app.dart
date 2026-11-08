import 'package:flutter/material.dart';
import 'auth/auth_gate.dart';
import 'onboarding/step1/onboarding_step1_page.dart';
import 'onboarding/step2/onboarding_step2_page.dart';


class TrainApp extends StatelessWidget {
  const TrainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          primary: const Color(0xFF1565C0),
        ),
        useMaterial3: true,
      ),
      // La app se dibuja de borde a borde (ver MainActivity). Este margen
      // global evita que listas, botones y hojas inferiores queden debajo
      // de la barra de navegación del sistema; el AppBar ya maneja la de
      // estado. El fondo pinta la franja con el color de las pantallas.
      builder: (context, child) => ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(top: false, child: child!),
      ),
      home: const AuthGate(),
      routes: {
        '/onboarding/step1': (_) => const OnboardingStep1Page(),
        '/onboarding/step2': (_) => const OnboardingStep2Page(),
      },
    );
  }
}