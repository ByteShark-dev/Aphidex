import 'dart:convert';
import 'dart:io';

import 'package:aphidex/data/ui_mapper.dart';
import 'package:aphidex/models/enemy.dart';
import 'package:aphidex/models/enemy_index_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<EnemyIndexEntry> loadIndex() {
    final rows =
        jsonDecode(
              File('assets/data/creatures/en/index_g2.json').readAsStringSync(),
            )
            as List<dynamic>;
    return rows
        .cast<Map<String, dynamic>>()
        .map(EnemyIndexEntry.fromJson)
        .toList(growable: false);
  }

  Enemy loadDetail(String id) => Enemy.fromJson(
    jsonDecode(
          File('assets/data/creatures/en/details/$id.json').readAsStringSync(),
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
}
