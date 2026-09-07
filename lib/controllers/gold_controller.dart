import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/creature_card_state.dart';
import '../data/local_storage.dart';
import '../models/creature_card_support.dart';

class GoldController {
  GoldController._() {
    reloadFromStorage();
  }

  static final GoldController instance = GoldController._();

  static const String _key = 'gold_cards';

  final ValueNotifier<Set<String>> gold = ValueNotifier<Set<String>>(
    <String>{},
  );
  final ValueNotifier<CreatureCardProgressMap> _progress =
      ValueNotifier<CreatureCardProgressMap>(<String, CreatureCardProgress>{});
  final Map<String, Set<String>> _knownLegacyIdsByKey = <String, Set<String>>{};
  final Map<String, Set<String>> _knownAliasesByKey = <String, Set<String>>{};
  Future<void> _writeQueue = Future<void>.value();

  ValueListenable<CreatureCardProgressMap> get progress => _progress;

  bool hasGold(String id) => gold.value.contains(id);

  bool needsMigration(Iterable<CreatureCardCarrier> enemies) {
    final migration = _buildMigration(enemies);
    return !_mapsEqual(migration.progress, _progress.value) ||
        !_setsEqual(migration.legacyGoldIds, gold.value);
  }

  CreatureCardProgress progressFor(CreatureCardCarrier enemy) {
    return resolveCreatureCardProgress(
      enemy,
      _progress.value,
      legacyGoldIds: gold.value,
    );
  }

  Future<void> toggle(String id) => toggleLinked([id]);

  Future<void> toggleLinked(Iterable<String?> ids) {
    final knownIds = _knownLegacyIdsByKey.values.expand((ids) => ids).toSet();
    final linkedIds = ids
        .whereType<String>()
        .map((id) => id.trim())
        .where(knownIds.contains)
        .toSet();
    if (linkedIds.isEmpty) {
      return Future<void>.value();
    }

    return _serialize(() async {
      final next = Set<String>.from(gold.value);
      final shouldRemove = linkedIds.any(next.contains);
      if (shouldRemove) {
        next.removeAll(linkedIds);
      } else {
        next.addAll(linkedIds);
      }
      gold.value = next;
      await LocalStorage.setStringSet(_key, next);
    });
  }

  Future<void> reset() {
    return _serialize(() async {
      gold.value = <String>{};
      _progress.value = <String, CreatureCardProgress>{};
      _knownLegacyIdsByKey.clear();
      _knownAliasesByKey.clear();
      await Future.wait([
        LocalStorage.setStringSet(_key, gold.value),
        LocalStorage.setString(
          creatureCardProgressStorageKey,
          encodeCreatureCardProgressMap(_progress.value),
        ),
      ]);
    });
  }

  Future<void> ensureMigrated(Iterable<CreatureCardCarrier> enemies) {
    final entries = enemies.toList(growable: false);
    return _serialize(() async {
      final migration = _buildMigration(entries);
      if (_mapsEqual(migration.progress, _progress.value) &&
          _setsEqual(migration.legacyGoldIds, gold.value)) {
        return;
      }

      _progress.value = migration.progress;
      gold.value = migration.legacyGoldIds;
      await Future.wait([
        LocalStorage.setString(
          creatureCardProgressStorageKey,
          encodeCreatureCardProgressMap(migration.progress),
        ),
        LocalStorage.setStringSet(_key, migration.legacyGoldIds),
      ]);
    });
  }

  Future<CreatureCardProgress> cycle(CreatureCardCarrier enemy) {
    return _serialize(() async {
      if (!_isValidCarrier(enemy)) {
        return CreatureCardProgress.unowned;
      }
      final next = nextCreatureCardProgress(enemy, progressFor(enemy));
      await _setProgressNow(enemy, next);
      return progressFor(enemy);
    });
  }

  Future<void> setProgress(
    CreatureCardCarrier enemy,
    CreatureCardProgress progress,
  ) {
    return _serialize(() => _setProgressNow(enemy, progress));
  }

  Future<void> _setProgressNow(
    CreatureCardCarrier enemy,
    CreatureCardProgress progress,
  ) async {
    final key = creatureCardProgressKeyOrNull(enemy);
    if (key == null || !shouldTrackCreatureCardProgress(enemy)) {
      return;
    }

    final normalized = normalizeCreatureCardProgress(enemy, progress);
    final next = Map<String, CreatureCardProgress>.from(_progress.value);
    if (normalized == CreatureCardProgress.unowned) {
      next.remove(key);
    } else {
      next[key] = normalized;
    }

    final linkedIds = <String>{
      ...?_knownLegacyIdsByKey[key],
      enemy.id.trim(),
      enemy.goldLinkId?.trim() ?? '',
    }..removeWhere((value) => value.isEmpty);
    final legacyNext = Set<String>.from(gold.value);
    legacyNext.removeAll(<String>{
      ...?_knownAliasesByKey[key],
      ...creatureCardLegacyAliases(enemy),
    });
    if (normalized == CreatureCardProgress.gold) {
      legacyNext.addAll(linkedIds);
    }

    _progress.value = next;
    gold.value = legacyNext;
    await Future.wait([
      LocalStorage.setString(
        creatureCardProgressStorageKey,
        encodeCreatureCardProgressMap(next),
      ),
      LocalStorage.setStringSet(_key, legacyNext),
    ]);
  }

  void reloadFromStorage() {
    gold.value = LocalStorage.getStringSet(_key);
    _progress.value = decodeCreatureCardProgressMap(
      LocalStorage.getString(creatureCardProgressStorageKey),
    );
  }

  _CardMigration _buildMigration(Iterable<CreatureCardCarrier> enemies) {
    final groups = <String, List<CreatureCardCarrier>>{};
    for (final enemy in enemies) {
      final key = creatureCardProgressKeyOrNull(enemy);
      if (key == null || !shouldTrackCreatureCardProgress(enemy)) {
        continue;
      }
      groups.putIfAbsent(key, () => <CreatureCardCarrier>[]).add(enemy);
    }

    final canonicalKeys = groups.keys.toSet();
    final next = Map<String, CreatureCardProgress>.from(_progress.value);
    final normalizedLegacy = Set<String>.from(gold.value);

    for (final group in groups.entries) {
      final aliases = <String>{};
      final legacyIds = <String>{};
      final obsoleteKeys = <String>{};
      for (final enemy in group.value) {
        aliases.addAll(creatureCardLegacyAliases(enemy));
        obsoleteKeys.addAll(creatureCardObsoleteProgressKeys(enemy));
        legacyIds
          ..add(enemy.id.trim())
          ..add(enemy.goldLinkId?.trim() ?? '');
      }
      legacyIds.removeWhere((value) => value.isEmpty);
      _knownLegacyIdsByKey[group.key] = legacyIds;
      _knownAliasesByKey[group.key] = aliases;

      CreatureCardProgress resolved = CreatureCardProgress.unowned;
      for (final alias in aliases) {
        final candidate = _progress.value[alias];
        if (candidate != null && _rank(candidate) > _rank(resolved)) {
          resolved = candidate;
        }
        if (gold.value.contains(alias)) {
          resolved = CreatureCardProgress.gold;
        }
      }
      resolved = _normalizeForGroup(group.value, resolved);

      for (final obsolete in obsoleteKeys) {
        if (obsolete != group.key && !canonicalKeys.contains(obsolete)) {
          next.remove(obsolete);
        }
      }
      if (resolved == CreatureCardProgress.unowned) {
        next.remove(group.key);
      } else {
        next[group.key] = resolved;
      }

      normalizedLegacy.removeAll(aliases);
      if (resolved == CreatureCardProgress.gold) {
        normalizedLegacy.addAll(legacyIds);
      }
    }

    return _CardMigration(progress: next, legacyGoldIds: normalizedLegacy);
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _writeQueue = _writeQueue.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  static bool _isValidCarrier(CreatureCardCarrier enemy) =>
      creatureCardProgressKeyOrNull(enemy) != null &&
      shouldTrackCreatureCardProgress(enemy);

  static int _rank(CreatureCardProgress progress) => switch (progress) {
    CreatureCardProgress.unowned => 0,
    CreatureCardProgress.obtained => 1,
    CreatureCardProgress.gold => 2,
  };

  static CreatureCardProgress _normalizeForGroup(
    Iterable<CreatureCardCarrier> enemies,
    CreatureCardProgress progress,
  ) {
    final hasNormal = enemies.any(creatureCardHasNormalVariant);
    final hasGold = enemies.any(creatureCardHasGoldVariant);
    return switch (progress) {
      CreatureCardProgress.unowned => CreatureCardProgress.unowned,
      CreatureCardProgress.obtained =>
        hasNormal
            ? CreatureCardProgress.obtained
            : hasGold
            ? CreatureCardProgress.gold
            : CreatureCardProgress.unowned,
      CreatureCardProgress.gold =>
        hasGold
            ? CreatureCardProgress.gold
            : hasNormal
            ? CreatureCardProgress.obtained
            : CreatureCardProgress.unowned,
    };
  }

  static bool _mapsEqual(
    CreatureCardProgressMap left,
    CreatureCardProgressMap right,
  ) {
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  static bool _setsEqual(Set<String> left, Set<String> right) =>
      left.length == right.length && left.containsAll(right);
}

class _CardMigration {
  const _CardMigration({required this.progress, required this.legacyGoldIds});

  final CreatureCardProgressMap progress;
  final Set<String> legacyGoldIds;
}
