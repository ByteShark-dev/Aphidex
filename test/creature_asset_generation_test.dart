import 'dart:convert';
import 'dart:io';

import 'package:aphidex/models/enemy.dart';
import 'package:flutter_test/flutter_test.dart';

const _languages = ['es', 'en', 'ru'];
const _games = ['g1', 'g2'];
const _allowedIndexKeys = {
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
  'mapMarkerAsset',
  'customAsset',
  'entityType',
  'hideHealth',
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
};
const _heavyIndexKeys = {
  'photo',
  'description',
  'behavior',
  'interactionWithPlayer',
  'interactionWithCreatures',
  'strategy',
  'attacks',
  'loot',
  'advancedLootTable',
  'abilities',
  'bossPhases',
  'combatStats',
};

void main() {
  test('generated indexes stay lightweight and complete', () {
    for (final language in _languages) {
      var combinedIndexBytes = 0;

      for (final game in _games) {
        final source = _readList('assets/data/enemies_$game.json');
        final indexFile = File(
          'assets/data/creatures/$language/index_$game.json',
        );

        expect(indexFile.existsSync(), isTrue, reason: indexFile.path);
        combinedIndexBytes += indexFile.lengthSync();

        final index = (jsonDecode(indexFile.readAsStringSync()) as List)
            .cast<Map<String, dynamic>>();
        final enabledSource = source
            .where((item) => item['enabled'] != false)
            .toList(growable: false);
        expect(
          index,
          hasLength(enabledSource.length),
          reason: '$language/$game',
        );

        for (final entry in index) {
          expect(entry.keys.toSet().difference(_allowedIndexKeys), isEmpty);
          expect(entry.keys.toSet().intersection(_heavyIndexKeys), isEmpty);
          expect(entry['name'], isA<String>());
          expect((entry['name'] as String).trim(), isNotEmpty);
        }
      }

      expect(
        combinedIndexBytes,
        lessThan(190 * 1024),
        reason:
            '$language index payload should stay within the expanded raid/wave startup budget',
      );
    }
  });

  test('generated details are localized and present for every creature', () {
    final sourceIds = <String>{
      for (final game in _games)
        for (final item in _readList('assets/data/enemies_$game.json'))
          if (item['enabled'] != false) item['id'] as String,
    };

    for (final language in _languages) {
      final detailsDir = Directory('assets/data/creatures/$language/details');
      expect(detailsDir.existsSync(), isTrue, reason: detailsDir.path);

      final detailFiles = detailsDir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'))
          .toList();
      expect(detailFiles, hasLength(sourceIds.length), reason: language);

      for (final id in sourceIds) {
        final file = File('${detailsDir.path}/$id.json');
        expect(file.existsSync(), isTrue, reason: file.path);

        final detail = jsonDecode(file.readAsStringSync());
        expect(_containsLocalizedMap(detail), isFalse, reason: file.path);
      }
    }
  });

  test('master and generated creature text does not keep mojibake markers', () {
    final files = <File>[
      for (final game in _games) File('assets/data/enemies_$game.json'),
      for (final language in _languages)
        for (final game in _games)
          File('assets/data/creatures/$language/index_$game.json'),
      for (final language in _languages)
        ...Directory(
          'assets/data/creatures/$language/details',
        ).listSync().whereType<File>(),
    ];

    for (final file in files) {
      expect(
        _hasQuestionMarkMojibake(file.readAsStringSync()),
        isFalse,
        reason: file.path,
      );
    }
  });

  test('spanish localization keeps key accented creature text', () {
    final g1 = _readList('assets/data/enemies_g1.json');
    final worker = Enemy.fromJson(
      g1.firstWhere((item) => item['id'] == 'g1_red_worker_ant'),
    );
    final ladybird = Enemy.fromJson(
      g1.firstWhere((item) => item['id'] == 'g1_ladybird'),
    );
    final generated = File(
      'assets/data/creatures/es/details/g2_masked_stranger_orc_waves.json',
    ).readAsStringSync();

    expect(ladybird.name.resolve('es'), 'Catarina negra');
    expect(
      worker.attacks.first.howToAvoid!.resolve('es'),
      contains('da\u00f1o'),
    );
    expect(worker.attacks.first.notes!.resolve('es'), contains('b\u00e1sico'));
    expect(worker.strategy!.resolve('es'), contains('s\u00ed'));

    expect(generated, contains('bot\u00edn espec\u00edfico'));
    expect(generated, contains('presi\u00f3n'));
    expect(generated, contains('qu\u00e9 criaturas'));
  });

  test(
    'special list icons and O.G.R.R. infusion images resolve to real assets',
    () {
      final g1 = _readList('assets/data/enemies_g1.json');
      final g2 = _readList('assets/data/enemies_g2.json');

      for (final id in [
        'g1_enemy_orc',
        'g1_enemy_infused',
        'g1_factional_raids',
        'g1_mixr_defenses',
        'g1_spicy_coaltana_event',
        'g1_javamatic_cable_defense',
        'g2_mixr_defenses',
        'g2_ice_sickles_event',
        'g2_masked_stranger_orc_waves',
      ]) {
        final source = id.startsWith('g1_') ? g1 : g2;
        final path = _entry(source, id)['listIconAsset'] as String?;
        expect(path, isNotNull, reason: id);
        expect(File(path!).existsSync(), isTrue, reason: path);
      }

      for (final id in [
        'g2_ogrr_blue_butterfly',
        'g2_ogrr_cricket',
        'g2_ogrr_ladybug',
        'g2_ogrr_northern_scorpion',
        'g2_ogrr_pincher_earwig',
        'g2_ogrr_praying_mantis_nymph',
        'g2_ogrr_rust_beetle',
        'g2_ogrr_wasp',
        'g2_ogrr_wasp_drone',
        'g2_ogrr_whipper_earwig',
        'g2_ogrr_wolf_spider',
      ]) {
        final entry = Enemy.fromJson(_entry(g2, id));
        for (final infusion in entry.infusions) {
          final imageAsset = infusion.imageAsset.trim();
          expect(imageAsset, isNotEmpty, reason: '${entry.id}:${infusion.id}');
          expect(File(imageAsset).existsSync(), isTrue, reason: imageAsset);
        }
      }
    },
  );
}

List<Map<String, dynamic>> _readList(String path) {
  return (jsonDecode(File(path).readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
}

Map<String, dynamic> _entry(List<Map<String, dynamic>> data, String id) {
  return data.firstWhere((item) => item['id'] == id);
}

bool _containsLocalizedMap(Object? value) {
  if (value is List) {
    return value.any(_containsLocalizedMap);
  }
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toSet();
    if (keys.isNotEmpty &&
        keys.every(_languages.contains) &&
        keys.any(_languages.contains)) {
      return true;
    }
    return value.values.any(_containsLocalizedMap);
  }
  return false;
}

bool _hasQuestionMarkMojibake(String text) {
  return RegExp(r'[A-Za-z]\?[A-Za-z]|\?[A-Za-z]').hasMatch(text);
}
