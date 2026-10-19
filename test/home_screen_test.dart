import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koda/features/home/home_screen.dart';
import 'package:koda/features/home/home_sections.dart';

Future<void> _pump(WidgetTester tester, List<HomeSection> sections) =>
    tester.pumpWidget(
      ProviderScope(
        overrides: [homeSectionsProvider.overrideWithValue(sections)],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

void main() {
  testWidgets('sin secciones muestra un estado vacío', (tester) async {
    await _pump(tester, const []);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Aquí aparecerá tu música'), findsOneWidget);
  });

  testWidgets('si ninguna sección tiene contenido muestra el estado vacío', (
    tester,
  ) async {
    final hidden = Provider<bool>((ref) => false);
    await _pump(tester, [
      HomeSection(
        id: 'vacia',
        order: 10,
        hasContent: hidden,
        builder: (_) => const Text('No debería verse'),
      ),
    ]);

    expect(find.text('Aquí aparecerá tu música'), findsOneWidget);
    expect(find.text('No debería verse'), findsNothing);
  });

  testWidgets('pinta las secciones registradas por orden', (tester) async {
    await _pump(tester, [
      HomeSection(id: 'b', order: 20, builder: (_) => const Text('Segunda')),
      HomeSection(id: 'a', order: 10, builder: (_) => const Text('Primera')),
    ]);

    expect(find.text('Aquí aparecerá tu música'), findsNothing);
    final first = tester.getTopLeft(find.text('Primera')).dy;
    final second = tester.getTopLeft(find.text('Segunda')).dy;
    expect(first, lessThan(second));
  });

  testWidgets('el botón de ajustes abre la pantalla de Ajustes', (
    tester,
  ) async {
    await _pump(tester, const []);
    await tester.tap(find.byTooltip('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Ajustes'), findsOneWidget);
  });
}
