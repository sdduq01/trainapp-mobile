import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../profile/models/user_profile.dart';
import '../../profile/profile_service.dart';
import '../models/progression_type.dart';
import '../models/routine.dart';
import '../models/workout_session.dart';
import '../services/exercise_notes_service.dart';
import '../services/exercise_pr_service.dart';
import '../services/progression_logic.dart';
import '../services/progression_service.dart';
import '../services/routine_service.dart';
import '../services/session_service.dart';

class WorkoutSessionPage extends StatefulWidget {
  final RoutineDay day;

  const WorkoutSessionPage({required this.day, super.key});

  @override
  State<WorkoutSessionPage> createState() => _WorkoutSessionPageState();
}

class _WorkoutSessionPageState extends State<WorkoutSessionPage>
    with WidgetsBindingObserver {
  final _userId = FirebaseAuth.instance.currentUser!.uid;
  final _audioPlayer = AudioPlayer();

  static const int kNoteMaxLength = 200;

  int _exerciseIndex = 0;
  int _setIndex = 0;

  // [exerciseIndex][setIndex] = (repsDone, weight) | null
  late List<List<(int, double)?>> _logged;

  // exerciseId → apunte. Cargado en initState y editado en sesión.
  final Map<String, String> _notes = {};

  // Configuración de intensidad cargada del perfil.
  bool _intensityEnabled = false;
  int _failureCadence = UserProfile.kFailureCadenceDefault;

  // Semana de la rutina (1-indexada). Calculada a partir de routine.createdAt.
  int _weekIndex = 1;

  late TextEditingController _weightCtrl;
  late TextEditingController _repsCtrl;

  bool _resting = false;
  bool _restExpired = false;
  int _restRemaining = 0;
  Timer? _timer;
  DateTime? _restEndTime;
  VoidCallback? _afterRest;

  // Cronómetro para ejercicios isométricos (plancha y similares).
  bool _isoRunning = false;
  int _isoElapsed = 0;
  DateTime? _isoStartTime;
  Timer? _isoTimer;

  bool _saving = false;

  RoutineExercise get _currentExercise =>
      widget.day.exercises[_exerciseIndex];

  int get _totalSets =>
      widget.day.exercises.fold(0, (sum, e) => sum + e.sets);

  int get _completedSets {
    int count = 0;
    for (int i = 0; i < _exerciseIndex; i++) {
      count += widget.day.exercises[i].sets;
    }
    return count + _setIndex;
  }

  bool get _isLastSet => _setIndex == _currentExercise.sets - 1;
  bool get _isLastExercise =>
      _exerciseIndex == widget.day.exercises.length - 1;

  // ── Audio ────────────────────────────────────────────────

  // Genera un WAV con 6 pitidos a 880 Hz
  static Uint8List _generateBeepWav() {
    const sampleRate = 22050;
    const hz = 880.0;
    const durations = [0.15, 0.08, 0.15, 0.08, 0.15, 0.08, 0.15, 0.08, 0.15, 0.08, 0.30];
    const isTone   = [true, false, true, false, true, false, true, false, true, false, true];

    final samples = <int>[];
    for (int seg = 0; seg < durations.length; seg++) {
      final n = (sampleRate * durations[seg]).toInt();
      for (int s = 0; s < n; s++) {
        if (!isTone[seg]) { samples.add(0); continue; }
        final t = s / sampleRate;
        double amp = 0.80;
        // Fade in/out de 5 ms para evitar clicks
        final fadeN = (sampleRate * 0.005).toInt();
        if (s < fadeN) amp *= s / fadeN;
        if (s > n - fadeN) amp *= (n - s) / fadeN;
        samples.add(
          (amp * 32767 * math.sin(2 * math.pi * hz * t))
              .round()
              .clamp(-32768, 32767),
        );
      }
    }

    final numSamples = samples.length;
    final buf = ByteData(44 + numSamples * 2);

    void writeStr(int offset, String s) {
      for (int i = 0; i < s.length; i++) { buf.setUint8(offset + i, s.codeUnitAt(i)); }
    }

    writeStr(0, 'RIFF');
    buf.setUint32(4, 36 + numSamples * 2, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    buf.setUint32(16, 16, Endian.little);
    buf.setUint16(20, 1, Endian.little);           // PCM
    buf.setUint16(22, 1, Endian.little);           // mono
    buf.setUint32(24, sampleRate, Endian.little);
    buf.setUint32(28, sampleRate * 2, Endian.little);
    buf.setUint16(32, 2, Endian.little);
    buf.setUint16(34, 16, Endian.little);
    writeStr(36, 'data');
    buf.setUint32(40, numSamples * 2, Endian.little);
    for (int i = 0; i < numSamples; i++) {
      buf.setInt16(44 + i * 2, samples[i], Endian.little);
    }

    return buf.buffer.asUint8List();
  }

  Future<void> _playAlarm() async {
    await _audioPlayer.stop();
    await _audioPlayer.play(BytesSource(_generateBeepWav()));
  }

  Future<void> _stopAlarm() => _audioPlayer.stop();

  // ── Draft de sesión (persistencia ante kill del proceso) ──

  static const _kDraftKey = 'session_draft';

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loggedJson = _logged
          .map((ex) => ex.map((s) => s == null ? null : [s.$1, s.$2]).toList())
          .toList();
      await prefs.setString(
        _kDraftKey,
        jsonEncode({
          'dayNumber': widget.day.dayNumber,
          'exerciseIndex': _exerciseIndex,
          'setIndex': _setIndex,
          'logged': loggedJson,
        }),
      );
    } catch (_) {}
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kDraftKey);
    } catch (_) {}
  }

  Future<void> _tryRestoreDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kDraftKey);
      if (raw == null || !mounted) return;

      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map['dayNumber'] != widget.day.dayNumber) {
        await prefs.remove(_kDraftKey);
        return;
      }

      final rawLogged = map['logged'] as List;
      // Valida que la estructura coincida con los ejercicios actuales del día
      if (rawLogged.length != widget.day.exercises.length) {
        await prefs.remove(_kDraftKey);
        return;
      }
      for (int i = 0; i < widget.day.exercises.length; i++) {
        if ((rawLogged[i] as List).length != widget.day.exercises[i].sets) {
          await prefs.remove(_kDraftKey);
          return;
        }
      }

      final hasProgress =
          rawLogged.any((ex) => (ex as List).any((s) => s != null));
      if (!hasProgress) return;

      if (!mounted) return;
      final shouldRestore = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Sesión en progreso'),
          content: Text(
            'Tenías una sesión del Día ${widget.day.dayNumber} sin terminar. ¿Continuarla?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Empezar de nuevo'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      if (shouldRestore != true) {
        await prefs.remove(_kDraftKey);
        return;
      }

      // Deserializa los sets guardados
      final restored = rawLogged.map((exJson) {
        return (exJson as List).map<(int, double)?>((s) {
          if (s == null) return null;
          return ((s[0] as int), (s[1] as num).toDouble());
        }).toList();
      }).toList();

      int exIdx = map['exerciseIndex'] as int;
      int setIdx = map['setIndex'] as int;

      // Si el set guardado ya estaba completado (la app murió durante el descanso),
      // avanza silenciosamente al siguiente set/ejercicio sin timer
      if (exIdx < widget.day.exercises.length &&
          setIdx < widget.day.exercises[exIdx].sets &&
          restored[exIdx][setIdx] != null) {
        final ex = widget.day.exercises[exIdx];
        if (setIdx < ex.sets - 1) {
          setIdx++;
        } else if (exIdx < widget.day.exercises.length - 1) {
          exIdx++;
          setIdx = 0;
        } else {
          // Murió en el descanso del último set del último ejercicio
          setState(() { _logged = restored; _exerciseIndex = exIdx; _setIndex = setIdx; });
          _finishSession();
          return;
        }
      }

      setState(() {
        _logged = restored;
        _exerciseIndex = exIdx;
        _setIndex = setIdx;
      });
      _disposeControllers();
      _initControllers();
    } catch (_) {
      // Draft corrupto — ignora
    }
  }

  // ── Ciclo de vida ─────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _logged = widget.day.exercises
        .map((e) => List<(int, double)?>.filled(e.sets, null))
        .toList();
    _initControllers();
    _loadNotes();
    _loadIntensityConfig();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _resting && !_restExpired) {
      _syncRestFromWallClock();
    }
    if (state == AppLifecycleState.resumed && _isoRunning) {
      _syncIsoFromWallClock();
    }
  }

  void _syncRestFromWallClock() {
    if (_restEndTime == null) return;
    final remaining = _restEndTime!.difference(DateTime.now()).inSeconds;
    if (remaining <= 0) {
      _timer?.cancel();
      if (!mounted) return;
      setState(() { _restExpired = true; _restRemaining = 0; });
      _playAlarm();
    } else {
      if (!mounted) return;
      setState(() => _restRemaining = remaining);
    }
  }

  Future<void> _loadIntensityConfig() async {
    final results = await Future.wait([
      ProfileService().getProfile(_userId),
      RoutineService().getRoutine(_userId),
    ]);
    final profile = results[0] as UserProfile?;
    final routine = results[1] as Routine?;
    if (!mounted) return;
    setState(() {
      if (profile != null) {
        _intensityEnabled = profile.intensityEnabled;
        _failureCadence = profile.failureWeekCadence;
      }
      if (routine != null) {
        _weekIndex = ProgressionLogic.weekIndexFor(routine);
      }
      // Re-prefilar el set activo con el target dinámico (puede haber
      // cambiado tras conocer cadencia/semana).
      _refillControllers();
    });
    await _tryRestoreDraft();
  }

  SetTarget _currentTarget() {
    final ex = _currentExercise;
    if (_setIndex == 0) {
      return ProgressionLogic.targetForSet(
        exercise: ex,
        setIndex: 0,
        weekIndex: _weekIndex,
        intensityEnabled: _intensityEnabled,
        failureCadence: _failureCadence,
      );
    }

    // A partir de set 2, el peso/reps depende de lo que el usuario hizo en el
    // set anterior (sobre todo en piramidal).
    final prev = _logged[_exerciseIndex][_setIndex - 1];
    final prevWeight = prev?.$2 ?? ex.currentWeight;
    final prevReps = prev?.$1 ?? 0;

    switch (ex.progressionType) {
      case ProgressionType.none:
      case ProgressionType.doubleLinear:
        final base = ProgressionLogic.targetForSet(
          exercise: ex,
          setIndex: _setIndex,
          weekIndex: _weekIndex,
          intensityEnabled: _intensityEnabled,
          failureCadence: _failureCadence,
        );
        return SetTarget(
          weight: prevWeight,
          reps: base.reps,
          rir: base.rir,
          isFailure: base.isFailure,
        );

      case ProgressionType.pyramid:
        final hitMax = prevReps >= ex.repsMax;
        final newWeight = hitMax
            ? prevWeight + ex.progressionStep
            : prevWeight;
        final rir =
            ProgressionLogic.pyramidRirMap(ex.sets)[_setIndex];
        final isFailure =
            _intensityEnabled && _isLastSet && rir == 0;
        return SetTarget(
          weight: newWeight,
          reps: ex.repsMax,
          rir: _intensityEnabled ? rir : null,
          isFailure: isFailure,
        );

      case ProgressionType.reversePyramid:
        final newWeight = prevWeight - ex.progressionStep;
        final reps = ex.repsMin + _setIndex;
        final rir =
            ProgressionLogic.reversePyramidRirMap(ex.sets)[_setIndex];
        final isFailure =
            _intensityEnabled && _isLastSet && rir == 0;
        return SetTarget(
          weight: newWeight,
          reps: reps,
          rir: _intensityEnabled ? rir : null,
          isFailure: isFailure,
        );
    }
  }

  void _refillControllers() {
    final t = _currentTarget();
    _weightCtrl.text = t.weight > 0 ? _trimDouble(t.weight) : '';
    _repsCtrl.text = t.reps.toString();
  }

  static String _trimDouble(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toString();

  Future<void> _loadNotes() async {
    final ids = widget.day.exercises.map((e) => e.exerciseId).toList();
    final notes = await ExerciseNotesService().getForExercises(_userId, ids);
    if (!mounted) return;
    setState(() {
      _notes
        ..clear()
        ..addAll(notes);
    });
  }

  Future<void> _editNote() async {
    final ex = _currentExercise;
    final saved = await showDialog<String>(
      context: context,
      builder: (_) => _NoteEditorDialog(
        exerciseName: ex.name,
        initialNote: _notes[ex.exerciseId] ?? '',
        maxLength: kNoteMaxLength,
      ),
    );
    if (saved == null) return;
    final trimmed = saved.trim();
    await ExerciseNotesService().upsert(_userId, ex.exerciseId, trimmed);
    if (!mounted) return;
    setState(() {
      if (trimmed.isEmpty) {
        _notes.remove(ex.exerciseId);
      } else {
        _notes[ex.exerciseId] = trimmed;
      }
    });
  }

  void _initControllers() {
    _weightCtrl = TextEditingController();
    _repsCtrl = TextEditingController();
    _resetIsoTimer();
    _refillControllers();
  }

  void _disposeControllers() {
    _weightCtrl.dispose();
    _repsCtrl.dispose();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _isoTimer?.cancel();
    _audioPlayer.dispose();
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    super.dispose();
  }

  // ── Timer de descanso ─────────────────────────────────────

  void _startCountdown(int seconds) {
    _timer?.cancel();
    _restEndTime = DateTime.now().add(Duration(seconds: seconds));
    setState(() { _restRemaining = seconds; _restExpired = false; });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      final remaining = _restEndTime!.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        t.cancel();
        setState(() { _restExpired = true; _restRemaining = 0; });
        _playAlarm();
      } else {
        setState(() => _restRemaining = remaining);
      }
    });
  }

  void _startRest(int seconds, {required VoidCallback onDone}) {
    _afterRest = onDone;
    setState(() { _resting = true; _restExpired = false; });
    _startCountdown(seconds);
  }

  void _postponeRest() {
    _stopAlarm();
    _startCountdown(30);
  }

  void _continueFromRest() {
    _timer?.cancel();
    _stopAlarm();
    final cb = _afterRest;
    _afterRest = null;
    setState(() { _resting = false; _restExpired = false; });
    cb?.call();
  }

  void _skipRest() {
    _timer?.cancel();
    _stopAlarm();
    final cb = _afterRest;
    _afterRest = null;
    setState(() { _resting = false; _restExpired = false; });
    cb?.call();
  }

  // ── Cronómetro de ejercicio isométrico ────────────────────
  //
  // El campo de "reps" representa segundos sostenidos para estos ejercicios.
  // Usa DateTime absoluto (igual que el descanso) para sobrevivir a que la
  // app pase a segundo plano mientras el usuario sostiene la posición.

  void _startIsoTimer() {
    _isoTimer?.cancel();
    _isoStartTime = DateTime.now();
    setState(() { _isoRunning = true; _isoElapsed = 0; });
    _isoTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() =>
          _isoElapsed = DateTime.now().difference(_isoStartTime!).inSeconds);
    });
  }

  void _stopIsoTimer() {
    _isoTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isoRunning = false;
      _repsCtrl.text = _isoElapsed.toString();
    });
  }

  void _syncIsoFromWallClock() {
    if (_isoStartTime == null || !mounted) return;
    setState(() =>
        _isoElapsed = DateTime.now().difference(_isoStartTime!).inSeconds);
  }

  void _resetIsoTimer() {
    _isoTimer?.cancel();
    _isoRunning = false;
    _isoElapsed = 0;
  }

  // ── Avance de ejercicio ───────────────────────────────────

  void _completeSet() {
    final ex = _currentExercise;
    // Si el cronómetro isométrico sigue corriendo, lo detiene y usa el
    // tiempo transcurrido como valor de la serie.
    if (ex.isIsometric && _isoRunning) _stopIsoTimer();

    final repsDone = int.tryParse(_repsCtrl.text) ?? ex.repsMax;
    final weight   = double.tryParse(_weightCtrl.text) ?? ex.currentWeight;

    setState(() => _logged[_exerciseIndex][_setIndex] = (repsDone, weight));
    _saveDraft(); // fire-and-forget — persiste ante kill del proceso

    if (_isLastSet && _isLastExercise) {
      _startRest(ex.restSeconds, onDone: _finishSession);
    } else if (_isLastSet) {
      _startRest(ex.restSeconds, onDone: _advanceExercise);
    } else {
      _startRest(ex.restSeconds, onDone: _advanceSet);
    }
  }

  void _advanceSet() {
    _resetIsoTimer();
    setState(() => _setIndex++);
    _refillControllers();
  }

  void _advanceExercise() {
    _disposeControllers();
    _resetIsoTimer();
    setState(() { _exerciseIndex++; _setIndex = 0; });
    _initControllers();
  }

  // ── Finalizar sesión ──────────────────────────────────────

  Future<void> _finishSession() async {
    setState(() => _saving = true);

    final exercises = <SessionExercise>[];
    for (int i = 0; i < widget.day.exercises.length; i++) {
      final ex = widget.day.exercises[i];
      final sets = <SessionSet>[];
      for (int s = 0; s < ex.sets; s++) {
        final log = _logged[i][s];
        sets.add(SessionSet(
          setNumber: s + 1,
          repsTarget: ex.repsMax,
          repsDone: log?.$1 ?? 0,
          weight: log?.$2 ?? 0,
          weightUnit: ex.weightUnit,
        ));
      }
      exercises.add(SessionExercise(
        exerciseId: ex.exerciseId,
        name: ex.name,
        sets: sets,
      ));
    }

    final session = WorkoutSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: _userId,
      date: DateTime.now(),
      dayNumber: widget.day.dayNumber,
      dayName: widget.day.name,
      focus: widget.day.focus,
      exercises: exercises,
      completed: true,
    );

    List<(String, double, double, String)> progressed = [];
    try {
      await SessionService().saveSession(session)
          .timeout(const Duration(seconds: 20));
      progressed = await _applyProgression()
          .timeout(const Duration(seconds: 20));
      if (progressed.isNotEmpty) {
        await ProgressionService()
            .saveProgressionEvent(_userId, progressed.length)
            .timeout(const Duration(seconds: 10));
      }
    } catch (_) {
      // Error de red o timeout: la sesión puede no haberse persistido,
      // pero no colgamos la app — siempre navegamos de vuelta.
    }

    await _clearDraft();
    if (!mounted) return;
    setState(() => _saving = false);
    if (progressed.isNotEmpty) {
      _showProgressionDialog(progressed);
    } else {
      _showCompletionDialog();
    }
  }

  // Evalúa el resultado de la sesión para un ejercicio según su tipo de
  // progresión. Devuelve null si no hay nada que escribir (sin sets logueados,
  // o tipo `none`).
  ({double newWeight, double referenceWeight, bool didProgress})? _evalProgression(
    RoutineExercise ex,
    List<(int, double)?> logged,
  ) {
    final weights = logged.where((s) => s != null && s.$2 > 0).map((s) => s!.$2);
    if (weights.isEmpty) return null;
    final maxWeightUsed = weights.reduce((a, b) => a > b ? a : b);

    switch (ex.progressionType) {
      case ProgressionType.none:
        // No actualiza currentWeight desde la sesión. El usuario edita manual.
        return null;

      case ProgressionType.doubleLinear:
        final setsAtMax = logged
            .where((s) => s != null && s.$1 >= ex.repsMax && s.$2 > 0)
            .length;
        if (ex.progressionStep > 0 && setsAtMax / ex.sets > 0.9) {
          return (
            newWeight: maxWeightUsed + ex.progressionStep,
            referenceWeight: maxWeightUsed,
            didProgress: true,
          );
        }
        // Definición de marcas: persiste el mayor peso usado aunque no progrese.
        final preserved = maxWeightUsed > ex.currentWeight
            ? maxWeightUsed
            : ex.currentWeight;
        return (
          newWeight: preserved,
          referenceWeight: maxWeightUsed,
          didProgress: false,
        );

      case ProgressionType.pyramid:
        final newWeight = ProgressionLogic.evalPyramidOverload(ex, logged);
        if (newWeight == null) return null;
        // Referencia para el dialog: el peso del set 2 actual = currentWeight + step
        // (que es el peso con el que arrancará la próxima sesión).
        return (
          newWeight: newWeight,
          referenceWeight: ex.currentWeight,
          didProgress: true,
        );

      case ProgressionType.reversePyramid:
        final newWeight =
            ProgressionLogic.evalReversePyramidOverload(ex, logged);
        if (newWeight == null) return null;
        return (
          newWeight: newWeight,
          referenceWeight: ex.currentWeight,
          didProgress: true,
        );
    }
  }

  // Recorre la rutina, aplica la progresión por tipo, y persiste cambios en
  // routine + PRs. Devuelve la lista de progresiones para mostrar el dialog.
  Future<List<(String, double, double, String)>> _applyProgression() async {
    final progressed = <(String, double, double, String)>[];
    final prUpdates = <String, ExercisePr>{};
    final routine = await RoutineService().getRoutine(_userId);
    if (routine == null) return progressed;

    bool changed = false;
    final updatedDays = routine.days.map((day) {
      if (day.dayNumber != widget.day.dayNumber) return day;

      final updatedExercises = day.exercises.map((routineEx) {
        final logIdx = widget.day.exercises
            .indexWhere((e) => e.exerciseId == routineEx.exerciseId);
        if (logIdx == -1) return routineEx;

        final logged = _logged[logIdx];
        if (logged.every((s) => s == null)) return routineEx;

        final outcome = _evalProgression(routineEx, logged);
        if (outcome == null) return routineEx;

        final newWeight = outcome.newWeight;
        if (newWeight == routineEx.currentWeight) return routineEx;

        changed = true;
        prUpdates[routineEx.exerciseId] =
            ExercisePr(weight: newWeight, unit: routineEx.weightUnit);
        if (outcome.didProgress) {
          progressed.add(
              (routineEx.name, outcome.referenceWeight, newWeight, routineEx.weightUnit));
        }

        return routineEx.copyWith(currentWeight: newWeight);
      }).toList();

      return RoutineDay(
        dayNumber: day.dayNumber,
        name: day.name,
        focus: day.focus,
        exercises: updatedExercises,
      );
    }).toList();

    if (changed) {
      await RoutineService().saveRoutine(Routine(
        userId: routine.userId,
        type: routine.type,
        name: routine.name,
        weekNumber: routine.weekNumber,
        createdAt: routine.createdAt,
        days: updatedDays,
      ));
      await ExercisePrService().upsertMany(_userId, prUpdates);
    }

    return progressed;
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('¡Sesión completada!'),
        content: Text('${widget.day.name} registrada correctamente.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(true);
            },
            child: const Text('Volver al inicio'),
          ),
        ],
      ),
    );
  }

  void _showProgressionDialog(List<(String, double, double, String)> progressed) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💪', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              const Text(
                'PROGRESIÓN\nDESBLOQUEADA',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '"Es una desgracia envejecer sin ver\nla belleza y la fuerza de la que\ntu cuerpo es capaz"',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '— Sócrates',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 20),
              const Divider(color: Colors.white24),
              const SizedBox(height: 12),
              for (final p in progressed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.trending_up, color: Colors.green, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          p.$1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${p.$2} → ${p.$3} ${p.$4}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop(true);
                  },
                  child: const Text(
                    'SEGUIR CRECIENDO 🏋️',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmExit() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Abandonar sesión?'),
        content: const Text('El progreso de esta sesión no se guardará.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Abandonar',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (result == true) await _clearDraft();
    return result ?? false;
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final exit = await _confirmExit();
        if (exit && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Día ${day.dayNumber} · ${day.name}'),
        ),
        body: _saving
            ? const Center(child: CircularProgressIndicator())
            : _resting
                ? _buildRestTimer()
                : _buildExerciseView(),
      ),
    );
  }

  Widget _buildRestTimer() {
    final colorScheme = Theme.of(context).colorScheme;

    if (_restExpired) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '¡Tiempo!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 160,
                  height: 160,
                  child: CircularProgressIndicator(
                    value: 0,
                    strokeWidth: 10,
                    backgroundColor: Colors.grey[200],
                  ),
                ),
                const Text(
                  '0 s',
                  style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 44),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _postponeRest,
                  icon: const Icon(Icons.add),
                  label: const Text('30 s más'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: _continueFromRest,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Continuar'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Timer activo
    final total = _currentExercise.restSeconds.toDouble();
    final progress = total > 0 ? _restRemaining / total : 0.0;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Descansando',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 10,
                  backgroundColor: Colors.grey[200],
                ),
              ),
              Text(
                '$_restRemaining s',
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          OutlinedButton(
            onPressed: _skipRest,
            child: const Text('Saltar descanso'),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseView() {
    final ex = _currentExercise;
    final totalEx = widget.day.exercises.length;

    return Column(
      children: [
        LinearProgressIndicator(
          value: _totalSets > 0 ? _completedSets / _totalSets : 0,
          minHeight: 4,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ejercicio ${_exerciseIndex + 1} de $totalEx',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  ex.name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ex.isIsometric
                      ? '${ex.sets} series · ${ex.repsMin}–${ex.repsMax} s · ${ex.restSeconds}s descanso'
                      : '${ex.sets} series · ${ex.repsMin}–${ex.repsMax} reps · ${ex.restSeconds}s descanso',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),

                _NoteCard(
                  note: _notes[ex.exerciseId],
                  onTap: _editNote,
                ),

                const SizedBox(height: 20),

                for (int s = 0; s < _setIndex; s++) ...[
                  _CompletedSetTile(
                    setNumber: s + 1,
                    repsDone: _logged[_exerciseIndex][s]!.$1,
                    weight: _logged[_exerciseIndex][s]!.$2,
                    weightUnit: ex.weightUnit,
                    isIsometric: ex.isIsometric,
                  ),
                  const SizedBox(height: 8),
                ],

                _ActiveSetCard(
                  setNumber: _setIndex + 1,
                  totalSets: ex.sets,
                  weightUnit: ex.weightUnit,
                  weightCtrl: _weightCtrl,
                  repsCtrl: _repsCtrl,
                  rir: _currentTarget().rir,
                  isFailure: _currentTarget().isFailure,
                  isIsometric: ex.isIsometric,
                  isoRunning: _isoRunning,
                  isoElapsed: _isoElapsed,
                  onStartIsoTimer: _startIsoTimer,
                  onStopIsoTimer: _stopIsoTimer,
                ),

                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _completeSet,
                    child: Text(
                      _isLastSet && _isLastExercise
                          ? 'Terminar sesión'
                          : 'Completar serie',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────

class _NoteEditorDialog extends StatefulWidget {
  final String exerciseName;
  final String initialNote;
  final int maxLength;

  const _NoteEditorDialog({
    required this.exerciseName,
    required this.initialNote,
    required this.maxLength,
  });

  @override
  State<_NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<_NoteEditorDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initialNote);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.exerciseName, style: const TextStyle(fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Apunte personal',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLength: widget.maxLength,
            maxLines: 4,
            minLines: 2,
            decoration: const InputDecoration(
              hintText: 'Ej: Banco en 2, retracción escapular…',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  final String? note;
  final VoidCallback onTap;

  const _NoteCard({required this.note, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasNote = note != null && note!.isNotEmpty;
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hasNote
              ? Colors.amber.withValues(alpha: 0.10)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasNote
                ? Colors.amber.withValues(alpha: 0.5)
                : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              hasNote ? Icons.sticky_note_2_outlined : Icons.note_add_outlined,
              size: 20,
              color: hasNote ? Colors.amber[800] : Colors.grey[600],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasNote ? note! : 'Agregar apunte (ajuste de máquina, cue técnico…)',
                style: TextStyle(
                  fontSize: 13,
                  color: hasNote ? Colors.black87 : Colors.grey[600],
                  fontStyle: hasNote ? FontStyle.normal : FontStyle.italic,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.edit_outlined, size: 16, color: Colors.grey[500]),
          ],
        ),
      ),
    );
  }
}

class _CompletedSetTile extends StatelessWidget {
  final int setNumber;
  final int repsDone;
  final double weight;
  final String weightUnit;
  final bool isIsometric;

  const _CompletedSetTile({
    required this.setNumber,
    required this.repsDone,
    required this.weight,
    required this.weightUnit,
    this.isIsometric = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.green,
            child: Text(
              '$setNumber',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            isIsometric
                ? (weight > 0 ? '$repsDone s · $weight $weightUnit' : '$repsDone s')
                : '$repsDone reps · $weight $weightUnit',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
        ],
      ),
    );
  }
}

class _ActiveSetCard extends StatelessWidget {
  final int setNumber;
  final int totalSets;
  final String weightUnit;
  final TextEditingController weightCtrl;
  final TextEditingController repsCtrl;
  final int? rir;
  final bool isFailure;
  final bool isIsometric;
  final bool isoRunning;
  final int isoElapsed;
  final VoidCallback? onStartIsoTimer;
  final VoidCallback? onStopIsoTimer;

  const _ActiveSetCard({
    required this.setNumber,
    required this.totalSets,
    required this.weightUnit,
    required this.weightCtrl,
    required this.repsCtrl,
    this.rir,
    this.isFailure = false,
    this.isIsometric = false,
    this.isoRunning = false,
    this.isoElapsed = 0,
    this.onStartIsoTimer,
    this.onStopIsoTimer,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFailure ? Colors.red.shade700 : colorScheme.primary,
          width: 2,
        ),
        color: isFailure
            ? Colors.red.withValues(alpha: 0.06)
            : colorScheme.primaryContainer.withValues(alpha: 0.25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Serie $setNumber de $totalSets',
                  style: TextStyle(
                    color: isFailure ? Colors.red.shade700 : colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isFailure)
                const _FailureBadge()
              else if (rir != null)
                _RirBadge(rir: rir!),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Peso ($weightUnit)',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: weightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        hintText: '0',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isIsometric ? 'Tiempo (s)' : 'Reps',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    if (isIsometric)
                      _IsoTimerField(
                        controller: repsCtrl,
                        running: isoRunning,
                        elapsed: isoElapsed,
                        onStart: onStartIsoTimer,
                        onStop: onStopIsoTimer,
                      )
                    else
                      TextField(
                        controller: repsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Campo de "reps" para ejercicios isométricos: cronómetro con play/stop.
/// En reposo permite edición manual (fallback); corriendo, muestra el
/// conteo en vivo y al detenerlo escribe el tiempo transcurrido en [controller].
class _IsoTimerField extends StatelessWidget {
  final TextEditingController controller;
  final bool running;
  final int elapsed;
  final VoidCallback? onStart;
  final VoidCallback? onStop;

  const _IsoTimerField({
    required this.controller,
    required this.running,
    required this.elapsed,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (running) {
      return Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.primary),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${elapsed}s',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            InkWell(
              onTap: onStop,
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.stop_circle, color: Colors.red, size: 28),
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        InkWell(
          onTap: onStart,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Icon(Icons.play_circle_fill, color: colorScheme.primary, size: 32),
          ),
        ),
      ],
    );
  }
}

class _RirBadge extends StatelessWidget {
  final int rir;
  const _RirBadge({required this.rir});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'RIR $rir',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Indicador de "FALLO" estilo Mortal Kombat fatality.
class _FailureBadge extends StatelessWidget {
  const _FailureBadge();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFFE066),
          Color(0xFFFF1A1A),
          Color(0xFF7A0000),
        ],
        stops: [0.0, 0.55, 1.0],
      ).createShader(rect),
      child: const Text(
        'FALLO',
        style: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w900,
          letterSpacing: 4,
          height: 1,
          shadows: [
            Shadow(
              color: Colors.black87,
              offset: Offset(0, 2),
              blurRadius: 4,
            ),
            Shadow(
              color: Color(0xFFFF3B3B),
              offset: Offset(0, 0),
              blurRadius: 8,
            ),
          ],
        ),
      ),
    );
  }
}
