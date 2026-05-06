import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/routine.dart';
import '../models/workout_session.dart';
import '../services/session_service.dart';

class WorkoutSessionPage extends StatefulWidget {
  final RoutineDay day;

  const WorkoutSessionPage({required this.day, super.key});

  @override
  State<WorkoutSessionPage> createState() => _WorkoutSessionPageState();
}

class _WorkoutSessionPageState extends State<WorkoutSessionPage> {
  final _userId = FirebaseAuth.instance.currentUser!.uid;
  final _audioPlayer = AudioPlayer();

  int _exerciseIndex = 0;
  int _setIndex = 0;

  // [exerciseIndex][setIndex] = (repsDone, weight) | null
  late List<List<(int, double)?>> _logged;

  late TextEditingController _weightCtrl;
  late TextEditingController _repsCtrl;

  bool _resting = false;
  bool _restExpired = false;
  int _restRemaining = 0;
  Timer? _timer;
  VoidCallback? _afterRest;

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

  // Genera un WAV con 3 pitidos (150ms·80ms·150ms·80ms·300ms) a 880 Hz
  static Uint8List _generateBeepWav() {
    const sampleRate = 22050;
    const hz = 880.0;
    const durations = [0.15, 0.08, 0.15, 0.08, 0.30];
    const isTone   = [true, false, true, false, true];

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

  // ── Ciclo de vida ─────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _logged = widget.day.exercises
        .map((e) => List<(int, double)?>.filled(e.sets, null))
        .toList();
    _initControllers();
  }

  void _initControllers() {
    final ex = _currentExercise;
    _weightCtrl = TextEditingController(
      text: ex.currentWeight > 0 ? ex.currentWeight.toString() : '',
    );
    _repsCtrl = TextEditingController(text: ex.repsMax.toString());
  }

  void _disposeControllers() {
    _weightCtrl.dispose();
    _repsCtrl.dispose();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    super.dispose();
  }

  // ── Timer de descanso ─────────────────────────────────────

  void _startCountdown(int seconds) {
    _timer?.cancel();
    setState(() { _restRemaining = seconds; _restExpired = false; });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_restRemaining <= 1) {
        t.cancel();
        setState(() { _restExpired = true; _restRemaining = 0; });
        _playAlarm();
      } else {
        setState(() => _restRemaining--);
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

  // ── Avance de ejercicio ───────────────────────────────────

  void _completeSet() {
    final ex = _currentExercise;
    final repsDone = int.tryParse(_repsCtrl.text) ?? ex.repsMax;
    final weight   = double.tryParse(_weightCtrl.text) ?? ex.currentWeight;

    setState(() => _logged[_exerciseIndex][_setIndex] = (repsDone, weight));

    if (_isLastSet && _isLastExercise) {
      _startRest(ex.restSeconds, onDone: _finishSession);
    } else if (_isLastSet) {
      _startRest(ex.restSeconds, onDone: _advanceExercise);
    } else {
      _startRest(ex.restSeconds, onDone: _advanceSet);
    }
  }

  void _advanceSet() {
    final prevWeight =
        _logged[_exerciseIndex][_setIndex]?.$2 ?? _currentExercise.currentWeight;
    setState(() => _setIndex++);
    _repsCtrl.text   = _currentExercise.repsMax.toString();
    _weightCtrl.text = prevWeight > 0 ? prevWeight.toString() : '';
  }

  void _advanceExercise() {
    _disposeControllers();
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

    await SessionService().saveSession(session);

    if (!mounted) return;
    setState(() => _saving = false);
    _showCompletionDialog();
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
                  '${ex.sets} series · ${ex.repsMin}–${ex.repsMax} reps · ${ex.restSeconds}s descanso',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 28),

                for (int s = 0; s < _setIndex; s++) ...[
                  _CompletedSetTile(
                    setNumber: s + 1,
                    repsDone: _logged[_exerciseIndex][s]!.$1,
                    weight: _logged[_exerciseIndex][s]!.$2,
                    weightUnit: ex.weightUnit,
                  ),
                  const SizedBox(height: 8),
                ],

                _ActiveSetCard(
                  setNumber: _setIndex + 1,
                  totalSets: ex.sets,
                  weightUnit: ex.weightUnit,
                  weightCtrl: _weightCtrl,
                  repsCtrl: _repsCtrl,
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

class _CompletedSetTile extends StatelessWidget {
  final int setNumber;
  final int repsDone;
  final double weight;
  final String weightUnit;

  const _CompletedSetTile({
    required this.setNumber,
    required this.repsDone,
    required this.weight,
    required this.weightUnit,
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
            '$repsDone reps · $weight $weightUnit',
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

  const _ActiveSetCard({
    required this.setNumber,
    required this.totalSets,
    required this.weightUnit,
    required this.weightCtrl,
    required this.repsCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary, width: 2),
        color: colorScheme.primaryContainer.withValues(alpha: 0.25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Serie $setNumber de $totalSets',
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
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
                      'Reps',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(height: 4),
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
