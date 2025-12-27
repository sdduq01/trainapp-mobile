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
      home: const AuthGate(),
      routes: {
        '/onboarding/step1': (_) => const OnboardingStep1Page(),
        '/onboarding/step2': (_) => const OnboardingStep2Page(),
      },
    );
  }
}