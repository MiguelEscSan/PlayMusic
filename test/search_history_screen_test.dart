import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/database/app_database.dart';
import 'package:sponify/features/search/data/search_history_dao.dart';
import 'package:sponify/features/search/data/search_source.dart';
import 'package:sponify/features/search/data/suggestion_source.dart';
import 'package:sponify/features/search/presentation/search_controller.dart';
import 'package:sponify/features/search/presentation/search_history_providers.dart';
import 'package:sponify/features/search/presentation/search_screen.dart';
import 'package:sponify/features/search/presentation/search_suggestions_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Búsqueda falsa sin resultados: así no hace falta reproductor ni BD de
/// canciones para pintar la pantalla.
class _FakeSearch implements SearchSource {
  final queries = <String>[];

  @override
  Future<SearchPage> search(String query) async {
    queries.add(query);
    return const SearchPage([], null);
  }
}

class _NoSuggestions implements SuggestionSource {
  @override
  Future<List<String>> suggestions(String query) async => const [];
}

void main() {
  sqfliteFfiInit();

  late AppDatabase db;
  late SearchHistoryDao history;
  late _FakeSearch search;

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    var now = DateTime(2026);
    history = SearchHistoryDao(
      db,
      clock: () => now = now.add(const Duration(seconds: 1)),
    );
    search = _FakeSearch();
  });

  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchSourceProvider.overrideWithValue(search),
          searchHistoryDaoProvider.overrideWithValue(history),
          suggestionSourceProvider.overrideWithValue(_NoSuggestions()),
        ],
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
    await settle(tester);
  }

  Future<List<String>> recent(WidgetTester tester) async =>
      (await tester.runAsync(history.recent))!;

  String fieldText(WidgetTester tester) =>
      tester.widget<SearchBar>(find.byType(SearchBar)).controller!.text;

  testWidgets('sin historial se ve el estado inicial', (tester) async {
    await pumpScreen(tester);
    expect(find.text('Busca cualquier canción'), findsOneWidget);
    expect(find.text('Búsquedas recientes'), findsNothing);
  });

  testWidgets('tocar una búsqueda reciente vuelve a buscarla', (tester) async {
    await tester.runAsync(() async {
      await history.record('rosalia');
      await history.record('quevedo');
    });
    await pumpScreen(tester);

    expect(find.text('Búsquedas recientes'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'quevedo'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'rosalia'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'rosalia'));
    await settle(tester);

    expect(search.queries, ['rosalia']);
    expect(fieldText(tester), 'rosalia');
    expect(find.text('Búsquedas recientes'), findsNothing);
    // Pasa a ser la más reciente.
    expect(await recent(tester), ['rosalia', 'quevedo']);
  });

  testWidgets('quitar una búsqueda y borrar todo', (tester) async {
    await tester.runAsync(() async {
      await history.record('rosalia');
      await history.record('quevedo');
    });
    await pumpScreen(tester);

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'quevedo'),
        matching: find.byTooltip('Quitar'),
      ),
    );
    await settle(tester);
    expect(find.widgetWithText(ListTile, 'quevedo'), findsNothing);
    expect(await recent(tester), ['rosalia']);

    await tester.tap(find.text('Borrar todo'));
    await settle(tester);
    expect(await recent(tester), isEmpty);
    expect(find.text('Búsquedas recientes'), findsNothing);
    expect(find.text('Busca cualquier canción'), findsOneWidget);
  });

  testWidgets('al enviar la búsqueda se guarda en el historial', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.enterText(find.byType(SearchBar), '  bad bunny ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);

    expect(search.queries, ['bad bunny']);
    expect(await recent(tester), ['bad bunny']);

    // Al vaciar el campo vuelve a verse la lista de recientes.
    await tester.tap(find.byTooltip('Borrar'));
    await settle(tester);
    expect(find.text('Búsquedas recientes'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'bad bunny'), findsOneWidget);
  });
}
