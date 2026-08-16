import 'dart:convert';
import 'dart:io';

import 'package:aphidex/data/enemy_variants.dart';
import 'package:aphidex/data/ui_mapper.dart';
import 'package:aphidex/models/enemy.dart';
import 'package:aphidex/models/enemy_index_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<Map<String, dynamic>> loadMaster() =>
      (jsonDecode(File('assets/data/enemies_g2.json').readAsStringSync())
              as List<dynamic>)
          .cast<Map<String, dynamic>>();

  List<EnemyIndexEntry> loadIndex({String game = 'g2'}) {
    final rows =
        jsonDecode(
              File(
                'assets/data/creatures/en/index_$game.json',
              ).readAsStringSync(),
            )
            as List<dynamic>;
    return rows
        .cast<Map<String, dynamic>>()
        .map(EnemyIndexEntry.fromJson)
        .toList(growable: false);
  }

  Enemy loadDetail(String id, {String language = 'en'}) => Enemy.fromJson(
    jsonDecode(
          File(
            'assets/data/creatures/$language/details/$id.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>,
  );

  test('tier zero stays logical tier one and uses its G2 visual asset', () {
    final aphid = loadDetail('g2_aphid');

    expect(aphid.tier, 1);
    expect(aphid.cardTier, 0);
    expect(
      UiMapper.tierIcon(
        tier: aphid.tier,
        isBoss: aphid.isBoss,
        game: aphid.game,
        cardTier: aphid.cardTier,
      ),
      'assets/g2/tier_icons/G2_tier_0.png',
    );
    expect(
      UiMapper.tierIcon(tier: 1, isBoss: false, game: 'g1'),
      'assets/global/CreatureTier1.webp',
    );
  });

  test('G2 boss styles resolve eliminable red and invulnerable yellow', () {
    final axl = loadDetail('g2_axl');
    final crow = loadDetail('g2_crow');

    expect(axl.bossCardStyle, BossCardStyle.red);
    expect(crow.bossCardStyle, BossCardStyle.yellow);
    expect(crow.isKillable, isFalse);
    expect(
      UiMapper.tierIcon(
        tier: crow.tier,
        isBoss: crow.isBoss,
        game: crow.game,
        bossCardStyle: crow.bossCardStyle,
      ),
      'assets/g2/tier_icons/G2_tier_boss_V.png',
    );
  });

  test('only the 20 Named C.R.O. rows become typed encounter variants', () {
    final enemies = loadIndex().map((entry) => loadDetail(entry.id));
    final variants = enemies
        .expand((enemy) => enemy.encounterVariants)
        .toList();

    expect(variants, hasLength(20));
    expect(variants.every((variant) => variant.isNamed), isTrue);
    expect(variants.every((variant) => variant.health?.value != null), isTrue);
    expect(variants.every((variant) => variant.attacks.isNotEmpty), isTrue);
  });

  test('Koi quick-navigation group has four independent G2 entries', () {
    final koi = loadIndex().where((entry) => entry.groupId == 'koi').toList();

    expect(koi.map((entry) => entry.id).toSet(), {
      'g2_koi_sunny',
      'g2_koi_calico',
      'g2_koi_oriole',
      'g2_koi_dagon',
    });
    expect(koi.every((entry) => entry.game == 'g2'), isTrue);
    expect(
      koi.every((entry) => entry.bossCardStyle == BossCardStyle.yellow),
      isTrue,
    );
  });

  test('Toe-biter Buggie keeps unverified stats empty', () {
    final buggy = loadDetail('g2_buggy_toe_biter');

    expect(buggy.collectionGroup, 'buggy');
    expect(buggy.health, isNull);
    expect(buggy.attacks, isEmpty);
    expect(buggy.cardNormal, loadDetail('g2_toe_biter_nymph').cardNormal);
  });

  test('unresolved attack damage is explicitly unidentified', () {
    EnemyAttack unresolved(String language) =>
        loadDetail(
          'g2_bombardier_beetle',
          language: language,
        ).attacks.singleWhere(
          (attack) => attack.name.resolve(language) == 'BeetleAOE',
        );

    expect(unresolved('es').notes?.resolve('es'), 'Sin identificar');
    expect(unresolved('en').notes?.resolve('en'), 'Unidentified');
    expect(unresolved('ru').notes?.resolve('ru'), 'Не идентифицировано');
  });

  test('alternate capture names resolve to the intended G2 entries', () {
    const mappedIds = {
      'g2_green_shield_bug',
      'g2_ogrr_toe_biter_leviathan',
      'g2_papa_toe_biter',
      'g2_toe_biter',
      'g2_toe_biter_leviathan',
      'g2_toe_biter_nymph',
    };

    for (final id in mappedIds) {
      final enemy = loadDetail(id);
      expect(enemy.photo, 'assets/g2/creatures/photos/v4_4_$id.png');
      expect(File(enemy.photo).existsSync(), isTrue);
    }
  });

  test('C.R.O. and scorpion raid waves are active', () {
    final waves = loadMaster()
        .where((entry) => entry['isRaidWave'] == true)
        .toList(growable: false);
    final active = waves
        .where((entry) => entry['enabled'] == true)
        .toList(growable: false);
    final disabled = waves
        .where((entry) => entry['enabled'] == false)
        .toList(growable: false);
    final indexedIds = loadIndex().map((entry) => entry.id).toSet();
    const activeScorpionWaveIds = {
      'g2_wave_scorpion_northern_wave',
      'g2_wave_scorpion_jr_northern_wave',
      'g2_wave_scorpling_northern_wave',
    };

    expect(waves, hasLength(50));
    expect(active, hasLength(40));
    expect(disabled, hasLength(10));
    expect(
      active.every(
        (entry) =>
            (entry['parentId'] as String).startsWith('g2_orc_') ||
            activeScorpionWaveIds.contains(entry['id']),
      ),
      isTrue,
    );
    expect(activeScorpionWaveIds.every(indexedIds.contains), isTrue);
    expect(active.every((entry) => indexedIds.contains(entry['id'])), isTrue);
    expect(disabled.any((entry) => indexedIds.contains(entry['id'])), isFalse);
  });

  test('new matching G2 insects join their unchanged G1 Shared entries', () {
    final g1 =
        (jsonDecode(File('assets/data/enemies_g1.json').readAsStringSync())
                as List<dynamic>)
            .cast<Map<String, dynamic>>();
    final g2 = loadMaster();
    const pairs = {
      'g2_diving_bell_spider': 'g1_diving_bell_spider',
      'g2_green_shield_bug': 'g1_green_shield_bug',
      'g2_spiny_water_flea': 'g1_spiny_water_flea',
      'g2_tadpole': 'g1_tadpole',
      'g2_tick': 'g1_tick',
      'g2_tiger_mosquito': 'g1_tiger_mosquito',
      'g2_water_boatman': 'g1_water_boatman',
      'g2_water_flea': 'g1_water_flea',
    };

    for (final pair in pairs.entries) {
      final g1Entry = g1.singleWhere((entry) => entry['id'] == pair.value);
      final g2Entry = g2.singleWhere((entry) => entry['id'] == pair.key);
      expect(g2Entry['speciesKey'], g1Entry['speciesKey'], reason: pair.key);
    }

    final grouped = groupEnemyIndexEntries([
      ...loadIndex(game: 'g1'),
      ...loadIndex(),
    ], mergeSharedSpecies: true);
    for (final pair in pairs.entries) {
      final speciesKey = g2.singleWhere(
        (entry) => entry['id'] == pair.key,
      )['speciesKey'];
      final shared = grouped.singleWhere(
        (entry) => entry.speciesKey == speciesKey,
      );
      expect(shared.variants.map((entry) => entry.game).toSet(), {'g1', 'g2'});
      expect(shared.variants, hasLength(2), reason: pair.key);
    }

    expect(
      g2.singleWhere(
        (entry) => entry['id'] == 'g2_orc_green_shield_bug',
      )['speciesKey'],
      isNot('g1_green_shield_bug'),
    );
    final sharedKoi = grouped.singleWhere(
      (entry) => entry.speciesKey == 'g1_koi_fish',
    );
    expect(sharedKoi.variants.map((entry) => entry.id).toSet(), {
      'g1_koi_fish',
      'g2_koi_sunny',
      'g2_koi_calico',
      'g2_koi_oriole',
      'g2_koi_dagon',
    });
  });
}
