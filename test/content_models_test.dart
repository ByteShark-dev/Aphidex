import 'package:aphidex/data/content_repositories.dart';
import 'package:aphidex/data/enemy_repository.dart';
import 'package:aphidex/models/defense_event.dart';
import 'package:aphidex/models/equipment.dart';
import 'package:aphidex/models/location.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all equipment items and armor sets deserialize exhaustively', () async {
    EquipmentRepository.clearCache();
    final catalog = await EquipmentRepository.load();
    expect(catalog.items, hasLength(209));
    expect(catalog.armorSets, hasLength(29));
    expect(
      catalog.items
          .expand((item) => item.attacks)
          .expand((attack) => attack.statusEffects),
      everyElement(isA<EquipmentStatusEffect>()),
    );
    expect(
      catalog.items.expand((item) => item.acquisition.recipes),
      everyElement(isA<EquipmentRecipe>()),
    );
    expect(
      catalog.items.expand((item) => item.repair),
      everyElement(isA<EquipmentIngredient>()),
    );
  });

  test('all normalized G2 creature details deserialize', () async {
    EnemyRepository.clearCaches();
    final entries = await EnemyRepository.loadGame('g2', 'en');
    expect(entries, hasLength(132));
    for (final entry in entries) {
      final detail = await EnemyRepository.loadDetail(
        entry.game,
        entry.id,
        'en',
      );
      expect(detail.id, entry.id);
    }
  });

  test(
    'canonical map transform and every runtime marker are representable',
    () async {
      MapRepository.clearCache();
      final catalog = await MapRepository.load();
      expect(catalog.markers, hasLength(4469));
      expect(
        catalog.markers,
        everyElement(
          isA<LocationRecord>()
              .having((item) => item.u, 'u', inInclusiveRange(0, 1))
              .having((item) => item.v, 'v', inInclusiveRange(0, 1)),
        ),
      );
      final surface = catalog.maps[MapLayer.surface]!;
      final point = surface.coordinateTransform.worldToNormalized(
        const Offset(-131527, -27812),
      );
      expect(point.dx, closeTo(.486, .002));
      expect(point.dy, closeTo(.166, .002));
    },
  );

  test('invalid normalized coordinates fail before runtime drawing', () {
    expect(
      () => LocationRecord.fromJson({
        'id': 'bad',
        'targetType': 'creature',
        'targetId': 'g2_aphid',
        'map': 'surface',
        'u': 1.1,
        'v': .5,
      }),
      throwsFormatException,
    );
  });

  test('single and multiple focus bounds are framed inside the viewport', () {
    const viewport = Size(400, 700);
    const texture = Size(3264, 2832);
    final single = MapViewportTransform.frame(
      viewport: viewport,
      texture: texture,
      normalizedBounds: const Rect.fromLTWH(.3, .4, 0, 0),
    );
    final centered = MatrixUtils.transformPoint(
      single,
      const Offset(.3 * 3264, .4 * 2832),
    );
    expect(centered.dx, closeTo(viewport.width / 2, .01));
    expect(centered.dy, closeTo(viewport.height / 2, .01));

    const bounds = Rect.fromLTRB(.15, .2, .8, .75);
    final multiple = MapViewportTransform.frame(
      viewport: viewport,
      texture: texture,
      normalizedBounds: bounds,
    );
    final topLeft = MatrixUtils.transformPoint(
      multiple,
      Offset(bounds.left * 3264, bounds.top * 2832),
    );
    final bottomRight = MatrixUtils.transformPoint(
      multiple,
      Offset(bounds.right * 3264, bounds.bottom * 2832),
    );
    expect(topLeft.dx, greaterThanOrEqualTo(47));
    expect(topLeft.dy, greaterThanOrEqualTo(47));
    expect(bottomRight.dx, lessThanOrEqualTo(viewport.width - 47));
    expect(bottomRight.dy, lessThanOrEqualTo(viewport.height - 47));
  });

  test('location and hazard provenance parse without losing coordinates', () {
    final location = LocationRecord.fromJson({
      'id': 'spawn-1',
      'targetType': 'creature',
      'targetId': 'g2_aphid',
      'map': 'abyss',
      'u': .25,
      'v': .75,
      'type': 'story_locked',
      'conditional': true,
      'environmentHazards': [
        {'type': 'required_equipment', 'equipmentId': 'DivingArmor'},
      ],
    });
    expect(location.layer, MapLayer.abyss);
    expect(location.conditional, isTrue);
    expect(location.environmentHazards.single.equipmentId, 'DivingArmor');
  });

  test('unresolved equipment acquisition remains explicit', () {
    final item = EquipmentItem.fromJson({
      'id': 'Example',
      'domain': 'trinket',
      'name': {'en': 'Example', 'es': 'Ejemplo', 'ru': 'Пример'},
      'icon': '',
      'acquisition': {'status': 'unresolved_acquisition'},
    });
    expect(item.domain, EquipmentDomain.trinket);
    expect(item.acquisition.unresolved, isTrue);
  });

  test('scheduled group terminology preserves the source index', () {
    final event = DefenseEvent.fromJson({
      'id': 'mixr_test',
      'mixrId': 'mixr_1',
      'name': {'en': 'MIX.R Test', 'es': 'MIX.R Prueba', 'ru': 'MIX.R Тест'},
      'location': {'map': 'surface', 'u': .4, 'v': .5},
      'scheduledGroups': [
        {
          'index': 9,
          'displayOrdinal': 1,
          'timeSeconds': 12.5,
          'creatures': [
            {'technicalId': 'Aphid', 'publicId': 'g2_aphid', 'count': 2},
          ],
        },
      ],
    });
    expect(event.groups.single.sourceIndex, 9);
    expect(event.groups.single.creatures.single.publicId, 'g2_aphid');
  });

  test('clustering is deterministic and keeps every marker', () {
    final markers = List.generate(
      20,
      (index) => LocationRecord(
        id: '$index',
        targetType: MapTargetType.creature,
        targetId: 'g2_aphid',
        layer: MapLayer.surface,
        u: (index % 5) / 10,
        v: (index ~/ 5) / 10,
        type: 'spawn',
        conditional: false,
      ),
    );
    final first = MapRepository.cluster(markers, cellSize: .2);
    final second = MapRepository.cluster(markers, cellSize: .2);
    expect(
      first.map((item) => '${item.u}:${item.v}:${item.markers.length}'),
      second.map((item) => '${item.u}:${item.v}:${item.markers.length}'),
    );
    expect(first.expand((item) => item.markers), hasLength(markers.length));
  });
}
