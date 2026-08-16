import 'dart:convert';
import 'dart:io';

const _languages = ['es', 'en', 'ru'];
const _sourceFiles = {
  'g1': 'assets/data/enemies_g1.json',
  'g2': 'assets/data/enemies_g2.json',
};
const _outputRoot = 'assets/data/creatures';
const _indexFields = [
  'id',
  'speciesKey',
  'game',
  'name',
  'tier',
  'danger',
  'underConstruction',
  'isBoss',
  'order',
  'defaultGold',
  'favoriteKey',
  'goldLinkId',
  'cardNormal',
  'cardGold',
  'listIconAsset',
  'hasCreatureCard',
  'hasGoldCreatureCard',
  'hasSelectableCardVariants',
  'defaultCardVariant',
  'weaknesses',
  'resistances',
  'temperament',
  'health',
  'collectionGroup',
  'technicalId',
  'bestiaryId',
  'cardTier',
  'bossCardStyle',
  'groupId',
];

void main() {
  final outputRoot = Directory(_outputRoot);
  if (outputRoot.existsSync()) {
    outputRoot.deleteSync(recursive: true);
  }

  final sources = <String, List<Map<String, dynamic>>>{};
  for (final entry in _sourceFiles.entries) {
    final file = File(entry.value);
    if (!file.existsSync()) {
      throw StateError('Missing source file: ${entry.value}');
    }

    final decoded = jsonDecode(file.readAsStringSync()) as List<dynamic>;
    final normalizedSource = _canonicalizeGameSource(
      _normalizeValue(decoded) as List<dynamic>,
      game: entry.key,
    );
    final normalizedJson = jsonEncode(normalizedSource);
    if (file.readAsStringSync() != normalizedJson) {
      file.writeAsStringSync(normalizedJson);
    }

    sources[entry.key] = normalizedSource
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList(growable: false);
  }

  for (final language in _languages) {
    final languageDir = Directory('$_outputRoot/$language');
    final detailsDir = Directory('${languageDir.path}/details');
    detailsDir.createSync(recursive: true);

    for (final source in sources.entries) {
      final index = <Map<String, dynamic>>[];

      for (final creature in source.value) {
        final normalized = _withDerivedCardFields(creature);
        if (normalized['enabled'] == false) {
          continue;
        }
        index.add(_buildIndexEntry(normalized, language));
        final detail = _localizeValue(normalized, language);
        final id = creature['id'] as String?;
        if (id == null || id.trim().isEmpty) {
          throw StateError(
            'Creature without id in ${_sourceFiles[source.key]}',
          );
        }
        _writeJson(File('${detailsDir.path}/$id.json'), detail);
      }

      _writeJson(File('${languageDir.path}/index_${source.key}.json'), index);
    }
  }
}

List<dynamic> _canonicalizeGameSource(
  List<dynamic> source, {
  required String game,
}) {
  if (game != 'g2') {
    return source;
  }

  return source
      .map((item) {
        if (item is! Map) {
          return item;
        }

        final creature = Map<String, dynamic>.from(
          item.cast<String, dynamic>(),
        );
        final isUnderConstruction = creature['underConstruction'] == true;
        final danger = creature['danger']?.toString().trim().toLowerCase();
        creature['danger'] = isUnderConstruction
            ? 'proximamente'
            : switch (danger) {
                'media' => 'intermedia',
                'imposible_alt' || 'imposible_alta' => 'imposible_superior',
                _ => danger,
              };
        return creature;
      })
      .toList(growable: false);
}

Map<String, dynamic> _buildIndexEntry(
  Map<String, dynamic> creature,
  String language,
) {
  final entry = <String, dynamic>{};
  for (final field in _indexFields) {
    if (!creature.containsKey(field)) {
      continue;
    }
    final value = creature[field];
    entry[field] = field == 'name' ? _localizeValue(value, language) : value;
  }
  return entry;
}

Map<String, dynamic> _withDerivedCardFields(Map<String, dynamic> creature) {
  final normalized = Map<String, dynamic>.from(creature);
  final normal = _validatedCardPath(
    creature['cardNormal'],
    creatureId: normalized['id']?.toString() ?? '<unknown>',
    fieldName: 'cardNormal',
  );
  final gold = _validatedCardPath(
    creature['cardGold'],
    creatureId: normalized['id']?.toString() ?? '<unknown>',
    fieldName: 'cardGold',
  );
  final listIcon = _validatedAssetPath(
    creature['listIconAsset'],
    creatureId: normalized['id']?.toString() ?? '<unknown>',
    fieldName: 'listIconAsset',
  );

  final hasNormal = normal.isNotEmpty;
  final hasGold = gold.isNotEmpty;
  normalized['cardNormal'] = normal;
  normalized['cardGold'] = gold;
  normalized['listIconAsset'] = listIcon;
  normalized['hasCreatureCard'] = hasNormal || hasGold;
  normalized['hasGoldCreatureCard'] = hasGold;
  normalized['hasSelectableCardVariants'] = hasNormal && hasGold;
  normalized['defaultCardVariant'] = hasNormal
      ? 'normal'
      : hasGold
      ? 'gold'
      : null;
  return normalized;
}

String _validatedCardPath(
  dynamic raw, {
  required String creatureId,
  required String fieldName,
}) {
  return _validatedAssetPath(raw, creatureId: creatureId, fieldName: fieldName);
}

String _validatedAssetPath(
  dynamic raw, {
  required String creatureId,
  required String fieldName,
}) {
  final path = raw?.toString().trim() ?? '';
  if (path.isEmpty) {
    return '';
  }
  if (!File(path).existsSync()) {
    throw StateError(
      'Missing creature card asset for $creatureId ($fieldName): $path',
    );
  }
  return path;
}

dynamic _localizeValue(dynamic value, String language) {
  if (value is List) {
    return value.map((item) => _localizeValue(item, language)).toList();
  }

  if (value is Map) {
    final map = value.cast<String, dynamic>();
    final keys = map.keys.toSet();
    final isLocalizedMap =
        keys.isNotEmpty &&
        keys.every(_languages.contains) &&
        keys.any(_languages.contains);

    if (isLocalizedMap) {
      for (final code in [language, 'es', 'en', 'ru']) {
        final localized = map[code];
        if (localized != null && localized.toString().trim().isNotEmpty) {
          return localized.toString();
        }
      }
      return '';
    }

    return {
      for (final entry in map.entries)
        entry.key: _localizeValue(entry.value, language),
    };
  }

  if (value is String) {
    return _repairText(value);
  }

  return value;
}

dynamic _normalizeValue(dynamic value) {
  if (value is List) {
    return value.map(_normalizeValue).toList();
  }
  if (value is Map) {
    return {
      for (final entry in value.entries)
        entry.key.toString(): _normalizeValue(entry.value),
    };
  }
  if (value is String) {
    return _repairText(value);
  }
  return value;
}

String _repairText(String value) {
  var current = value;
  while (true) {
    final repaired = _repairUtf8Mojibake(current);
    if (repaired == current) {
      return current;
    }
    current = repaired;
  }
}

String _repairUtf8Mojibake(String value) {
  if (!_looksMojibake(value)) {
    return value;
  }

  try {
    final repaired = utf8.decode(_encodeWindows1252(value));
    return _mojibakeScore(repaired) < _mojibakeScore(value) ? repaired : value;
  } on FormatException {
    return value;
  }
}

List<int> _encodeWindows1252(String value) {
  const cp1252 = {
    0x20AC: 0x80,
    0x201A: 0x82,
    0x0192: 0x83,
    0x201E: 0x84,
    0x2026: 0x85,
    0x2020: 0x86,
    0x2021: 0x87,
    0x02C6: 0x88,
    0x2030: 0x89,
    0x0160: 0x8A,
    0x2039: 0x8B,
    0x0152: 0x8C,
    0x017D: 0x8E,
    0x2018: 0x91,
    0x2019: 0x92,
    0x201C: 0x93,
    0x201D: 0x94,
    0x2022: 0x95,
    0x2013: 0x96,
    0x2014: 0x97,
    0x02DC: 0x98,
    0x2122: 0x99,
    0x0161: 0x9A,
    0x203A: 0x9B,
    0x0153: 0x9C,
    0x017E: 0x9E,
    0x0178: 0x9F,
  };

  final bytes = <int>[];
  for (final rune in value.runes) {
    if (rune <= 0xFF) {
      bytes.add(rune);
      continue;
    }
    final mapped = cp1252[rune];
    if (mapped == null) {
      throw const FormatException('Cannot encode rune as Windows-1252');
    }
    bytes.add(mapped);
  }
  return bytes;
}

bool _looksMojibake(String value) {
  return value.contains('Ã') ||
      value.contains('Â') ||
      value.contains('Ð') ||
      value.contains('Ñ') ||
      value.contains('â');
}

int _mojibakeScore(String value) {
  var score = 0;
  const suspicious = ['Ã', 'Â', 'Ð', 'Ñ', 'â', '�'];
  for (final token in suspicious) {
    score += token.allMatches(value).length;
  }
  return score;
}

void _writeJson(File file, Object? data) {
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(jsonEncode(data));
}
