import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';
import '../profile_service.dart';
import '../../onboarding/config/body_fat_options.dart';
import '../../workout/services/routine_generator.dart';
import '../../workout/services/routine_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _userId = FirebaseAuth.instance.currentUser!.uid;

  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();

  double? _bodyFat;
  DateTime? _birthDate;
  int _trainingDays = 4;
  double _experienceMonths = 0;
  TrainingGoal? _goal;
  bool _intensityEnabled = false;
  int _failureCadence = UserProfile.kFailureCadenceDefault;
  bool _warmupEnabled = false;
  bool _stretchingEnabled = false;
  bool _cardioEnabled = false;

  UserProfile? _initial;
  bool _loading = true;
  bool _saving = false;

  static const _goalLabels = {
    TrainingGoal.fatLoss: 'Perder grasa',
    TrainingGoal.muscleGain: 'Ganar masa muscular',
    TrainingGoal.recomposition: 'Recomposición corporal',
    TrainingGoal.sportComplement: 'Deporte complementario',
    TrainingGoal.mentalHealth: 'Salud mental',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = await ProfileService().getProfile(_userId);
    if (!mounted || profile == null) return;
    setState(() {
      _initial = profile;
      _weightCtrl.text = profile.weight?.toString() ?? '';
      _heightCtrl.text = profile.height?.toString() ?? '';
      _bodyFat = profile.bodyFat;
      _birthDate = profile.birthDate;
      _trainingDays = profile.trainingDaysPerWeek ?? 4;
      _experienceMonths = (profile.trainingExperienceMonths ?? 0).toDouble();
      _goal = profile.goal;
      _intensityEnabled = profile.intensityEnabled;
      _failureCadence = profile.failureWeekCadence;
      _warmupEnabled = profile.warmupEnabled;
      _stretchingEnabled = profile.stretchingEnabled;
      _cardioEnabled = profile.cardioEnabled;
      _loading = false;
    });
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initial = _birthDate ?? DateTime(now.year - 25, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 13, now.month, now.day),
      helpText: 'Selecciona tu fecha de nacimiento',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  String _formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  int? _ageOf(DateTime? d) {
    if (d == null) return null;
    final now = DateTime.now();
    int years = now.year - d.year;
    final hadBirthday =
        (now.month > d.month) || (now.month == d.month && now.day >= d.day);
    if (!hadBirthday) years--;
    return years;
  }

  bool get _routineAffectingChanged {
    if (_initial == null) return false;
    return _trainingDays != _initial!.trainingDaysPerWeek ||
        _experienceMonths.round() != _initial!.trainingExperienceMonths ||
        _goal != _initial!.goal;
  }

  bool get _isValid =>
      _weightCtrl.text.isNotEmpty &&
      _heightCtrl.text.isNotEmpty &&
      _bodyFat != null &&
      _birthDate != null &&
      _goal != null &&
      !_saving;

  Future<bool> _confirmRegenerate() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Regenerar rutina'),
        content: const Text(
          'Cambiaste datos que afectan tu rutina (días, objetivo o experiencia). '
          '¿Quieres regenerar la rutina con los nuevos datos? Se reemplazará la rutina actual.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Mantener rutina'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Regenerar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final updated = UserProfile(
      uid: _userId,
      weight: double.tryParse(_weightCtrl.text),
      height: double.tryParse(_heightCtrl.text),
      bodyFat: _bodyFat,
      birthDate: _birthDate,
      trainingExperienceMonths: _experienceMonths.round(),
      trainingDaysPerWeek: _trainingDays,
      goal: _goal,
      completedOnboarding: _initial?.completedOnboarding ?? true,
      intensityEnabled: _intensityEnabled,
      failureWeekCadence: _failureCadence,
      warmupEnabled: _warmupEnabled,
      stretchingEnabled: _stretchingEnabled,
      cardioEnabled: _cardioEnabled,
    );

    final shouldAskRegenerate = _routineAffectingChanged;

    bool saved = false;
    bool regenerated = false;
    try {
      await ProfileService().saveProfile(updated);
      saved = true;

      if (shouldAskRegenerate && mounted) {
        final yes = await _confirmRegenerate();
        if (yes) {
          final routine = RoutineGenerator.generate(updated);
          final hydrated = await RoutineService().hydrateWithPRs(routine);
          await RoutineService().saveRoutine(hydrated);
          regenerated = true;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(regenerated
              ? 'Perfil guardado y rutina regenerada'
              : 'Perfil guardado'),
        ),
      );
      Navigator.of(context).pop(regenerated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionTitle('Datos físicos'),
                const SizedBox(height: 12),
                TextField(
                  controller: _weightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Peso (kg)'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _heightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Altura (cm)'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickBirthDate,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Fecha de nacimiento',
                      prefixIcon: const Icon(Icons.cake_outlined),
                      suffixText: _ageOf(_birthDate) != null
                          ? '${_ageOf(_birthDate)} años'
                          : null,
                    ),
                    child: Text(
                      _birthDate == null
                          ? 'Selecciona tu fecha de nacimiento'
                          : _formatDate(_birthDate!),
                      style: TextStyle(
                        color: _birthDate == null ? Colors.grey[600] : null,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                _sectionTitle('Porcentaje de grasa corporal'),
                const SizedBox(height: 8),
                for (final option in bodyFatOptions)
                  GestureDetector(
                    onTap: () =>
                        setState(() => _bodyFat = option['value'] as double),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _bodyFat == option['value']
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _bodyFat == option['value']
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
                          if (_bodyFat == option['value'])
                            Icon(
                              Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 24),
                _sectionTitle('Objetivo'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _goalLabels.entries
                      .map((e) => ChoiceChip(
                            label: Text(e.value),
                            selected: _goal == e.key,
                            onSelected: (_) => setState(() => _goal = e.key),
                          ))
                      .toList(),
                ),

                const SizedBox(height: 24),
                _sectionTitle('Días por semana'),
                const SizedBox(height: 8),
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
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
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

                const SizedBox(height: 24),
                _sectionTitle('Experiencia en el gimnasio'),
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

                const SizedBox(height: 24),
                _sectionTitle('Intensidad (RIR)'),
                const SizedBox(height: 4),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mostrar intensidad por serie'),
                  subtitle: const Text(
                    'Cada ejercicio mostrará su RIR objetivo según la progresión configurada.',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _intensityEnabled,
                  onChanged: (v) => setState(() => _intensityEnabled = v),
                ),
                if (_intensityEnabled) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Semana FALLO cada $_failureCadence semanas',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const Text(
                    'En doble progresión lineal, cada N semanas la última serie va al FALLO.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Slider(
                    value: _failureCadence.toDouble(),
                    min: UserProfile.kFailureCadenceMin.toDouble(),
                    max: UserProfile.kFailureCadenceMax.toDouble(),
                    divisions: UserProfile.kFailureCadenceMax -
                        UserProfile.kFailureCadenceMin,
                    label: '$_failureCadence semanas',
                    onChanged: (v) =>
                        setState(() => _failureCadence = v.round()),
                  ),
                ],

                const SizedBox(height: 24),
                _sectionTitle('Extras de entrenamiento'),
                const SizedBox(height: 4),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Calentamiento'),
                  subtitle: const Text(
                    'Agrega series de aproximación automáticas (livianas) antes '
                    'de cada ejercicio con peso registrado.',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _warmupEnabled,
                  onChanged: (v) => setState(() => _warmupEnabled = v),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Estiramientos'),
                  subtitle: const Text(
                    'Muestra el grupo "Estiramiento" al agregar ejercicios a tus rutinas.',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _stretchingEnabled,
                  onChanged: (v) => setState(() => _stretchingEnabled = v),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cardio'),
                  subtitle: const Text(
                    'Muestra el grupo "Cardio" al agregar ejercicios a tus rutinas.',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _cardioEnabled,
                  onChanged: (v) => setState(() => _cardioEnabled = v),
                ),

                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _isValid ? _save : null,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Guardar cambios'),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      );
}
