import 'dart:convert';

import '../models/creature_card_support.dart';

enum CreatureCardProgress { unowned, obtained, gold }

extension CreatureCardProgressX on CreatureCardProgress {
  String get storageValue => switch (this) {
    CreatureCardProgress.unowned => 'unowned',
    CreatureCardProgress.obtained => 'obtained',
    CreatureCardProgress.gold => 'gold',
  };

  static CreatureCardProgress? fromStorageValue(String? value) {
    return switch (value?.trim()) {
      'unowned' => CreatureCardProgress.unowned,
      'obtained' => CreatureCardProgress.obtained,
      'gold' => CreatureCardProgress.gold,
      _ => null,
    };
  }
}

typedef CreatureCardProgressMap = Map<String, CreatureCardProgress>;

const String creatureCardProgressStorageKey = 'creature_card_progress_v2';

String? creatureCardProgressKeyOrNull(CreatureCardCarrier enemy) {
  final game = enemy.game.trim();
  final linkedId = enemy.goldLinkId?.trim() ?? '';
  final cardId = linkedId.isNotEmpty ? linkedId : enemy.id.trim();
  if (game.isEmpty || cardId.isEmpty) {
    return null;
  }
  return '$game:$cardId';
}

String creatureCardProgressKey(CreatureCardCarrier enemy) =>
    creatureCardProgressKeyOrNull(enemy) ?? '';

CreatureCardProgressMap decodeCreatureCardProgressMap(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return <String, CreatureCardProgress>{};
  }

  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return <String, CreatureCardProgress>{};
    }

    final entries = <String, CreatureCardProgress>{};
    for (final entry in decoded.entries) {
      final progress = CreatureCardProgressX.fromStorageValue(
        entry.value?.toString(),
      );
      if (progress == null) {
        continue;
      }
      entries[entry.key.toString()] = progress;
    }
    return entries;
  } catch (_) {
    return <String, CreatureCardProgress>{};
  }
}

String encodeCreatureCardProgressMap(CreatureCardProgressMap value) {
  final encoded = <String, String>{};
  for (final entry in value.entries) {
    encoded[entry.key] = entry.value.storageValue;
  }
  return jsonEncode(encoded);
}

bool creatureCardHasNormalVariant(CreatureCardCarrier enemy) {
  return (enemy.assetForCardVariant(CreatureCardVariant.normal) ?? '')
      .trim()
      .isNotEmpty;
}

bool creatureCardHasGoldVariant(CreatureCardCarrier enemy) {
  return (enemy.assetForCardVariant(CreatureCardVariant.gold) ?? '')
      .trim()
      .isNotEmpty;
}

bool shouldTrackCreatureCardProgress(CreatureCardCarrier enemy) {
  return enemy.hasCreatureCard &&
      (creatureCardHasNormalVariant(enemy) ||
          creatureCardHasGoldVariant(enemy));
}

Set<String> creatureCardLegacyAliases(CreatureCardCarrier enemy) {
  final game = enemy.game.trim();
  final id = enemy.id.trim();
  final linkedId = enemy.goldLinkId?.trim() ?? '';
  final aliases = <String>{
    id,
    creatureCardProgressKey(enemy),
    if (game.isNotEmpty && id.isNotEmpty) '$game:$id',
    linkedId,
    if (game.isNotEmpty && linkedId.isNotEmpty) '$game:$linkedId',
  }..removeWhere((value) => value.isEmpty);

  final expanded = <String>{...aliases};
  for (final alias in aliases) {
    for (final separator in const [':', '|', '/']) {
      final segments = alias.split(separator);
      if (segments.length != 2) {
        continue;
      }
      final left = segments.first.trim();
      final right = segments.last.trim();
      if (left.isNotEmpty && right.isNotEmpty) {
        expanded
          ..add(left)
          ..add(right);
      }
    }
  }
  return expanded;
}

Set<String> creatureCardObsoleteProgressKeys(CreatureCardCarrier enemy) {
  final game = enemy.game.trim();
  final id = enemy.id.trim();
  final linkedId = enemy.goldLinkId?.trim() ?? '';
  final keys = <String>{
    id,
    linkedId,
    if (game.isNotEmpty && id.isNotEmpty) ...{
      '$game:$id',
      '$game|$id',
      '$game/$id',
    },
    if (game.isNotEmpty && linkedId.isNotEmpty) ...{
      '$game:$linkedId',
      '$game|$linkedId',
      '$game/$linkedId',
    },
  }..removeWhere((value) => value.isEmpty);
  return keys;
}

CreatureCardProgress normalizeCreatureCardProgress(
  CreatureCardCarrier enemy,
  CreatureCardProgress progress,
) {
  if (!shouldTrackCreatureCardProgress(enemy)) {
    return CreatureCardProgress.unowned;
  }

  final hasNormal = creatureCardHasNormalVariant(enemy);
  final hasGold = creatureCardHasGoldVariant(enemy);

  switch (progress) {
    case CreatureCardProgress.unowned:
      return CreatureCardProgress.unowned;
    case CreatureCardProgress.obtained:
      if (hasNormal) {
        return CreatureCardProgress.obtained;
      }
      return CreatureCardProgress.unowned;
    case CreatureCardProgress.gold:
      if (hasGold) {
        return CreatureCardProgress.gold;
      }
      if (hasNormal) {
        return CreatureCardProgress.obtained;
      }
      return CreatureCardProgress.unowned;
  }
}

CreatureCardProgress nextCreatureCardProgress(
  CreatureCardCarrier enemy,
  CreatureCardProgress current,
) {
  final normalized = normalizeCreatureCardProgress(enemy, current);
  final hasNormal = creatureCardHasNormalVariant(enemy);
  final hasGold = creatureCardHasGoldVariant(enemy);

  if (!hasNormal && !hasGold) {
    return CreatureCardProgress.unowned;
  }
  if (hasNormal && hasGold) {
    return switch (normalized) {
      CreatureCardProgress.unowned => CreatureCardProgress.obtained,
      CreatureCardProgress.obtained => CreatureCardProgress.gold,
      CreatureCardProgress.gold => CreatureCardProgress.unowned,
    };
  }
  if (hasNormal) {
    return switch (normalized) {
      CreatureCardProgress.unowned => CreatureCardProgress.obtained,
      CreatureCardProgress.obtained ||
      CreatureCardProgress.gold => CreatureCardProgress.unowned,
    };
  }
  return switch (normalized) {
    CreatureCardProgress.unowned ||
    CreatureCardProgress.obtained => CreatureCardProgress.gold,
    CreatureCardProgress.gold => CreatureCardProgress.unowned,
  };
}

CreatureCardProgress? resolveLegacyCreatureCardProgress(
  CreatureCardCarrier enemy,
  CreatureCardProgressMap progressByKey, {
  Set<String> legacyGoldIds = const <String>{},
}) {
  if (!shouldTrackCreatureCardProgress(enemy)) {
    return null;
  }

  final hasNormal = creatureCardHasNormalVariant(enemy);
  final hasGold = creatureCardHasGoldVariant(enemy);
  final aliases = creatureCardLegacyAliases(enemy);

  CreatureCardProgress? legacyProgress;
  for (final alias in aliases) {
    final stored = progressByKey[alias];
    if (stored == null) {
      continue;
    }
    legacyProgress = stored;
    if (stored == CreatureCardProgress.gold) {
      break;
    }
    if (stored == CreatureCardProgress.obtained && hasNormal) {
      break;
    }
  }

  final legacyMarked = aliases.any((alias) => legacyGoldIds.contains(alias));
  if (legacyMarked) {
    if (hasGold) {
      return CreatureCardProgress.gold;
    }
    if (hasNormal) {
      return CreatureCardProgress.obtained;
    }
    return null;
  }

  if (legacyProgress == null) {
    return null;
  }
  if (legacyProgress == CreatureCardProgress.gold) {
    if (hasGold) {
      return CreatureCardProgress.gold;
    }
    if (hasNormal) {
      return CreatureCardProgress.obtained;
    }
    return null;
  }
  if (legacyProgress == CreatureCardProgress.obtained) {
    if (hasNormal) {
      return CreatureCardProgress.obtained;
    }
    if (hasGold) {
      return CreatureCardProgress.gold;
    }
    return null;
  }
  return CreatureCardProgress.unowned;
}

CreatureCardProgress migrateLegacyCreatureCardProgress(
  CreatureCardCarrier enemy,
  CreatureCardProgressMap progressByKey, {
  Set<String>? legacyGoldIds,
}) {
  if (!shouldTrackCreatureCardProgress(enemy)) {
    return CreatureCardProgress.unowned;
  }

  return normalizeCreatureCardProgress(
    enemy,
    resolveLegacyCreatureCardProgress(
          enemy,
          progressByKey,
          legacyGoldIds: legacyGoldIds ?? const <String>{},
        ) ??
        CreatureCardProgress.unowned,
  );
}

CreatureCardProgress resolveCreatureCardProgress(
  CreatureCardCarrier enemy,
  CreatureCardProgressMap progressByKey, {
  Set<String> legacyGoldIds = const <String>{},
}) {
  if (!shouldTrackCreatureCardProgress(enemy)) {
    return CreatureCardProgress.unowned;
  }

  final key = creatureCardProgressKeyOrNull(enemy);
  if (key == null) {
    return CreatureCardProgress.unowned;
  }
  final stored = progressByKey[key];
  if (stored != null) {
    return normalizeCreatureCardProgress(enemy, stored);
  }
  return migrateLegacyCreatureCardProgress(
    enemy,
    progressByKey,
    legacyGoldIds: legacyGoldIds,
  );
}

CreatureCardVariant? resolveCreatureCardVariant(
  CreatureCardCarrier enemy,
  CreatureCardProgress progress,
) {
  if (!shouldTrackCreatureCardProgress(enemy)) {
    return null;
  }

  final normalized = normalizeCreatureCardProgress(enemy, progress);
  if (normalized == CreatureCardProgress.gold &&
      creatureCardHasGoldVariant(enemy)) {
    return CreatureCardVariant.gold;
  }
  if (creatureCardHasNormalVariant(enemy)) {
    return CreatureCardVariant.normal;
  }
  if (creatureCardHasGoldVariant(enemy)) {
    return CreatureCardVariant.gold;
  }
  return null;
}

String? resolveCreatureCardAsset(
  CreatureCardCarrier enemy,
  CreatureCardProgress progress,
) {
  final variant = resolveCreatureCardVariant(enemy, progress);
  if (variant == null) {
    return null;
  }
  return enemy.assetForCardVariant(variant);
}
