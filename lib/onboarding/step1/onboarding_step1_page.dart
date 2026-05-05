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

            Column(
              children: [
                for (final option in bodyFatOptions)
                  GestureDetector(
                    onTap: () => setState(() {
                      _selectedBodyFat = option['value'] as double;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _selectedBodyFat == option['value']
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedBodyFat == option['value']
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            option['emoji'] as String,
                            style: const TextStyle(fontSize: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  option['label'] as String,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  option['description'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_selectedBodyFat == option['value'])
                            Icon(
                              Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        ],
                      ),
                    ),
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