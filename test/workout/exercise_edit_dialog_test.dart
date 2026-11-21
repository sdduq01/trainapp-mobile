import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainapp_mobile/workout/models/routine.dart';
import 'package:trainapp_mobile/workout/widgets/exercise_edit_dialog.dart';

const press = RoutineExercise(
  exerciseId: 'press',
  name: 'Press en máquina',
  sets: 3,
  repsMin: 8,
  repsMax: 12,
  currentWeight: 9,
  weightUnit: 'unidades',
  restSeconds: 90,
);

/// Abre el diálogo y devuelve un getter con lo que retornó al cerrarse.
Future<RoutineExercise? Function()> open(WidgetTester tester,
    {bool editWeight = true}) async {
  RoutineExercise? result;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () async => result =
            await showExerciseEditDialog(context, press, editWeight: editWeight),
        child: const Text('abrir'),
      ),
    ),
  ));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return () => result;
}

void main() {
  testWidgets('corrige el peso sugerido', (tester) async {
    final result = await open(tester);
    expect(find.widgetWithText(TextField, '9'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '6');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(result()!.currentWeight, 6);
    expect(result()!.sets, 3);
  });

  testWidgets('acepta coma decimal', (tester) async {
    final result = await open(tester);
    await tester.enterText(find.byType(TextField), '6,5');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(result()!.currentWeight, 6.5);
  });

  testWidgets('rechaza un peso inválido sin cerrar', (tester) async {
    final result = await open(tester);
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Peso no válido'), findsOneWidget);
    expect(result(), isNull);
  });

  testWidgets('sin editWeight no muestra el campo y conserva el peso',
      (tester) async {
    final result = await open(tester, editWeight: false);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(result()!.currentWeight, 9);
  });
}
