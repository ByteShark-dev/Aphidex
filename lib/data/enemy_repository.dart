import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/enemy.dart';
import '../models/enemy_index_entry.dart';
import '../startup/startup_profiler.dart';

class EnemyRepository {
  static final Map<String, Future<List<EnemyIndexEntry>>> _gameFutures = {};
  static final Map<String, Future<List<EnemyIndexEntry>>> _allFutures = {};
  static final Map<String, Enemy> _detailCache = {};
  static final Map<String, Future<Enemy>> _detailFutures = {};

  static Future<List<EnemyIndexEntry>> loadAll(String languageCode) async {
    final language = _normalizedLanguageCode(languageCode);
    return _allFutures.putIfAbsent(language, () => _loadAllInternal(language));
  }

  static Future<List<EnemyIndexEntry>> loadGame(
    String game,
    String languageCode,
  ) {
    final language = _normalizedLanguageCode(languageCode);
    switch (game) {
      case 'g1':
        return _gameFutures.putIfAbsent(
          '$language/g1',
          () => _loadIndexFile('assets/data/creatures/$language/index_g1.json'),
        );
      case 'g2':
        return _gameFutures.putIfAbsent(
          '$language/g2',
          () => _loadIndexFile('assets/data/creatures/$language/index_g2.json'),
        );
      default:
        return loadAll(language);
    }
  }

  static Future<Enemy> loadDetail(String game, String id, String languageCode) {
    if (game != 'g1' && game != 'g2') {
      throw ArgumentError.value(game, 'game', 'Expected g1 or g2');
    }
    if (!id.startsWith('${game}_')) {
      throw StateError('Enemy ID $id does not belong to $game');
    }
    final language = _normalizedLanguageCode(languageCode);
    final cacheKey = '$language/$game/$id';
    final cached = _detailCache[cacheKey];
    if (cached != null) {
      return SynchronousFuture(cached);
    }

    return _detailFutures.putIfAbsent(cacheKey, () async {
      try {
        final path = 'assets/data/creatures/$language/details/$id.json';
        final raw = await rootBundle.loadString(path);
        final decoded = await compute(_decodeEnemyDetailJsonMap, raw);
        final enemy = Enemy.fromJson(decoded);
        if (enemy.game != game || enemy.id != id) {
          throw StateError(
            'Enemy detail identity mismatch: requested $game/$id, '
            'loaded ${enemy.game}/${enemy.id}',
          );
        }
        _detailCache[cacheKey] = enemy;
        return enemy;
      } catch (error) {
        throw StateError('Failed to load enemy detail $id ($language): $error');
      } finally {
        _detailFutures.remove(cacheKey);
      }
    });
  }

  static void warmUpGame(String game, String languageCode) {
    unawaited(loadGame(game, languageCode));
  }

  @visibleForTesting
  static void clearCaches() {
    _gameFutures.clear();
    _allFutures.clear();
    _detailCache.clear();
    _detailFutures.clear();
  }

  static Future<List<EnemyIndexEntry>> _loadAllInternal(String language) async {
    final g1 = await loadGame('g1', language);
    final g2 = await loadGame('g2', language);
    return [...g1, ...g2];
  }

  static Future<List<EnemyIndexEntry>> _loadIndexFile(String path) async {
    try {
      final raw = await rootBundle.loadString(path);
      final decoded = await compute(_decodeEnemyJsonMaps, raw);
      StartupProfiler.instance.mark('G1/G2 index read/parse ready: $path');
      StartupProfiler.instance.markOnce('repository/data init ready');
      return decoded.map(EnemyIndexEntry.fromJson).toList(growable: false);
    } catch (error) {
      throw StateError('Failed to load enemy index from $path: $error');
    }
  }

  static String _normalizedLanguageCode(String languageCode) {
    final code = languageCode.toLowerCase();
    return switch (code) {
      'es' || 'en' || 'ru' => code,
      _ => 'en',
    };
  }
}

List<Map<String, dynamic>> _decodeEnemyJsonMaps(String raw) {
  final List<dynamic> data = json.decode(raw) as List<dynamic>;
  return data
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

Map<String, dynamic> _decodeEnemyDetailJsonMap(String raw) {
  final decoded = json.decode(raw) as Map<dynamic, dynamic>;
  return Map<String, dynamic>.from(decoded);
}
