import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';
import 'login/login_page.dart';
import '../home/home_page.dart';
import '../profile/profile_service.dart';
import '../profile/models/user_profile.dart';
import '../onboarding/step1/onboarding_step1_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final profileService = ProfileService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, authSnapshot) {
        // ⏳ Esperando estado de autenticación
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 🚪 No logueado → Login
        if (!authSnapshot.hasData) {
          return const LoginPage();
        }

        final user = authSnapshot.data!;

        // 👤 Usuario logueado → verificar perfil en Firestore
        return FutureBuilder<UserProfile?>(
          future: profileService.getProfile(user.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final profile = profileSnapshot.data;

            // 🧭 Sin perfil o onboarding incompleto → Onboarding
            if (profile == null || !profile.completedOnboarding) {
              return const OnboardingStep1Page();
            }

            // 🏠 Perfil completo → Home
            return const HomePage();
          },
        );
      },
    );
  }
}
