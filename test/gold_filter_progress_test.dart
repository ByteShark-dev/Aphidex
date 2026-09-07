import 'package:aphidex/data/creature_card_state.dart';
import 'package:aphidex/models/creature_card_support.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gold filter keeps only entries whose current progress is gold', () {
    const goldEntry = _FakeCardCarrier(
      id: 'g2_regular_test',
      cardNormal: 'normal.webp',
      cardGold: 'gold.webp',
    );
    const normalEntry = _FakeCardCarrier(
      id: 'g2_regular_alt',
      cardNormal: 'normal.webp',
      cardGold: 'gold.webp',
    );
    const eventEntry = _FakeCardCarrier(id: 'g2_event_test');

    const progressByKey = <String, CreatureCardProgress>{
      'g2:g2_regular_test': CreatureCardProgress.gold,
      'g2:g2_regular_alt': CreatureCardProgress.obtained,
    };

    final filtered = [goldEntry, normalEntry, eventEntry]
        .where(
          (entry) =>
              resolveCreatureCardProgress(entry, progressByKey) ==
              CreatureCardProgress.gold,
        )
        .map((entry) => entry.id)
        .toList();

    expect(filtered, ['g2_regular_test']);
  });

  test('gold filter keeps both views of one linked gold card', () {
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
    const progress = <String, CreatureCardProgress>{
      'g2:g2_ladybug': CreatureCardProgress.gold,
    };

    expect(
      [base, buggy]
          .where(
            (entry) =>
                resolveCreatureCardProgress(entry, progress) ==
                CreatureCardProgress.gold,
          )
          .map((entry) => entry.id),
      ['g2_ladybug', 'g2_buggy_ladybug'],
    );
  });
}

class _FakeCardCarrier implements CreatureCardCarrier {
  const _FakeCardCarrier({
    required this.id,
    this.cardNormal = '',
    this.cardGold = '',
    this.goldLinkId,
  });

  @override
  final String id;
  final String cardNormal;
  final String cardGold;

  @override
  final String? goldLinkId;

  @override
  String get game => 'g2';

  @override
  bool get defaultGold => false;

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
