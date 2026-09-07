import 'package:aphidex/data/creature_card_state.dart';
import 'package:aphidex/models/creature_card_support.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normal plus gold cards cycle through all three approved states', () {
    const enemy = _FakeCardCarrier(
      id: 'regular',
      cardNormal: 'normal.webp',
      cardGold: 'gold.webp',
    );

    expect(
      nextCreatureCardProgress(enemy, CreatureCardProgress.unowned),
      CreatureCardProgress.obtained,
    );
    expect(
      nextCreatureCardProgress(enemy, CreatureCardProgress.obtained),
      CreatureCardProgress.gold,
    );
    expect(
      nextCreatureCardProgress(enemy, CreatureCardProgress.gold),
      CreatureCardProgress.unowned,
    );
  });

  test('normal-only cards skip the gold state', () {
    const enemy = _FakeCardCarrier(
      id: 'normal_only',
      cardNormal: 'normal.webp',
    );

    expect(
      nextCreatureCardProgress(enemy, CreatureCardProgress.unowned),
      CreatureCardProgress.obtained,
    );
    expect(
      nextCreatureCardProgress(enemy, CreatureCardProgress.obtained),
      CreatureCardProgress.unowned,
    );
  });

  test('gold-only cards toggle between unowned and gold', () {
    const enemy = _FakeCardCarrier(
      id: 'gold_only',
      cardGold: 'gold.webp',
      defaultGold: true,
    );

    expect(
      nextCreatureCardProgress(enemy, CreatureCardProgress.unowned),
      CreatureCardProgress.gold,
    );
    expect(
      nextCreatureCardProgress(enemy, CreatureCardProgress.gold),
      CreatureCardProgress.unowned,
    );
  });

  test('entries without cards stay out of the progress system', () {
    const enemy = _FakeCardCarrier(id: 'global_entry');

    expect(shouldTrackCreatureCardProgress(enemy), isFalse);
    expect(
      resolveCreatureCardProgress(
        enemy,
        const <String, CreatureCardProgress>{},
      ),
      CreatureCardProgress.unowned,
    );
    expect(resolveCreatureCardAsset(enemy, CreatureCardProgress.gold), isNull);
  });

  test('legacy marked gold-only cards do not auto-own without a mark', () {
    const enemy = _FakeCardCarrier(
      id: 'gold_only',
      cardGold: 'gold.webp',
      defaultGold: true,
    );

    expect(
      resolveCreatureCardProgress(
        enemy,
        const <String, CreatureCardProgress>{},
      ),
      CreatureCardProgress.unowned,
    );
    expect(
      migrateLegacyCreatureCardProgress(
        enemy,
        const <String, CreatureCardProgress>{},
        legacyGoldIds: {'gold_only'},
      ),
      CreatureCardProgress.gold,
    );
  });

  test(
    'legacy invalid gold states on normal-only cards migrate to obtained',
    () {
      const enemy = _FakeCardCarrier(
        id: 'normal_only',
        cardNormal: 'normal.webp',
        goldLinkId: 'linked_normal_only',
      );

      expect(
        migrateLegacyCreatureCardProgress(
          enemy,
          const <String, CreatureCardProgress>{},
          legacyGoldIds: {'linked_normal_only'},
        ),
        CreatureCardProgress.obtained,
      );
      expect(
        migrateLegacyCreatureCardProgress(
          enemy,
          const <String, CreatureCardProgress>{
            'linked_normal_only': CreatureCardProgress.gold,
          },
        ),
        CreatureCardProgress.obtained,
      );
    },
  );

  test('linked base and Buggie entries use one canonical progress key', () {
    const base = _FakeCardCarrier(
      id: 'g2_ladybug',
      cardNormal: 'normal.webp',
      cardGold: 'gold.webp',
    );
    const buggy = _FakeCardCarrier(
      id: 'g2_buggy_ladybug',
      goldLinkId: 'g2_ladybug',
      cardNormal: 'buggy-normal.webp',
      cardGold: 'buggy-gold.webp',
    );

    expect(creatureCardProgressKey(base), 'g2:g2_ladybug');
    expect(creatureCardProgressKey(buggy), 'g2:g2_ladybug');
    expect(
      creatureCardObsoleteProgressKeys(buggy),
      contains('g2:g2_buggy_ladybug'),
    );
  });

  test('empty game or card identity cannot create a storage key', () {
    const emptyId = _FakeCardCarrier(id: '', cardNormal: 'normal.webp');
    const emptyGame = _FakeCardCarrier(
      id: 'card',
      game: '',
      cardNormal: 'normal.webp',
    );

    expect(creatureCardProgressKeyOrNull(emptyId), isNull);
    expect(creatureCardProgressKeyOrNull(emptyGame), isNull);
  });
}

class _FakeCardCarrier implements CreatureCardCarrier {
  const _FakeCardCarrier({
    required this.id,
    this.cardNormal = '',
    this.cardGold = '',
    this.goldLinkId,
    this.defaultGold = false,
    this.game = 'g2',
  });

  @override
  final String id;
  final String cardNormal;
  final String cardGold;
  @override
  final String? goldLinkId;
  @override
  final bool defaultGold;

  @override
  final String game;

  @override
  bool get hasCreatureCard => cardNormal.isNotEmpty || cardGold.isNotEmpty;

  @override
  bool get hasGoldCreatureCard => cardGold.isNotEmpty;

  @override
  bool get hasSelectableCardVariants =>
      cardNormal.isNotEmpty && cardGold.isNotEmpty;

  @override
  CreatureCardVariant? get defaultCardVariant {
    if (cardNormal.isNotEmpty) {
      return CreatureCardVariant.normal;
    }
    if (cardGold.isNotEmpty) {
      return CreatureCardVariant.gold;
    }
    return null;
  }

  @override
  String? assetForCardVariant(CreatureCardVariant variant) {
    return switch (variant) {
      CreatureCardVariant.normal => cardNormal.isEmpty ? null : cardNormal,
      CreatureCardVariant.gold => cardGold.isEmpty ? null : cardGold,
    };
  }
}
