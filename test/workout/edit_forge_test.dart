import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainapp_mobile/workout/data/macrocycle_forjado.dart';
import 'package:trainapp_mobile/workout/models/routine.dart';
import 'package:trainapp_mobile/workout/screens/edit_routine_page.dart';

void main() {
  Routine forge({bool extra = false}) {
    final base = ForjadoPorElHierro.routineForPhase('u1', 1);
    if (!extra) return base;
    return base.copyWith(days: [
      ...base.days,
      const RoutineDay(dayNumber: 5, name: 'Cardio', focus: 'cardio', exercises: []),
    ]);
  }

  Future<void> open(WidgetTester tester, Routine r) async {
    tester.view.physicalSize = const Size(1080, 40000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: EditRoutinePage(routine: r)));
    await tester.pumpAndSettle();
  }

  testWidgets('forja: días base sin borrar, se pueden agregar días', (tester) async {
    await open(tester, forge());
    expect(find.byTooltip('Eliminar día'), findsNothing);
    expect(find.text('Agregar día'), findsOneWidget);
    expect(find.textContaining('Puedes agregar días extra'), findsOneWidget);
  });

  testWidgets('forja: un día extra se puede borrar y se marca como extra',
      (tester) async {
    await open(tester, forge(extra: true));
    expect(find.byTooltip('Eliminar día'), findsOneWidget);
    expect(find.textContaining('Día extra'), findsOneWidget);
  });
}
