/// Grupos musculares específicos usados para catalogar ejercicios y para el
/// selector en dos pasos (grupo muscular → ejercicio) en los menús de
/// rutina. Los ejercicios multiarticulares usan la zona principal que
/// entrenan (pecho, espalda, cuádriceps...) y los analíticos el músculo
/// puntual (bíceps, tríceps, gemelos...).
const Map<String, String> muscleGroupLabels = {
  'pecho': 'Pecho',
  'espalda': 'Espalda',
  'hombros': 'Hombros',
  'trapecios': 'Trapecios',
  'biceps': 'Bíceps',
  'triceps': 'Tríceps',
  'antebrazo': 'Antebrazo',
  'cuadriceps': 'Cuádriceps',
  'femorales': 'Femorales',
  'gluteos': 'Glúteos',
  'gemelos': 'Gemelos',
  'abductores': 'Abductores',
  'aductores': 'Aductores',
  'abdominales': 'Abdominales',
  'otros': 'Otros',
};

/// Orden de despliegue en los selectores (agrupado visualmente por zona:
/// tren superior empuje/tracción, brazos, tren inferior, core).
const List<String> muscleGroupOrder = [
  'pecho',
  'espalda',
  'hombros',
  'trapecios',
  'biceps',
  'triceps',
  'antebrazo',
  'cuadriceps',
  'femorales',
  'gluteos',
  'gemelos',
  'abductores',
  'aductores',
  'abdominales',
  'otros',
];
