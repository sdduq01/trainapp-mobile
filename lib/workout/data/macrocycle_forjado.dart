import '../models/progression_type.dart';
import '../models/routine.dart';

/// "Forjado por el Hierro" — macro ciclo de ~1 año.
///
/// Los días 1–3 son fijos todo el año; solo el **Día 4** rota su énfasis a lo
/// largo de 6 fases. Una fase se cierra cuando el usuario registra
/// [sessionsPerDay] sesiones completas de **cada uno** de los 4 días (sin
/// atajos: no basta con machacar el Día 4). Al cerrar la fase 6 se marca
/// `forjadoHierroCompletado` en el perfil y se abre la pestaña Top Secret.
class ForjadoPorElHierro {
  ForjadoPorElHierro._();

  static const String templateId = 'macro_forjado_hierro';
  static const String routineName = 'Forjado por el Hierro';
  static const String routineType = 'Macrocycle';

  /// Sesiones necesarias de cada día para cerrar una fase.
  static const int sessionsPerDay = 8;

  /// Días de la rutina que cuentan para el avance de fase: los 4 (no se puede
  /// hacer trampa machacando solo el Día 4).
  static const List<int> trackedDays = [1, 2, 3, 4];

  /// Énfasis del Día 4 en cada fase (índice 0 = fase 1). Dos fases de cada
  /// énfasis, en rotación para no repetir el mismo dos veces seguidas.
  static const List<String> emphases = [
    'Pierna',
    'Brazos',
    'Abdomen',
    'Brazos',
    'Abdomen',
    'Pierna',
  ];

  /// Mínimo de ejercicios por día exigido al editar la rutina del macro ciclo.
  static const int minExercisesPerDay = 4;

  /// Anti-trampa: por cada día del calendario, como máximo estas sesiones
  /// cuentan para la forja (no se puede completar el macro ciclo entrando y
  /// cerrando sesiones sin entrenar de verdad; el descanso es parte del progreso).
  static const int maxCountedSessionsPerDay = 2;

  static int get totalPhases => emphases.length;

  /// Sesiones para cerrar una fase (todos los días) y para todo el macro ciclo.
  static int get sessionsPerPhase => sessionsPerDay * trackedDays.length; // 32
  static int get totalSessions => sessionsPerPhase * totalPhases; // 192

  static RoutineExercise _ex(
    String id,
    String name, {
    int sets = 3,
    int repsMin = 6,
    int repsMax = 10,
    int rest = 180,
    double step = 2.5,
    ProgressionType progression = ProgressionType.doubleLinear,
    bool isometric = false,
  }) => RoutineExercise(
    exerciseId: id,
    name: name,
    sets: sets,
    repsMin: repsMin,
    repsMax: repsMax,
    currentWeight: 0,
    restSeconds: rest,
    weightUnit: 'kg',
    progressionStep: step,
    progressionType: progression,
    isIsometric: isometric,
  );

  /// Días 1–3: la base fija que no cambia en todo el macro ciclo.
  static List<RoutineDay> baseDays() => [
    RoutineDay(
      dayNumber: 1,
      name: 'Pecho Espalda',
      focus: 'push',
      exercises: [
        _ex('press_banca', 'Press de Banca', step: 5),
        _ex('press_inclinado_hammer', 'Press Inclinado en Hammer'),
        _ex('aperturas_pec_dec', 'Aperturas en Pec Dec'),
        _ex('dominadas_lastradas', 'Dominadas Lastradas'),
        _ex('pull_over', 'Pull Over'),
      ],
    ),
    RoutineDay(
      dayNumber: 2,
      name: 'Pierna 1',
      focus: 'legs',
      exercises: [
        _ex('sentadilla_smith', 'Sentadilla en Smith', rest: 240, step: 10),
        _ex('prensa', 'Prensa de Piernas', step: 10),
        _ex('curl_femoral_sentado', 'Curl Femoral Sentado en Máquina'),
        _ex('peso_muerto_rumano', 'Peso Muerto Rumano', step: 10),
        _ex('extension_pantorrila', 'Extensión de Pantorrilla'),
      ],
    ),
    RoutineDay(
      dayNumber: 3,
      name: 'Espalda Pecho',
      focus: 'pull',
      exercises: [
        _ex('jalones_pecho', 'Jalones al Pecho'),
        _ex('remo_en_t', 'Remo en T'),
        _ex('remo_gironda', 'Remo en Gironda'),
        _ex('cruces_poleas', 'Cruces en Poleas'),
        _ex('fondos_lastrados', 'Fondos Lastrados'),
      ],
    ),
  ];

  /// Día 4 según el énfasis de la fase.
  ///   Pierna  → segundo día de pierna (cuádriceps, femoral, glúteo, gemelo).
  ///   Brazos  → hombro y brazos (press militar, laterales, bíceps, tríceps).
  ///   Abdomen → core a 3×12-20 / 60s (plancha isométrica).
  static RoutineDay day4ForEmphasis(String emphasis) => switch (emphasis) {
    'Brazos' => RoutineDay(
      dayNumber: 4,
      name: 'Hombro y Brazos',
      focus: 'upper',
      exercises: [
        _ex('press_militar', 'Press Militar'),
        _ex(
          'elevacion_lateral_mancuerna',
          'Elevación Lateral con Mancuerna',
          step: 1.25,
        ),
        _ex('curl_bayesiano', 'Curl Bayesiano'),
        _ex('curl_barra', 'Curl con Barra'),
        _ex('extension_triceps', 'Extensión de Tríceps'),
        _ex('extension_katana', 'Extensión Katana'),
      ],
    ),
    'Abdomen' => RoutineDay(
      dayNumber: 4,
      name: 'Abdomen',
      focus: 'core',
      exercises: [
        _ex(
          'elevacion_piernas_colgado',
          'Elevación de Piernas Colgado',
          repsMin: 12,
          repsMax: 20,
          rest: 60,
          step: 1,
        ),
        _ex(
          'rueda_abdominal',
          'Rueda Abdominal',
          repsMin: 12,
          repsMax: 20,
          rest: 60,
          step: 1,
        ),
        _ex(
          'crunch_abdominal_polea',
          'Crunch Abdominal en Polea Alta',
          repsMin: 12,
          repsMax: 20,
          rest: 60,
          step: 2.5,
        ),
        _ex(
          'giro_oblicuo_polea',
          'Giro Oblicuo en Polea',
          repsMin: 12,
          repsMax: 20,
          rest: 60,
          step: 2.5,
        ),
        _ex(
          'plancha',
          'Plancha',
          repsMin: 30,
          repsMax: 60,
          rest: 60,
          step: 1,
          progression: ProgressionType.none,
          isometric: true,
        ),
      ],
    ),
    _ => RoutineDay(
      dayNumber: 4,
      name: 'Pierna 2',
      focus: 'legs',
      exercises: [
        _ex('sentadilla_hack', 'Sentadilla Hack', rest: 240, step: 10),
        _ex('extension_cuadriceps', 'Extensión de Cuádriceps', step: 10),
        _ex('curl_femoral_sentado', 'Curl Femoral Sentado en Máquina'),
        _ex('hip_thrust', 'Hip Thrust', step: 10),
        _ex('extension_pantorrila', 'Extensión de Pantorrilla'),
      ],
    ),
  };

  static RoutineDay day4ForPhase(int phaseIndex) =>
      day4ForEmphasis(emphases[phaseIndex]);

  /// Rutina completa para una fase (días 1–3 + Día 4 del énfasis).
  static Routine routineForPhase(String userId, int phaseIndex) => Routine(
    userId: userId,
    type: routineType,
    name: routineName,
    weekNumber: 1,
    createdAt: DateTime.now(),
    days: [...baseDays(), day4ForPhase(phaseIndex)],
  );
}
