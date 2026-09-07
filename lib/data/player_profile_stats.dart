import '../data/creature_card_state.dart';
import '../models/creature_card_support.dart';

class PlayerProfileStats {
  const PlayerProfileStats({
    required this.cardsObtained,
    required this.cardsTotal,
    required this.goldCardsObtained,
    required this.goldCardsTotal,
    this.kills = 0,
  });

  const PlayerProfileStats.empty()
    : cardsObtained = 0,
      cardsTotal = 0,
      goldCardsObtained = 0,
      goldCardsTotal = 0,
      kills = 0;

  final int cardsObtained;
  final int cardsTotal;
  final int goldCardsObtained;
  final int goldCardsTotal;
  final int kills;
}

PlayerProfileStats summarizePlayerProfileStats(
  Iterable<CreatureCardCarrier> entries,
  CreatureCardProgressMap progressByKey,
) {
  var cardsObtained = 0;
  var cardsTotal = 0;
  var goldCardsObtained = 0;
  var goldCardsTotal = 0;

  final cardsByKey = <String, List<CreatureCardCarrier>>{};
  for (final entry in entries) {
    final key = creatureCardProgressKeyOrNull(entry);
    if (key == null || !shouldTrackCreatureCardProgress(entry)) {
      continue;
    }
    cardsByKey.putIfAbsent(key, () => <CreatureCardCarrier>[]).add(entry);
  }

  for (final cardEntries in cardsByKey.values) {
    cardsTotal += 1;
    var progress = CreatureCardProgress.unowned;
    for (final entry in cardEntries) {
      final candidate = resolveCreatureCardProgress(entry, progressByKey);
      if (candidate == CreatureCardProgress.gold) {
        progress = candidate;
        break;
      }
      if (candidate == CreatureCardProgress.obtained) {
        progress = candidate;
      }
    }
    if (progress != CreatureCardProgress.unowned) {
      cardsObtained += 1;
    }
    if (cardEntries.any(creatureCardHasGoldVariant)) {
      goldCardsTotal += 1;
      if (progress == CreatureCardProgress.gold) {
        goldCardsObtained += 1;
      }
    }
  }

  return PlayerProfileStats(
    cardsObtained: cardsObtained,
    cardsTotal: cardsTotal,
    goldCardsObtained: goldCardsObtained,
    goldCardsTotal: goldCardsTotal,
  );
}
