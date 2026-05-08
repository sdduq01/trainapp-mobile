import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/onboarding_data.dart';
import '../../profile/models/user_profile.dart';
import '../../profile/profile_service.dart';
import '../../home/home_page.dart';
import '../../workout/services/routine_generator.dart';
import '../../workout/services/routine_service.dart';

class OnboardingStep2Page extends StatefulWidget {
  const OnboardingStep2Page({super.key});

  @override
  State<OnboardingStep2Page> createState() => _OnboardingStep2PageState();
}

class _OnboardingStep2PageState extends State<OnboardingStep2Page> {
  TrainingGoal? _selectedGoal;
  double _experienceMonths = 0;
  int _trainingDays = 4;
  bool _loading = false;

  final Map<TrainingGoal, String> _goals = {
    TrainingGoal.fatLoss: 'Perder grasa',
    TrainingGoal.muscleGain: 'Ganar masa muscular',
    TrainingGoal.recomposition: 'Recomposición corporal',
    TrainingGoal.sportComplement: 'Deporte complementario',
    TrainingGoal.mentalHealth: 'Salud mental',
  };

  bool get _isValid => _selectedGoal != null && !_loading;

  Future<void> _finish(OnboardingData previousData) async {
    setState(() => _loading = true);

    bool saved = false;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final profile = UserProfile(
        uid: user.uid,
        weight: previousData.weight,
        height: previousData.height,
        bodyFat: previousData.bodyFat,
        birthDate: previousData.birthDate,
        trainingExperienceMonths: _experienceMonths.round(),
        trainingDaysPerWeek: _trainingDays,
        goal: _selectedGoal,
        completedOnboarding: true,
      );

      await ProfileService().saveProfile(profile);

      // Generar rutina automáticamente según el perfil
      final routine = RoutineGenerator.generate(profile);
      await RoutineService().saveRoutine(routine);

      saved = true;
    } catch (e) {
      debugPrint('❌ Error en onboarding: $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }

    if (saved && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final previousData =
        ModalRoute.of(context)!.settings.arguments as OnboardingData;

    return Scaffold(
      appBar: AppBar(title: const Text('Tu entrenamiento')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              '¿Cuál es tu objetivo?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _goals.entries.map((entry) {
                return ChoiceChip(
                  label: Text(entry.value),
                  selected: _selectedGoal == entry.key,
                  onSelected: (_) => setState(() => _selectedGoal = entry.key),
                );
              }).toList(),
            ),

            const SizedBox(height: 32),

            const Text(
              '¿Cuántos días entrenas por semana?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [3, 4, 5, 6].map((days) {
                final selected = _trainingDays == days;
                return GestureDetector(
                  onTap: () => setState(() => _trainingDays = days),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$days',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: selected ? Colors.white : null,
                          ),
                        ),
                        Text(
                          'días',
                          style: TextStyle(
                            fontSize: 11,
                            color: selected ? Colors.white70 : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 32),

            const Text(
              'Experiencia en el gimnasio',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            Text('${_experienceMonths.round()} meses'),

            Slider(
              value: _experienceMonths,
              min: 0,
              max: 120,
              divisions: 120,
              label: '${_experienceMonths.round()} meses',
              onChanged: (v) => setState(() => _experienceMonths = v),
            ),

            const SizedBox(height: 32),

            FilledButton(
              onPressed: _isValid ? () => _finish(previousData) : null,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Finalizar y generar mi rutina'),
            ),
          ],
        ),
      ),
    );
  }
}
