import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../account_deletion_service.dart';
import '../models/user_profile.dart';
import '../profile_service.dart';
import '../../auth/auth_gate.dart';
import '../../core/utils/legal_links.dart';
import '../../gym/models/gym_member.dart';
import '../../gym/services/gym_service.dart';
import '../../onboarding/config/body_fat_options.dart';
import '../../trainer/models/trainer_link.dart';
import '../../trainer/services/trainer_link_service.dart';
import '../../workout/services/routine_generator.dart';
import '../../workout/services/routine_service.dart';
import '../../workout/services/training_reset_service.dart';

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
  bool _isTrainer = false;

  UserProfile? _initial;
  bool _loading = true;
  bool _saving = false;
  bool _resettingData = false;
  bool _deletingAccount = false;

  // Estado de "soy atleta de un entrenador": mi propio doc en trainer_links.
  TrainerLink? _trainerLink;
  bool _trainerLinkLoading = true;
  bool _trainerLinkBusy = false;

  // Pertenencia a un gimnasio: mi propio doc en gym_members.
  GymMember? _gymMembership;
  bool _gymBusy = false;

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
    _loadTrainerLink();
    _loadGymMembership();
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
      _isTrainer = profile.isTrainer;
      _loading = false;
    });
  }

  Future<void> _loadTrainerLink() async {
    try {
      final link = await TrainerLinkService().getLinkForAthlete(_userId);
      if (mounted) {
        setState(() {
          _trainerLink = link;
          _trainerLinkLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _trainerLinkLoading = false);
    }
  }

  Future<void> _acceptTrainer() async {
    setState(() => _trainerLinkBusy = true);
    try {
      await TrainerLinkService().acceptRequest(_userId);
      await _loadTrainerLink();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al aceptar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _trainerLinkBusy = false);
    }
  }

  Future<void> _rejectOrRevokeTrainer() async {
    setState(() => _trainerLinkBusy = true);
    try {
      await TrainerLinkService().deleteLink(_userId);
      await _loadTrainerLink();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _trainerLinkBusy = false);
    }
  }

  Future<void> _loadGymMembership() async {
    try {
      final membership = await GymService().getMembership(_userId);
      if (mounted) setState(() => _gymMembership = membership);
    } catch (_) {
      // silencioso: la sección del gimnasio simplemente no aparece
    }
  }

  Future<void> _acceptGym() async {
    setState(() => _gymBusy = true);
    try {
      await GymService().acceptInvitation(_userId);
      await _loadGymMembership();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al aceptar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _gymBusy = false);
    }
  }

  Future<void> _rejectOrLeaveGym() async {
    final membership = _gymMembership!;
    if (membership.isAccepted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Salir del gimnasio'),
          content: Text(
            'Dejarás de pertenecer a ${membership.gymName}'
            '${membership.isTrainer ? ' y perderás el acceso a sus atletas' : ' y sus entrenadores ya no verán tu rutina'}'
            '. ¿Continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salir'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _gymBusy = true);
    try {
      await GymService().deleteMembership(_userId);
      await _loadGymMembership();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _gymBusy = false);
    }
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

  // ── Zona de peligro: reiniciar datos de entrenamiento ─────

  Future<bool> _confirmResetData() async {
    const confirmWord = 'REINICIAR';
    final ctrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('¿Reiniciar todos los datos?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Esta acción no se puede deshacer. Se borrará para siempre:',
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text(
                  '• Todo el historial de sesiones\n'
                  '• Los PRs y pesos actuales (vuelven a 0)\n'
                  '• Los eventos de progresión y hitos\n'
                  '• Los apuntes guardados por ejercicio\n'
                  '• El contador de semana de la rutina (vuelve a la semana 1)',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Escribe $confirmWord para confirmar:',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: ctrl.text.trim().toUpperCase() == confirmWord
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: const Text('Borrar todo'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    return result ?? false;
  }

  Future<void> _resetTrainingData() async {
    final confirmed = await _confirmResetData();
    if (!confirmed) return;

    setState(() => _resettingData = true);
    try {
      await TrainingResetService().resetAll(_userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos de entrenamiento reiniciados')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _resettingData = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al reiniciar datos: $e')),
        );
      }
    }
  }

  // ── Zona de peligro: eliminar la cuenta ───────────────────

  /// Pide la contraseña como confirmación. Devuelve null si se cancela.
  Future<String?> _confirmDeleteAccount() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('¿Eliminar tu cuenta?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Esta acción no se puede deshacer. Se borrará para siempre:',
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text(
                  '• Tu cuenta de acceso (correo y contraseña)\n'
                  '• Tu perfil y tu rutina activa\n'
                  '• Tus ejercicios y rutinas personalizadas\n'
                  '• Todo el historial de sesiones, PRs, progresión y apuntes\n'
                  '• Tu vínculo con tu entrenador o con tus atletas',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Escribe tu contraseña para confirmar:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                autofocus: true,
                obscureText: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: ctrl.text.isNotEmpty
                  ? () => Navigator.pop(ctx, ctrl.text)
                  : null,
              child: const Text('Eliminar cuenta'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    return result;
  }

  String _deleteAccountError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          return 'Contraseña incorrecta. No se eliminó nada.';
        case 'too-many-requests':
          return 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.';
        case 'network-request-failed':
          return 'Sin conexión. Revisa tu internet e inténtalo de nuevo.';
      }
    }
    return 'Error al eliminar la cuenta: $e';
  }

  Future<void> _deleteAccount() async {
    final password = await _confirmDeleteAccount();
    if (password == null) return;

    setState(() => _deletingAccount = true);
    try {
      await AccountDeletionService().deleteAccount(password: password);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu cuenta fue eliminada')),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _deletingAccount = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_deleteAccountError(e))),
        );
      }
    }
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
      forjadoHierroCompletado: _initial?.forjadoHierroCompletado ?? false,
      isTrainer: _isTrainer,
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

                const SizedBox(height: 24),
                _sectionTitle('Modo entrenador'),
                const SizedBox(height: 4),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Soy entrenador'),
                  subtitle: const Text(
                    'Habilita "Mis atletas" para enviar solicitudes y ver/editar '
                    'la rutina de los atletas que las acepten.',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _isTrainer,
                  onChanged: (v) => setState(() => _isTrainer = v),
                ),

                if (_gymMembership != null) ...[
                  const SizedBox(height: 24),
                  _sectionTitle('Gimnasio'),
                  const SizedBox(height: 8),
                  _buildGymCard(),
                ],

                if (!_trainerLinkLoading && _trainerLink != null) ...[
                  const SizedBox(height: 24),
                  _sectionTitle('Entrenador'),
                  const SizedBox(height: 8),
                  _buildTrainerLinkCard(),
                ],

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

                const SizedBox(height: 40),
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  'Zona de peligro',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Borra tu historial de sesiones, PRs, pesos y progresión '
                  'guardados, y deja la rutina lista para empezar de cero.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _resettingData || _deletingAccount
                      ? null
                      : _resetTrainingData,
                  icon: _resettingData
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_forever_outlined),
                  label: const Text('Reiniciar datos de entrenamiento'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Elimina tu cuenta y todos tus datos de TrainApp de forma '
                  'permanente.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _resettingData || _deletingAccount
                      ? null
                      : _deleteAccount,
                  icon: _deletingAccount
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_remove_outlined),
                  label: const Text('Eliminar mi cuenta'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                TextButton.icon(
                  onPressed: _openPrivacyPolicy,
                  icon: const Icon(Icons.privacy_tip_outlined, size: 18),
                  label: const Text('Política de privacidad'),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Future<void> _openPrivacyPolicy() async {
    final ok = await openPrivacyPolicy();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir: $kPrivacyPolicyUrl')),
      );
    }
  }

  Widget _buildTrainerLinkCard() {
    final link = _trainerLink!;
    final isPending = link.status == TrainerLinkStatus.pending;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isPending
                  ? 'Solicitud pendiente de ${link.trainerEmail}'
                  : 'Tu entrenador: ${link.trainerEmail}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              isPending
                  ? 'Si aceptás, podrá ver y editar tu rutina y ver tu historial.'
                  : 'Puede ver tu rutina e historial, y editar tu rutina y pesos.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (isPending) ...[
                  FilledButton(
                    onPressed: _trainerLinkBusy ? null : _acceptTrainer,
                    child: const Text('Aceptar'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _trainerLinkBusy ? null : _rejectOrRevokeTrainer,
                    child: const Text('Rechazar'),
                  ),
                ] else
                  OutlinedButton(
                    onPressed: _trainerLinkBusy ? null : _rejectOrRevokeTrainer,
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Revocar acceso'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGymCard() {
    final m = _gymMembership!;
    final isPending = !m.isAccepted;
    final String detail;
    if (m.isTrainer) {
      detail = isPending
          ? 'Si aceptas, podrás ver, editar y lanzar las rutinas de los atletas del gimnasio.'
          : 'Puedes ver, editar y lanzar las rutinas de los atletas del gimnasio desde "Mis atletas".';
    } else {
      detail = isPending
          ? 'Si aceptas, los entrenadores del gimnasio podrán ver y editar tu rutina, '
              'ver tu historial y registrar tus sesiones.'
          : 'Los entrenadores del gimnasio pueden ver y editar tu rutina, ver tu '
              'historial y registrar tus sesiones.';
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isPending
                  ? '${m.gymName} te invita como ${m.roleLabel}'
                  : 'Perteneces a ${m.gymName} como ${m.roleLabel}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(detail, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            Row(
              children: [
                if (isPending) ...[
                  FilledButton(
                    onPressed: _gymBusy ? null : _acceptGym,
                    child: const Text('Aceptar'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _gymBusy ? null : _rejectOrLeaveGym,
                    child: const Text('Rechazar'),
                  ),
                ] else
                  OutlinedButton(
                    onPressed: _gymBusy ? null : _rejectOrLeaveGym,
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Salir del gimnasio'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      );
}
