import 'package:koda/core/domain/entities/last_playback.dart';
import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/domain/repositories/i_settings_repository.dart';
import 'package:koda/core/error/failure.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/features/history/domain/i_history_repository.dart';
import 'package:koda/features/search/domain/i_search_history_repository.dart';

/// Ajustes en memoria. Si [failure] no es null, todas las operaciones
/// devuelven `Err(failure)`.
class FakeSettingsRepository implements ISettingsRepository {
  bool radioEnabled = true;
  bool downloadOnlyWifi = false;
  String? likedPlaylistId;
  Failure? failure;

  Future<Result<T>> _run<T>(T Function() action) async {
    if (failure case final f?) return Err(f);
    return Ok(action());
  }

  @override
  Future<Result<bool>> getRadioEnabled() => _run(() => radioEnabled);

  @override
  Future<Result<Unit>> setRadioEnabled(bool enabled) => _run(() {
    radioEnabled = enabled;
    return unit;
  });

  @override
  Future<Result<bool>> getDownloadOnlyWifi() => _run(() => downloadOnlyWifi);

  @override
  Future<Result<Unit>> setDownloadOnlyWifi(bool enabled) => _run(() {
    downloadOnlyWifi = enabled;
    return unit;
  });

  @override
  Future<Result<String?>> getLikedPlaylistId() => _run(() => likedPlaylistId);

  @override
  Future<Result<Unit>> setLikedPlaylistId(String id) => _run(() {
    likedPlaylistId = id;
    return unit;
  });

  LastPlayback? lastPlayback;

  @override
  Future<Result<LastPlayback?>> getLastPlayback() =>
      _run(() => lastPlayback);

  @override
  Future<Result<Unit>> setLastPlayback(LastPlayback playback) => _run(() {
    lastPlayback = playback;
    return unit;
  });
}

/// Historial en memoria: [recent] y [top] se devuelven tal cual.
class FakeHistoryRepository implements IHistoryRepository {
  FakeHistoryRepository({this.recent = const [], this.top = const []});

  List<Song> recent;
  List<Song> top;
  Failure? failure;
  final recorded = <Song>[];
  int clearCalls = 0;
  int recentCalls = 0;
  int topCalls = 0;

  Future<Result<T>> _run<T>(T Function() action) async {
    if (failure case final f?) return Err(f);
    return Ok(action());
  }

  @override
  Future<Result<List<Song>>> recentSongs() => _run(() {
    recentCalls++;
    return recent;
  });

  @override
  Future<Result<List<Song>>> topSongs() => _run(() {
    topCalls++;
    return top;
  });

  @override
  Future<Result<Unit>> record(Song song) => _run(() {
    recorded.add(song);
    return unit;
  });

  @override
  Future<Result<Unit>> clear() => _run(() {
    clearCalls++;
    recent = const [];
    top = const [];
    return unit;
  });
}

/// Búsquedas recientes en memoria, la última primero.
class FakeSearchHistoryRepository implements ISearchHistoryRepository {
  FakeSearchHistoryRepository([List<String>? queries])
    : queries = queries ?? [];

  final List<String> queries;
  Failure? failure;

  Future<Result<T>> _run<T>(T Function() action) async {
    if (failure case final f?) return Err(f);
    return Ok(action());
  }

  @override
  Future<Result<List<String>>> recent() => _run(() => List.of(queries));

  @override
  Future<Result<Unit>> record(String query) => _run(() {
    queries
      ..remove(query)
      ..insert(0, query);
    return unit;
  });

  @override
  Future<Result<Unit>> remove(String query) => _run(() {
    queries.remove(query);
    return unit;
  });

  @override
  Future<Result<Unit>> clear() => _run(() {
    queries.clear();
    return unit;
  });
}
