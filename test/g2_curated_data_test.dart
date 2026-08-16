import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final file = File('assets/data/enemies_g2.json');
  final data = (jsonDecode(file.readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();

  Map<String, dynamic> entry(String id) =>
      data.firstWhere((enemy) => enemy['id'] == id);

  test('water damage is never stored as an elemental weakness in g2', () {
    for (final enemy in data) {
      final elemental = (enemy['elementalWeaknesses'] as List?) ?? const [];
      expect(
        elemental.whereType<Map>().any((bonus) => bonus['type'] == 'water'),
        isFalse,
        reason: 'water should be treated as damage, not elemental',
      );
    }
  });

  test(
    'curated shared g2 entries keep localized names and structured combat data',
    () {
      final redWorkerAnt = entry('g2_red_worker_ant');
      final ladybug = entry('g2_ladybug');
      final bee = entry('g2_bee');
      final firefly = entry('g2_firefly');

      expect(redWorkerAnt['name']['es'], 'Hormiga obrera roja');
      expect(
        (redWorkerAnt['damageWeaknesses'] as List).whereType<Map>().any(
          (bonus) => bonus['type'] == 'stabbing',
        ),
        isTrue,
      );

      expect(ladybug['name']['es'], 'Mariquita');
      expect(
        (ladybug['resistancesV2'] as List).whereType<Map>().any(
          (bonus) => bonus['type'] == 'spicy' && bonus['bonusPct'] == 25,
        ),
        isTrue,
      );

      expect(bee['name']['es'], 'Abeja');
      expect((bee['description']['es'] as String).contains('néctar'), isTrue);
      expect(bee['attacks'], isNotEmpty);

      expect(firefly['name']['es'], 'Luciérnaga');
      expect((firefly['inflictsEffects'] as List).contains('busting'), isTrue);
      expect(
        (firefly['description']['en'] as String).contains('glow goo'),
        isTrue,
      );
    },
  );

  test('g2 weak points match the curated creature board', () {
    expect(
      entry('g2_baby_garden_snail')['weakPoint'],
      containsPair('susceptibleDamage', 'stabbing_arrows_only'),
    );
    expect(
      entry('g2_garden_snail')['weakPoint'],
      containsPair('susceptibleDamage', 'stabbing_arrows_only'),
    );
    expect(
      entry('g2_praying_mantis_nymph')['weakPoint'],
      containsPair('susceptibleDamage', 'stabbing_bows_and_spears'),
    );
    expect(
      entry('g2_ladybug')['weakPoint'],
      equals({
        'part': 'legs',
        'susceptibleDamage': 'slashing',
        'susceptibleDamageTypes': ['slashing'],
      }),
    );
    expect(
      entry('g2_potato_beetle')['weakPoint'],
      equals({
        'part': 'legs',
        'susceptibleDamage': 'slashing',
        'susceptibleDamageTypes': ['slashing'],
      }),
    );
    expect(
      entry('g2_rust_beetle')['weakPoint'],
      equals({
        'part': 'rump',
        'susceptibleDamage': 'any',
        'susceptibleDamageTypes': ['any'],
      }),
    );
    expect(
      entry('g2_axl')['weakPoint'],
      equals({
        'part': 'rump',
        'susceptibleDamage': 'any',
        'susceptibleDamageTypes': ['any'],
      }),
    );
    expect(
      entry('g2_king_dozer')['weakPoint'],
      equals({
        'part': 'eyes',
        'susceptibleDamage': 'any',
        'susceptibleDamageTypes': ['any'],
      }),
    );
  });

  test('g2 scorpions expose the extracted abdomen and stinger weak points', () {
    for (final id in [
      'g2_northern_scorpion',
      'g2_northern_scorpion_jr',
      'g2_orc_northern_scorpion',
      'g2_orc_northern_scorpion_jr',
      'g2_ogrr_northern_scorpion',
    ]) {
      final weakPoints = (entry(id)['weakPoints'] as List)
          .cast<Map<String, dynamic>>();
      expect(weakPoints, hasLength(2), reason: id);
      expect(
        weakPoints[0],
        equals({
          'part': 'butt',
          'susceptibleDamage': 'any',
          'susceptibleDamageTypes': ['any'],
        }),
        reason: id,
      );
      expect(
        weakPoints[1],
        equals({
          'part': 'stinger',
          'susceptibleDamage': 'any',
          'susceptibleDamageTypes': ['any'],
        }),
        reason: id,
      );
    }
  });

  test(
    'g2 variants inherit the corrected weak points of their base species',
    () {
      expect(
        entry('g2_orc_red_soldier_ant')['weakPoint'],
        containsPair('susceptibleDamage', 'stabbing_arrows_only'),
      );
      expect(
        entry('g2_orc_bee')['weakPoint'],
        containsPair('susceptibleDamage', 'stabbing_arrows_only'),
      );
      expect(
        entry('g2_orc_black_soldier_ant')['weakPoint'],
        containsPair('susceptibleDamage', 'stabbing_arrows_only'),
      );
      expect(
        entry('g2_orc_praying_mantis_nymph')['weakPoint'],
        containsPair('susceptibleDamage', 'stabbing_bows_and_spears'),
      );
      expect(
        entry('g2_ogrr_praying_mantis_nymph')['weakPoint'],
        containsPair('susceptibleDamage', 'stabbing_bows_and_spears'),
      );
      expect(
        entry('g2_orc_ladybug')['weakPoint'],
        containsPair('susceptibleDamage', 'slashing'),
      );
      expect(
        entry('g2_ogrr_ladybug')['weakPoint'],
        containsPair('susceptibleDamage', 'slashing'),
      );
      expect(
        entry('g2_buggy_ladybug')['weakPoint'],
        containsPair('susceptibleDamage', 'slashing'),
      );
      expect(
        entry('g2_orc_bombardier_beetle')['weakPoint'],
        containsPair('susceptibleDamage', 'any'),
      );
      expect(
        entry('g2_orc_potato_beetle')['weakPoint'],
        containsPair('susceptibleDamage', 'slashing'),
      );
      expect(
        entry('g2_orc_rust_beetle')['weakPoint'],
        containsPair('susceptibleDamage', 'any'),
      );
      expect(
        entry('g2_ogrr_rust_beetle')['weakPoint'],
        containsPair('susceptibleDamage', 'any'),
      );
    },
  );

  test(
    'orchid mantis playground boss entry stays localized and phase-complete',
    () {
      final orchidMantis = entry('g2_orchid_mantis');
      final phases = (orchidMantis['bossPhases'] as List)
          .cast<Map<String, dynamic>>();

      expect(orchidMantis['collectionGroup'], 'other');
      expect(orchidMantis['temperament'], 'aggressive');
      expect(orchidMantis['name']['en'], 'Orchid Mantis');
      expect(
        orchidMantis['respawnInfo']['en'],
        'Depends on the Playground configuration.',
      );
      expect(
        (orchidMantis['combatStats']['attackDamageSummary']['en'] as String)
            .contains('Combo Slam: 120'),
        isTrue,
      );

      expect(phases, hasLength(3));
      expect(phases.first['startsAtHealthPct'], 100);
      expect(
        (phases.first['attacks'] as List).whereType<Map>().any(
          (attack) => attack['name']['en'] == 'Combo Slam',
        ),
        isTrue,
      );
      expect(
        (phases[1]['attacks'] as List).whereType<Map>().any(
          (attack) => attack['name']['en'] == 'Ground Shred',
        ),
        isTrue,
      );
      expect(
        (phases[2]['attacks'] as List).whereType<Map>().any(
          (attack) => attack['name']['en'] == 'Double Charged Strike',
        ),
        isTrue,
      );
    },
  );

  test('masked fighter boss entry keeps its full duel phase structure', () {
    final maskedFighter = entry('g2_masked_fighter');
    final phases = (maskedFighter['bossPhases'] as List)
        .cast<Map<String, dynamic>>();

    expect(maskedFighter['weaknesses'], contains('fresh'));
    expect(
      (maskedFighter['resistancesV2'] as List).whereType<Map>().any(
        (bonus) => bonus['type'] == 'venom',
      ),
      isTrue,
    );
    expect(maskedFighter['combatStats']['health'], 1875);
    expect(phases, hasLength(5));
    expect(phases[1]['trigger']['en'], contains('75%'));
    expect(
      (phases[1]['attacks'] as List).whereType<Map>().any(
        (attack) => attack['name']['en'] == 'Charged Attack',
      ),
      isTrue,
    );
    expect(
      (phases[3]['abilities'] as List).whereType<Map>().any(
        (ability) => ability['name']['en'] == 'Reposition+',
      ),
      isTrue,
    );
  });

  test(
    'roach elites and major roaches keep their real two-phase transitions',
    () {
      final cockroach = entry('g2_cockroach');
      final orcCockroach = entry('g2_orc_cockroach');
      final cockroachQueen = entry('g2_cockroach_queen');
      final orcCockroachQueen = entry('g2_orc_cockroach_queen');

      expect(cockroach['isBoss'], isFalse);
      expect((cockroach['bossPhases'] as List), hasLength(2));
      expect(
        (cockroach['bossPhases'] as List)[1]['trigger']['en'],
        contains('loses its head'),
      );
      expect(
        (cockroach['combatStats']['attackDamageSummary']['en'] as String),
        contains('Headless Ram: 25'),
      );

      expect(orcCockroach['isBoss'], isFalse);
      expect((orcCockroach['bossPhases'] as List), hasLength(2));

      expect(cockroachQueen['isBoss'], isFalse);
      expect((cockroachQueen['bossPhases'] as List), hasLength(2));

      expect(orcCockroachQueen['isBoss'], isFalse);
      expect((orcCockroachQueen['bossPhases'] as List), hasLength(2));
      expect(
        orcCockroachQueen['description']['en'],
        allOf(contains('remote-controlled'), contains('O.R.C. Receiver')),
      );
    },
  );

  test('g2 boss danger tiers match the current community read', () {
    expect(entry('g2_axl')['danger'], 'imposible_superior');
    expect(entry('g2_king_dozer')['danger'], 'extrema');
    expect(entry('g2_orc_broodmother')['danger'], 'imposible');
    expect(entry('g2_masked_stranger')['danger'], 'imposible');
    expect(entry('g2_masked_fighter')['danger'], 'imposible');
    expect(entry('g2_orchid_mantis')['danger'], 'proximamente');
    expect(entry('g2_orchid_mantis')['underConstruction'], isTrue);
  });

  test('heavy g2 non-boss enemies match the current community read', () {
    expect(entry('g2_cockroach_queen')['danger'], 'muy_alta');
    expect(entry('g2_orc_cockroach_queen')['danger'], 'muy_alta');
    expect(entry('g2_wasp')['danger'], 'muy_alta');
    expect(entry('g2_wasp_drone')['danger'], 'muy_alta');
    expect(entry('g2_pincher_earwig')['danger'], 'alta');
    expect(entry('g2_whipper_earwig')['danger'], 'muy_alta');
    expect(entry('g2_rust_beetle')['danger'], 'muy_alta');
  });

  test('g2 indirect-threat creatures use the elevated danger tier', () {
    expect(entry('g2_woolly_aphid')['danger'], 'intermedia');
    expect(entry('g2_garter_snake')['danger'], 'intermedia');
    expect(entry('g2_orc_weevil')['danger'], 'alta');
  });

  test('g2 content corrections stay in the master data', () {
    expect(entry('g2_red_soldier_ant')['collectionGroup'], 'angry');
    expect(entry('g2_orc_rust_beetle')['tier'], 3);
    expect(entry('g2_ogrr_whipper_earwig')['tier'], 3);

    for (final id in [
      'g2_caterpillar',
      'g2_baby_garden_snail',
      'g2_garden_snail',
    ]) {
      expect(entry(id)['danger'], 'baja', reason: id);
    }

    final expectedOgrrDanger = {
      'g2_ogrr_northern_scorpion': 'imposible',
      'g2_ogrr_blue_butterfly': 'muy_alta',
      'g2_ogrr_ladybug': 'imposible',
      'g2_ogrr_cricket': 'imposible',
      'g2_ogrr_rust_beetle': 'imposible',
      'g2_ogrr_pincher_earwig': 'imposible',
      'g2_ogrr_whipper_earwig': 'imposible',
      'g2_ogrr_wasp': 'imposible',
      'g2_ogrr_wasp_drone': 'imposible',
      'g2_ogrr_praying_mantis_nymph': 'imposible',
      'g2_ogrr_wolf_spider': 'imposible',
    };
    for (final item in expectedOgrrDanger.entries) {
      expect(entry(item.key)['danger'], item.value, reason: item.key);
    }

    for (final id in ['g2_cockroach_queen', 'g2_orc_cockroach_queen']) {
      final serialized = jsonEncode(entry(id));
      expect(serialized, contains('Spray ácido sin cabeza'), reason: id);
      expect(serialized, isNot(contains('Spray ?cido sin cabeza')), reason: id);
    }
  });

  test('g2 text content does not keep question-mark mojibake', () {
    final serialized = jsonEncode(data);
    expect(
      RegExp(r'[A-Za-z]\?[A-Za-z]|\?[A-Za-z]').hasMatch(serialized),
      isFalse,
    );
  });

  test(
    'ogrr entries expose three infusions and independent lesser mutations',
    () {
      final ogrrEntries = data
          .where((enemy) => enemy['collectionGroup'] == 'ogrr')
          .toList(growable: false);
      const expectedIds = {
        'g2_ogrr_northern_scorpion',
        'g2_ogrr_blue_butterfly',
        'g2_ogrr_ladybug',
        'g2_ogrr_cricket',
        'g2_ogrr_rust_beetle',
        'g2_ogrr_pincher_earwig',
        'g2_ogrr_whipper_earwig',
        'g2_ogrr_wasp',
        'g2_ogrr_wasp_drone',
        'g2_ogrr_praying_mantis_nymph',
        'g2_ogrr_wolf_spider',
      };

      const extractedV44Ids = {
        'g2_ogrr_green_shield_bug',
        'g2_ogrr_striped_bark_scorpion',
        'g2_ogrr_tiger_mosquito',
        'g2_ogrr_toe_biter',
        'g2_ogrr_toe_biter_leviathan',
      };
      expect(ogrrEntries, hasLength(16));
      expect(
        ogrrEntries.map((enemy) => enemy['id']).toSet(),
        expectedIds.union(extractedV44Ids),
      );

      for (final enemy in ogrrEntries.where(
        (enemy) => expectedIds.contains(enemy['id']),
      )) {
        final infusions = (enemy['infusions'] as List)
            .cast<Map<String, dynamic>>();
        expect(
          infusions.map((item) => item['id']).toList(),
          ['fresh', 'sour', 'spicy'],
          reason: enemy['id'] as String,
        );
        expect(enemy['lesserMutationsDescription'], isA<Map>());
        expect((enemy['lesserMutations'] as List), hasLength(7));
      }

      for (final id in extractedV44Ids) {
        expect(entry(id)['health']['value'], isPositive, reason: id);
        expect((entry(id)['attacks'] as List), isNotEmpty, reason: id);
      }

      expect(entry('g2_masked_stranger_orc_waves')['healthDisplay'], 'hidden');
    },
  );

  test(
    'g2 system entries document MIX.R and Ice Sickles without faction raids',
    () {
      final mixr = entry('g2_mixr_defenses');
      final iceSickles = entry('g2_ice_sickles_event');

      expect(mixr['isBoss'], isFalse);
      expect(mixr['description']['en'], contains('Grounded 2 MIX.R events'));
      expect(mixr['specialTraits'][0]['en'], contains('objective-defense'));

      expect(iceSickles['description']['en'], contains('Ice Sickles'));
      expect(
        (iceSickles['abilities'] as List).whereType<Map>().any(
          (ability) => ability['name']['en'] == 'Scorpion Waves',
        ),
        isTrue,
      );
      for (final event in [mixr, iceSickles]) {
        expect(
          (event['abilities'] as List).whereType<Map>().any(
            (ability) => ability['name']['en'] == 'Guard Dog Progress',
          ),
          isTrue,
        );
      }
    },
  );

  test('focused g2 entries now expose the approved HP values', () {
    const approvedHealthValues = {
      'g2_orc_cockroach_queen': 1650,
      'g2_orc_wolf_spider': 1500,
      'g2_orc_praying_mantis_nymph': 1400,
      'g2_orc_cricket': 1400,
      'g2_orc_wasp': 1075,
      'g2_orc_wasp_drone': 1075,
      'g2_orc_pincher_earwig': 1100,
      'g2_orc_potato_beetle': 2000,
      'g2_orc_rust_beetle': 938,
      'g2_orc_firefly': 660,
      'g2_orc_broodmother': 2500,
      'g2_masked_fighter': 1875,
      'g2_ogrr_wasp': 1600,
      'g2_ogrr_wasp_drone': 1600,
      'g2_ogrr_praying_mantis_nymph': 1800,
      'g2_ogrr_wolf_spider': 1800,
      'g2_ogrr_cricket': 1800,
      'g2_ogrr_ladybug': 2200,
      'g2_ogrr_blue_butterfly': 1600,
      'g2_ogrr_northern_scorpion': 1700,
      'g2_orb_weaver_jr': 440,
      'g2_orc_stinkbug': 800,
      'g2_orc_northern_scorpion': 875,
      'g2_orc_blue_butterfly': 500,
    };

    for (final item in approvedHealthValues.entries) {
      expect(entry(item.key)['health']['value'], item.value, reason: item.key);
      expect(entry(item.key)['healthDisplay'], 'normal', reason: item.key);
    }

    expect(entry('g2_orc_black_soldier_ant')['health']['value'], 680);
    expect(entry('g2_orc_black_soldier_ant')['healthDisplay'], isNot('hidden'));
  });

  test('ogrr and late g2 location notes stay aligned to the curated map', () {
    final ogrrCricket = entry('g2_ogrr_cricket');
    final orchidMantis = entry('g2_orchid_mantis');
    final ogrrLadybug = entry('g2_ogrr_ladybug');
    final ogrrWolfSpider = entry('g2_ogrr_wolf_spider');
    final ogrrButterfly = entry('g2_ogrr_blue_butterfly');
    final pincherEarwig = entry('g2_ogrr_pincher_earwig');
    final whipperEarwig = entry('g2_ogrr_whipper_earwig');
    final ogrrRustBeetle = entry('g2_ogrr_rust_beetle');
    final ogrrScorpion = entry('g2_ogrr_northern_scorpion');
    final ogrrWasp = entry('g2_ogrr_wasp');
    final ogrrWaspDrone = entry('g2_ogrr_wasp_drone');

    expect(
      (ogrrCricket['environments'] as List).last['en'],
      'Solar Panel above Pumpkin Patch',
    );
    expect(
      (ogrrCricket['environments'] as List).first['en'],
      'After releasing the O.G.R.Rs. in the Scarecrow Lab',
    );
    expect(
      ogrrCricket['behavior']['es'],
      contains('Su spawn nocturno solo se habilita'),
    );

    expect((orchidMantis['environments'] as List).first['en'], 'Playgrounds');
    expect(
      orchidMantis['behavior']['es'],
      contains('No forma parte del mapa normal'),
    );

    expect(
      (ogrrLadybug['environments'] as List).last['en'],
      'On top of the Picnic Table',
    );
    expect(
      (ogrrWolfSpider['environments'] as List).last['en'],
      'Northern Blueberry Shrubs near the Metal Bench',
    );
    expect(
      (ogrrButterfly['environments'] as List).last['en'],
      'Fallen Ice Cream Truck',
    );

    final pincherEarwigEnvironments = (pincherEarwig['environments'] as List)
        .map((environment) => environment['en'])
        .toList();
    expect(pincherEarwigEnvironments, contains('Inside the Scarecrow Pumpkin'));
    expect(
      pincherEarwigEnvironments,
      contains('Cave between the Statue Shrubs and the Greenhouse'),
    );
    expect(
      pincherEarwig['behavior']['es'],
      contains('comparten los mismos puntos'),
    );

    final whipperEarwigEnvironments = (whipperEarwig['environments'] as List)
        .map((environment) => environment['en'])
        .toList();
    expect(whipperEarwigEnvironments, contains('Inside the Scarecrow Pumpkin'));
    expect(
      whipperEarwigEnvironments,
      contains('Cave between the Statue Shrubs and the Greenhouse'),
    );
    expect(
      whipperEarwig['behavior']['es'],
      contains('comparten los mismos puntos'),
    );

    expect((ogrrRustBeetle['environments'] as List).last['en'], 'Candy Lab');
    expect(
      ogrrRustBeetle['behavior']['es'],
      contains('no depende de la noche'),
    );

    expect((ogrrScorpion['environments'] as List).last['en'], 'Lime Tree Seed');
    expect(ogrrScorpion['behavior']['es'], contains('no depende de la noche'));

    expect(
      (ogrrWasp['environments'] as List).last['en'],
      'Shelves with Empty Jars near King Dozer',
    );
    expect(
      (ogrrWaspDrone['environments'] as List).last['en'],
      'Shelves with Empty Jars near King Dozer',
    );
    expect(
      ogrrWasp['behavior']['es'],
      contains('Su spawn nocturno solo se habilita'),
    );
    expect(
      ogrrWaspDrone['behavior']['es'],
      contains('Su spawn nocturno solo se habilita'),
    );
  });

  test('special g2 entries keep their intended creature photos', () {
    expect(
      entry('g2_orc_broodmother')['photo'],
      'assets/g2/creatures/photos/ORC_Broodmother.webp',
    );
    expect(
      entry('g2_king_dozer')['photo'],
      'assets/g2/creatures/photos/King_Dozer.webp',
    );
    expect(
      entry('g2_buggy_red_soldier_ant')['photo'],
      'assets/g2/creatures/photos/Buggy_Red_Soldier_Ant.webp',
    );
    expect(
      entry('g2_buggy_orb_weaver')['photo'],
      'assets/g2/creatures/photos/Buggy_Orb_Weaver.webp',
    );
    expect(
      entry('g2_buggy_ladybug')['photo'],
      'assets/g2/creatures/photos/Ladybuggy.webp',
    );
    expect(
      entry('g2_buggy_black_soldier_ant')['photo'],
      'assets/g2/creatures/photos/Buggy_Black_Soldier_Ant.webp',
    );
  });
}
