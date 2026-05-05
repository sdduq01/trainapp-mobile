import '../data/exercise_catalog.dart';
import '../models/exercise.dart';
import '../models/routine.dart';
import '../../profile/models/user_profile.dart';

class RoutineGenerator {
  static Routine generate(UserProfile profile) {
    final days = profile.trainingDaysPerWeek ?? 4;
    final months = profile.trainingExperienceMonths ?? 0;
    final isAdvanced = months >= 12;
    final userId = profile.uid;

    if (days <= 3) return _ppl3(userId, isAdvanced);
    if (days == 4) return _upperLower4(userId, isAdvanced);
    if (days == 5) return _ppl5(userId, isAdvanced);
    return _ppl6(userId, isAdvanced);
  }

  // ── PPL 3 días ──────────────────────────────────────────
  static Routine _ppl3(String userId, bool advanced) {
    return Routine(
      userId: userId,
      type: 'PPL',
      name: 'PPL · 3 días',
      weekNumber: 1,
      createdAt: DateTime.now(),
      days: [
        _pushDay(1, advanced ? 6 : 5),
        _pullDay(2, advanced ? 6 : 5),
        _legsDay(3, advanced ? 6 : 5),
      ],
    );
  }

  // ── Upper / Lower 4 días ────────────────────────────────
  static Routine _upperLower4(String userId, bool advanced) {
    return Routine(
      userId: userId,
      type: 'UpperLower',
      name: 'Upper/Lower · 4 días',
      weekNumber: 1,
      createdAt: DateTime.now(),
      days: [
        _upperDay(1, 'A', advanced ? 6 : 5),
        _lowerDay(2, 'A', advanced ? 5 : 4),
        _upperDay(3, 'B', advanced ? 6 : 5),
        _lowerDay(4, 'B', advanced ? 5 : 4),
      ],
    );
  }

  // ── PPL 5 días ──────────────────────────────────────────
  static Routine _ppl5(String userId, bool advanced) {
    return Routine(
      userId: userId,
      type: 'PPL',
      name: 'PPL · 5 días',
      weekNumber: 1,
      createdAt: DateTime.now(),
      days: [
        _pushDay(1, advanced ? 6 : 5),
        _pullDay(2, advanced ? 6 : 5),
        _legsDay(3, advanced ? 6 : 5),
        _upperDay(4, '', advanced ? 6 : 5),
        _lowerDay(5, '', advanced ? 5 : 4),
      ],
    );
  }

  // ── PPL 6 días ──────────────────────────────────────────
  static Routine _ppl6(String userId, bool advanced) {
    return Routine(
      userId: userId,
      type: 'PPL',
      name: 'PPL · 6 días',
      weekNumber: 1,
      createdAt: DateTime.now(),
      days: [
        _pushDay(1, advanced ? 7 : 6),
        _pullDay(2, advanced ? 7 : 6),
        _legsDay(3, advanced ? 6 : 5),
        _pushDay(4, advanced ? 7 : 6),
        _pullDay(5, advanced ? 7 : 6),
        _legsDay(6, advanced ? 6 : 5),
      ],
    );
  }

  // ── Constructores de días ────────────────────────────────

  static RoutineDay _pushDay(int number, int count) {
    final push = byMuscle('push');
    return RoutineDay(
      dayNumber: number,
      name: 'Push',
      focus: 'push',
      exercises: _pick(push, [
        'press_banca',
        'press_militar',
        'elev_laterales',
        'press_inclinado',
        'ext_triceps_cable',
        'fondos_triceps',
        'aperturas_cable',
      ], count),
    );
  }

  static RoutineDay _pullDay(int number, int count) {
    final pull = byMuscle('pull');
    return RoutineDay(
      dayNumber: number,
      name: 'Pull',
      focus: 'pull',
      exercises: _pick(pull, [
        'jalon_pecho',
        'remo_barra',
        'face_pull',
        'remo_mancuerna',
        'curl_barra',
        'curl_martillo',
        'remo_cable',
      ], count),
    );
  }

  static RoutineDay _legsDay(int number, int count) {
    final legs = byMuscle('legs');
    return RoutineDay(
      dayNumber: number,
      name: 'Legs',
      focus: 'legs',
      exercises: _pick(legs, [
        'sentadilla',
        'peso_muerto_rumano',
        'prensa_piernas',
        'curl_isquio',
        'ext_cuadriceps',
        'elev_talones',
        'zancadas',
      ], count),
    );
  }

  static RoutineDay _upperDay(int number, String suffix, int count) {
    final push = byMuscle('push');
    final pull = byMuscle('pull');
    final exercises = [
      ..._pick(push, ['press_banca', 'press_militar', 'elev_laterales'], 3),
      ..._pick(pull, ['jalon_pecho', 'remo_barra', 'curl_barra'], count - 3),
    ];
    return RoutineDay(
      dayNumber: number,
      name: suffix.isEmpty ? 'Upper' : 'Upper $suffix',
      focus: 'upper',
      exercises: exercises,
    );
  }

  static RoutineDay _lowerDay(int number, String suffix, int count) {
    final legs = byMuscle('legs');
    return RoutineDay(
      dayNumber: number,
      name: suffix.isEmpty ? 'Lower' : 'Lower $suffix',
      focus: 'lower',
      exercises: _pick(legs, [
        'sentadilla',
        'peso_muerto_rumano',
        'prensa_piernas',
        'curl_isquio',
        'elev_talones',
      ], count),
    );
  }

  // Toma ejercicios en el orden de `ids`, máximo `count`
  static List<RoutineExercise> _pick(
    List<Exercise> catalog,
    List<String> ids,
    int count,
  ) {
    final result = <RoutineExercise>[];
    for (final id in ids) {
      if (result.length >= count) break;
      final ex = catalog.where((e) => e.id == id).firstOrNull;
      if (ex == null) continue;
      result.add(RoutineExercise(
        exerciseId: ex.id,
        name: ex.name,
        sets: ex.defaultSets,
        repsMin: ex.defaultRepsMin,
        repsMax: ex.defaultRepsMax,
        restSeconds: ex.restSeconds,
        weightUnit: ex.defaultWeightUnit,
        progressionStep: ex.defaultProgressionStep,
      ));
    }
    return result;
  }
}
