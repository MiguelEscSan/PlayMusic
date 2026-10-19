import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koda/core/database/app_database.dart';
import 'package:koda/di/providers.dart';
import 'package:koda/features/search/data/search_history_dao.dart';
import 'package:koda/core/domain/sources/i_track_search.dart';
import 'package:koda/features/search/domain/suggestion_source.dart';
import 'package:koda/features/search/presentation/search_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeSearch implements ITrackSearch {
  final queries = <String>[];

  @override
  Future<SearchPage> search(String query) async {
    queries.add(query);
    return const SearchPage([], null);
  }
}

class _FakeSuggestions implements SuggestionSource {
  _FakeSuggestions({this.fail = false});

  final bool fail;
  final queries = <String>[];

  @override
  Future<List<String>> suggestions(String query) async {
    queries.add(query);
    if (fail) throw Exception('sin red');
    return ['$query uno', '$query dos'];
  }
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
    history = SearchHistoryDao(db);
    search = _FakeSearch();
  });

  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpScreen(WidgetTester tester, SuggestionSource source) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trackSearchProvider.overrideWithValue(search),
          searchHistoryDaoProvider.overrideWithValue(history),
          suggestionSourceProvider.overrideWithValue(source),
        ],
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
    await settle(tester);
  }

  testWidgets('al escribir aparecen sugerencias tras el debounce', (
    tester,
  ) async {
    final source = _FakeSuggestions();
    await pumpScreen(tester, source);

    await tester.enterText(find.byType(SearchBar), 'r');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(SearchBar), 'ros');
    await tester.pump(const Duration(milliseconds: 100));
    expect(source.queries, isEmpty, reason: 'aún dentro del debounce');

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(source.queries, ['ros'], reason: 'una sola petición');
    expect(find.widgetWithText(ListTile, 'ros uno'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'ros dos'), findsOneWidget);
    // Escribir no lanza la búsqueda: solo sugiere.
    expect(search.queries, isEmpty);
  });

  testWidgets('tocar una sugerencia busca y la guarda', (tester) async {
    await pumpScreen(tester, _FakeSuggestions());

    await tester.enterText(find.byType(SearchBar), 'ros');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.tap(find.widgetWithText(ListTile, 'ros dos'));
    await settle(tester);

    expect(search.queries, ['ros dos']);
    expect(
      tester.widget<SearchBar>(find.byType(SearchBar)).controller!.text,
      'ros dos',
    );
    expect(find.widgetWithText(ListTile, 'ros uno'), findsNothing);
    expect(await tester.runAsync(history.recent), ['ros dos']);
  });

  testWidgets('si las sugerencias fallan no se muestra nada', (tester) async {
    final source = _FakeSuggestions(fail: true);
    await pumpScreen(tester, source);

    await tester.enterText(find.byType(SearchBar), 'ros');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(source.queries, ['ros']);
    expect(find.byType(ListTile), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
