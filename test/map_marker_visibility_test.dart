import 'package:aphidex/models/location.dart';
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
  const markers = <LocationRecord>[creatureA, creatureB, equipment];

  test('general map never exposes catalog markers', () {
    expect(visibleMapMarkersForRequest(markers, null), isEmpty);
  });

  test('non-creature contextual navigation never exposes markers', () {
    const request = MapOpenRequest(
      target: MapTarget(MapTargetType.equipment, 'g2_equipment'),
      filter: MapFilter(
        type: MapTargetType.equipment,
        targetId: 'g2_equipment',
      ),
      focus: MapFocus(),
    );

    expect(visibleMapMarkersForRequest(markers, request), isEmpty);
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
}
