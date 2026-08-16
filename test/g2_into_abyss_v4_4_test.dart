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

  test('Named C.R.O. and active waves become typed encounter variants', () {
    final enemies = loadIndex().map((entry) => loadDetail(entry.id));
    final variants = enemies
        .expand((enemy) => enemy.encounterVariants)
        .toList();
    final named = variants.where((variant) => variant.isNamed).toList();
    final waves = variants
        .where((variant) => variant.role == 'wave_or_raid')
        .toList();

    expect(named, hasLength(20));
    expect(waves, hasLength(40));
    expect(variants, hasLength(60));
    expect(named.every((variant) => variant.health?.value != null), isTrue);
    expect(named.every((variant) => variant.attacks.isNotEmpty), isTrue);
    expect(waves.every((variant) => variant.id.startsWith('g2_wave_')), isTrue);
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
    expect(buggy.tier, 3);
    expect(buggy.cardTier, 3);
    expect(buggy.health, isNull);
    expect(buggy.attacks, isEmpty);
    expect(buggy.cardNormal, loadDetail('g2_toe_biter_nymph').cardNormal);
    final buggies = loadIndex()
        .where((entry) => entry.collectionGroup == 'buggy')
        .map((entry) => loadDetail(entry.id));
    expect(buggies.every((entry) => !entry.healthDisplay.shouldRender), isTrue);
    expect(buggies.every((entry) => entry.health == null), isTrue);
  });

  test('unresolved attack damage is explicitly unidentified', () {
    EnemyAttack unresolved(String language) =>
        loadDetail(
          'g2_bombardier_beetle',
          language: language,
        ).attacks.singleWhere(
          (attack) =>
              attack.notes?.resolve(language) ==
              switch (language) {
                'es' => 'Sin identificar',
                'ru' => 'Не идентифицировано',
                _ => 'Unidentified',
              },
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

  test('C.R.O. and scorpion waves stay inside their parent selector', () {
    final master = loadMaster();
    final active = master
        .expand((entry) => (entry['encounterVariants'] as List? ?? const []))
        .whereType<Map<String, dynamic>>()
        .where((entry) => entry['role'] == 'wave_or_raid')
        .toList(growable: false);
    final contextual = master
        .expand((entry) => (entry['contextVariants'] as List? ?? const []))
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    final indexedIds = loadIndex().map((entry) => entry.id).toSet();
    const activeScorpionWaveIds = {
      'g2_wave_scorpion_northern_wave',
      'g2_wave_scorpion_jr_northern_wave',
      'g2_wave_scorpling_northern_wave',
    };

    expect(master, hasLength(132));
    expect(contextual, hasLength(50));
    expect(active, hasLength(40));
    expect(
      activeScorpionWaveIds.every((id) => active.any((v) => v['id'] == id)),
      isTrue,
    );
    expect(indexedIds.any((id) => id.startsWith('g2_wave_')), isFalse);
    expect(master.any((entry) => entry['isRaidWave'] == true), isFalse);
  });

  test('all G2 generic weaknesses are presented as busting damage', () {
    final master = loadMaster();
    for (final entry in master) {
      expect(
        entry['weaknesses'] as List? ?? const [],
        isNot(contains('generic')),
      );
      expect(
        (entry['damageWeaknesses'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map((row) => row['type']),
        isNot(contains('generic')),
      );
      for (final variant in [
        ...(entry['encounterVariants'] as List? ?? const []),
        ...(entry['contextVariants'] as List? ?? const []),
      ].whereType<Map<String, dynamic>>()) {
        final types = (variant['weaknesses'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .expand((row) => row['damageTypes'] as List? ?? const []);
        expect(
          types,
          isNot(contains('General')),
          reason: entry['id'].toString(),
        );
      }
    }
    expect(
      master.any(
        (entry) =>
            (entry['weaknesses'] as List? ?? const []).contains('busting'),
      ),
      isTrue,
    );
  });

  test('all O.G.R.R. entries expose the three flavor infusions', () {
    final ogrr = loadIndex()
        .where((entry) => entry.collectionGroup == 'ogrr')
        .map((entry) => loadDetail(entry.id))
        .toList();
    expect(ogrr, hasLength(16));
    expect(
      ogrr.every(
        (entry) => entry.infusions
            .map((infusion) => infusion.id)
            .toSet()
            .containsAll({'fresh', 'sour', 'spicy'}),
      ),
      isTrue,
    );
  });

  test('new combat copy is user-facing and new creatures are aggressive', () {
    final master = loadMaster();
    final technicalCopy = RegExp(
      r'Extracted base damage|v4\.4 combat data|datos de combate v4\.4',
      caseSensitive: false,
    );
    expect(technicalCopy.hasMatch(jsonEncode(master)), isFalse);
    expect(
      master.singleWhere(
        (entry) => entry['id'] == 'g2_green_shield_bug',
      )['collectionGroup'],
      'angry',
    );
    expect(
      loadDetail('g2_northern_scorpion').attacks.first.name.resolve('en'),
      'Combo 2',
    );
    expect(
      loadDetail(
        'g2_northern_scorpion',
        language: 'es',
      ).attacks.first.notes?.resolve('es'),
      'Daño del ataque: 28',
    );
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
