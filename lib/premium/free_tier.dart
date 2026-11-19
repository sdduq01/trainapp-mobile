import '../workout/models/routine.dart';

/// Qué incluye la versión gratis de TrainApp. Todo lo demás es premium.
class FreeTier {
  FreeTier._();

  static const String lightDutyId = 'trainapp_light_duty';
  static const String dutyId = 'trainapp_duty';
  static const String hardDutyId = 'trainapp_hard_duty';

  /// Únicas plantillas del catálogo disponibles sin premium.
  static const Set<String> routineTemplateIds = {
    lightDutyId,
    dutyId,
    hardDutyId,
  };

  /// Rutinas activadas antes de que existiera `Routine.templateId`: se
  /// reconocen por nombre.
  static const Set<String> _legacyRoutineNames = {
    'TrainApp Light Duty',
    'TrainApp Duty',
    'TrainApp Hard Duty',
  };

  /// Sesiones que se ven en el historial sin premium (las más recientes).
  static const int historySessions = 5;

  static bool isFreeTemplate(String templateId) =>
      routineTemplateIds.contains(templateId);

  static bool isFreeRoutine(Routine routine) {
    final id = routine.templateId;
    if (id != null) return isFreeTemplate(id);
    return _legacyRoutineNames.contains(routine.name);
  }

  /// La rutina gratis que corresponde a [daysPerWeek] días de entrenamiento.
  static String templateIdForDays(int? daysPerWeek) {
    final days = daysPerWeek ?? 4;
    if (days <= 3) return lightDutyId;
    if (days == 4) return dutyId;
    return hardDutyId;
  }
}
