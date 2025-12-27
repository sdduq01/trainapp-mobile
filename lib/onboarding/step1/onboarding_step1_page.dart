import 'package:flutter/material.dart';
import '../models/onboarding_data.dart';
import '../config/body_fat_options.dart';

class OnboardingStep1Page extends StatefulWidget {
  const OnboardingStep1Page({super.key});

  @override
  State<OnboardingStep1Page> createState() => _OnboardingStep1PageState();
}

class _OnboardingStep1PageState extends State<OnboardingStep1Page> {
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();

  double? _selectedBodyFat;

  bool get _isValid =>
      _weightController.text.isNotEmpty &&
      _heightController.text.isNotEmpty &&
      _selectedBodyFat != null;

  void _continue() {
    final data = OnboardingData(
      weight: double.tryParse(_weightController.text),
      height: double.tryParse(_heightController.text),
      bodyFat: _selectedBodyFat,
    );

    Navigator.pushNamed(
      context,
      '/onboarding/step2',
      arguments: data,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tu cuerpo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              'Cuéntanos sobre ti',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            TextField(
              controller: _weightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Peso (kg)',
              ),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _heightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Altura (cm)',
              ),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 24),
            const Text(
              'Porcentaje de grasa corporal',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              children: [
                for (final option in bodyFatOptions)
                  ChoiceChip(
                    label: Text(option['label'] as String),
                    selected: _selectedBodyFat == option['value'],
                    onSelected: (_) {
                      setState(() {
                        _selectedBodyFat = option['value'] as double;
                      });
                    },
                  ),
              ],
            ),

            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isValid ? _continue : null,
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
  }
}