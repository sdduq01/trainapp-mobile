import 'package:flutter/material.dart';
import '../models/onboarding_data.dart';

class OnboardingStep2Page extends StatefulWidget {
  const OnboardingStep2Page({super.key});

  @override
  State<OnboardingStep2Page> createState() => _OnboardingStep2PageState();
}

class _OnboardingStep2PageState extends State<OnboardingStep2Page> {
  String? _selectedGoal;
  double _experienceMonths = 0;

  final _goals = [
    'Perder grasa',
    'Ganar masa muscular',
    'Recomposición corporal',
    'Deporte complementario',
  ];

  bool get _isValid => _selectedGoal != null;

  void _finish(OnboardingData previousData) {
    final finalData = previousData.copyWith(
      goal: _selectedGoal,
      trainingExperienceMonths: _experienceMonths.round(),
    );

    // Por ahora solo debug
    debugPrint('ONBOARDING COMPLETO');
    debugPrint(finalData.toString());

    // En el próximo paso:
    // - Guardar en Firestore
    // - Redirigir a Home
  }

  @override
  Widget build(BuildContext context) {
    final previousData =
        ModalRoute.of(context)!.settings.arguments as OnboardingData;

    return Scaffold(
      appBar: AppBar(title: const Text('Tu experiencia')),
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
              children: [
                for (final goal in _goals)
                  ChoiceChip(
                    label: Text(goal),
                    selected: _selectedGoal == goal,
                    onSelected: (_) {
                      setState(() {
                        _selectedGoal = goal;
                      });
                    },
                  ),
              ],
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
              label: _experienceMonths.round().toString(),
              onChanged: (value) {
                setState(() {
                  _experienceMonths = value;
                });
              },
            ),

            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isValid ? () => _finish(previousData) : null,
              child: const Text('Finalizar'),
            ),
          ],
        ),
      ),
    );
  }
}