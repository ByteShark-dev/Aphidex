import 'package:aphidex/models/location.dart';
import 'package:aphidex/models/enemy_index_entry.dart';
import 'package:aphidex/screens/map_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const creatureA = LocationRecord(
    id: 'creature-a-surface',
    targetType: MapTargetType.creature,
    targetId: 'g2_creature_a',
    layer: MapLayer.surface,
    u: .2,
    v: .3,
    type: 'spawn',
    conditional: false,
  );
  const creatureB = LocationRecord(
    id: 'creature-b-surface',
    targetType: MapTargetType.creature,
    targetId: 'g2_creature_b',
    layer: MapLayer.surface,
    u: .4,
    v: .5,
    type: 'spawn',
    conditional: false,
  );
  const equipment = LocationRecord(
    id: 'equipment-surface',
    targetType: MapTargetType.equipment,
    targetId: 'g2_equipment',
    layer: MapLayer.surface,
    u: .6,
    v: .7,
    type: 'physical_pickup',
    conditional: false,
  );
  const mixr = LocationRecord(
    id: 'mixr-greenhouse',
    targetType: MapTargetType.defense,
    targetId: 'mixr_greenhouse',
    layer: MapLayer.surface,
    u: .7,
    v: .8,
    type: 'mixr',
    conditional: false,
  );
  const markers = <LocationRecord>[creatureA, creatureB, equipment, mixr];

  test('general map never exposes catalog markers', () {
    expect(visibleMapMarkersForRequest(markers, null), isEmpty);
  });

  test('equipment navigation exposes only its exact item locations', () {
    const request = MapOpenRequest(
      target: MapTarget(MapTargetType.equipment, 'g2_equipment'),
      filter: MapFilter(
        type: MapTargetType.equipment,
        targetId: 'g2_equipment',
      ),
      focus: MapFocus(),
    );

    expect(visibleMapMarkersForRequest(markers, request), [equipment]);
  });

  test('defense navigation exposes its exact event location', () {
    const request = MapOpenRequest(
      target: MapTarget(MapTargetType.defense, 'mixr_greenhouse'),
      filter: MapFilter(
        type: MapTargetType.defense,
        targetId: 'mixr_greenhouse',
      ),
      focus: MapFocus(),
    );

    expect(visibleMapMarkersForRequest(markers, request), [mixr]);
  });

  test('creature navigation exposes only the exact creature locations', () {
    const request = MapOpenRequest(
      target: MapTarget(MapTargetType.creature, 'g2_creature_a'),
      filter: MapFilter(
        type: MapTargetType.creature,
        targetId: 'g2_creature_a',
      ),
      focus: MapFocus(),
    );

    expect(visibleMapMarkersForRequest(markers, request), [creatureA]);
  });

  test('map creature presentation uses its Creature Card, not thumbnail', () {
    final creature = EnemyIndexEntry.fromJson({
      'id': 'g2_bee',
      'speciesKey': 'bee',
      'game': 'g2',
      'name': 'Bee',
      'order': 1,
      'tier': 2,
      'danger': 'medium',
      'isBoss': false,
      'weaknesses': <String>[],
      'resistances': <String>[],
      'defaultGold': false,
      'cardNormal': 'assets/g2/creatures/cards/Creaturecard_Bee.png',
      'cardGold': 'assets/g2/creatures/cards/Creaturecardgold_Bee.png',
      'mapMarkerAsset': 'assets/g2/creatures/thumbnails/Bee.webp',
      'defaultCardVariant': 'normal',
    });

    expect(mapCreatureCardAsset(creature), creature.cardNormal);
    expect(mapCreatureCardAsset(creature), isNot(creature.mapMarkerAsset));
  });
}
