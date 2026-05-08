/// Tipo de progresión asignado a un ejercicio dentro de una rutina.
///
/// `none` — el usuario edita pesos manualmente, sin sugerencias ni RIR.
/// `doubleLinear` — peso constante todos los sets a RIR 1; sube cuando ≥90%
/// de los sets alcanzan repsMax. Cada N semanas el último set es FALLO (RIR 0).
/// `pyramid` — RIR descendente desde 3, peso ascendente set a set si el
/// anterior cumplió repsMax. Overload: cumplir todos los sets subiendo peso.
/// `reversePyramid` — peso descendente y reps ascendentes set a set, RIR 1
/// → 0 a la mitad. Overload: cumplir el set 1 (peso máximo, repsMin, RIR 1).
enum ProgressionType {
  none,
  doubleLinear,
  pyramid,
  reversePyramid,
}

extension ProgressionTypeX on ProgressionType {
  String get id => switch (this) {
        ProgressionType.none           => 'none',
        ProgressionType.doubleLinear   => 'doubleLinear',
        ProgressionType.pyramid        => 'pyramid',
        ProgressionType.reversePyramid => 'reversePyramid',
      };

  String get label => switch (this) {
        ProgressionType.none           => 'Sin progresión',
        ProgressionType.doubleLinear   => 'Doble lineal',
        ProgressionType.pyramid        => 'Piramidal',
        ProgressionType.reversePyramid => 'Piramidal invertida',
      };

  /// Si los ejercicios con este tipo deben mostrar RIR cuando el toggle de
  /// intensidad está activo.
  bool get showsRir => this != ProgressionType.none;

  static ProgressionType fromId(String? id) => switch (id) {
        'none'           => ProgressionType.none,
        'pyramid'        => ProgressionType.pyramid,
        'reversePyramid' => ProgressionType.reversePyramid,
        _                => ProgressionType.doubleLinear,
      };
}
