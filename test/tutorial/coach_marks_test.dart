import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainapp_mobile/onboarding/tutorial/coach_marks.dart';

void main() {
  final a = GlobalKey(), b = GlobalKey(), missing = GlobalKey();
  bool? result;

  Future<void> open(WidgetTester t) async {
    t.view.physicalSize = const Size(360 * 3, 760 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    result = null;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        appBar: AppBar(actions: [IconButton(key: a, icon: const Icon(Icons.history), onPressed: () {})]),
        body: ListView(children: [
          const SizedBox(height: 900),
          Card(key: b, child: const ListTile(title: Text('Día 1'))),
        ]),
      ),
    ));
    final ctx = t.element(find.byType(Scaffold));
    CoachMarks.show(ctx, [
      CoachMarkStep(target: a, circle: true, title: 'Historial', body: 'Tus sesiones.'),
      CoachMarkStep(target: missing, title: 'No está', body: '—'),
      CoachMarkStep(target: b, title: 'Tu día', body: 'Entrena aquí.'),
    ]).then((r) => result = r);
    await t.pumpAndSettle();
  }

  testWidgets('recorre los pasos visibles y desplaza hasta el elemento', (t) async {
    await open(t);
    expect(find.text('Historial'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget); // el paso sin elemento se omite
    await t.tap(find.text('Siguiente'));
    await t.pumpAndSettle();
    expect(find.text('Tu día'), findsOneWidget);
    // Se desplazó: el card quedó en pantalla.
    final y = t.getTopLeft(find.byKey(b)).dy;
    expect(y, inInclusiveRange(0, 760));
    await t.tap(find.text('Atrás'));
    await t.pumpAndSettle();
    expect(find.text('Historial'), findsOneWidget);
    await t.tap(find.text('Siguiente'));
    await t.pumpAndSettle();
    await t.tap(find.text('Terminar'));
    await t.pumpAndSettle();
    expect(result, isTrue);
    expect(find.text('Tu día'), findsNothing);
  });

  testWidgets('se puede omitir', (t) async {
    await open(t);
    await t.tap(find.text('Omitir'));
    await t.pumpAndSettle();
    expect(result, isFalse);
    expect(find.text('Historial'), findsNothing);
  });

  testWidgets('atrás cierra el tutorial, no la pantalla', (t) async {
    await open(t);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(result, isFalse);
    expect(find.text('Historial'), findsNothing);
    expect(find.byIcon(Icons.history), findsOneWidget); // la pantalla sigue
  });
}
