import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/database/app_database.dart';
import 'package:sponify/core/settings/settings_dao.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late AppDatabase db;
  late SettingsDao settings;

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    settings = SettingsDao(db);
  });

  tearDown(() => db.close());

  test('sin valor guardado devuelve el valor por defecto', () async {
    expect(await settings.getBool('x', fallback: true), isTrue);
    expect(await settings.getBool('x', fallback: false), isFalse);
  });

  test('guarda y sobrescribe booleanos', () async {
    await settings.setBool('x', false);
    expect(await settings.getBool('x', fallback: true), isFalse);
    await settings.setBool('x', true);
    expect(await settings.getBool('x', fallback: false), isTrue);
  });

  test('avisa de los cambios', () async {
    final changed = settings.changes.first;
    await settings.setBool(SettingsKeys.radioEnabled, false);
    await changed;
  });
}
