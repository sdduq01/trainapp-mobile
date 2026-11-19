import '../workout/models/routine.dart';
import '../workout/models/routine_template.dart';
import '../workout/services/routine_template_service.dart';

/// Qué incluye la versión gratis de TrainApp. Todo lo demás es premium.
class FreeTier {
  FreeTier._();

  static const String lightDutyId = 'trainapp_light_duty';
  static const String dutyId = 'trainapp_duty';
  static const String hardDutyId = 'trainapp_hard_duty';

  /// Categoría del catálogo disponible sin premium: todas las Recomendadas
  /// (TrainApp, calistenia, crossfit, en casa...). Deportes, edición
  /// limitada, macro ciclos y Top Secret son premium.
  static const String freeCategory = 'recommended';

  /// Top Secret se gana completando el macro ciclo (que es premium): sus
  /// rutinas quedan disponibles aunque luego no se tenga premium.
  static const String earnedCategory = 'secret';

  /// Sesiones que se ven en el historial sin premium (las más recientes).
  static const int historySessions = 5;

  static bool isFreeTemplate(RoutineTemplate template) =>
      template.category == freeCategory || template.category == earnedCategory;

  static Future<List<RoutineTemplate>>? _freeTemplates;

  /// Plantillas gratis (Recomendadas), en el orden del catálogo. Se cachean
  /// durante la sesión; si la consulta falla se reintenta la próxima vez.
  static Future<List<RoutineTemplate>> freeTemplates() {
    return _freeTemplates ??= RoutineTemplateService()
        .getByCategory(freeCategory)
        .catchError((Object e) {
      _freeTemplates = null;
      throw e;
    });
  }

  /// ¿La rutina activa salió de una plantilla gratis? Las rutinas activadas
  /// antes de que existiera `Routine.templateId` se reconocen por nombre.
  static Future<bool> isFreeRoutine(Routine routine) async {
    final free = await freeTemplates();
    final id = routine.templateId;
    if (id == null) return free.any((t) => t.name == routine.name);
    if (free.any((t) => t.id == id)) return true;
    final template = await RoutineTemplateService().getById(id);
    return template != null && isFreeTemplate(template);
  }

  /// La rutina gratis que corresponde a [daysPerWeek] días de entrenamiento.
  static String templateIdForDays(int? daysPerWeek) {
    final days = daysPerWeek ?? 4;
    if (days <= 3) return lightDutyId;
    if (days == 4) return dutyId;
    return hardDutyId;
  }
}
