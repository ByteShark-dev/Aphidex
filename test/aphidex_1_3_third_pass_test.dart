import 'dart:convert';
import 'dart:io';

import 'package:aphidex/data/enemy_repository.dart';
import 'package:aphidex/data/content_repositories.dart';
import 'package:aphidex/data/entity_asset_resolver.dart';
import 'package:aphidex/data/equipment_presentation.dart';
import 'package:aphidex/data/ui_mapper.dart';
import 'package:aphidex/i18n/app_localizations.dart';
import 'package:aphidex/models/enemy.dart';
import 'package:aphidex/models/location.dart';
import 'package:aphidex/screens/enemy_detail_screen.dart';
import 'package:aphidex/screens/map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

List<dynamic> _jsonList(String path) =>
    jsonDecode(File(path).readAsStringSync()) as List<dynamic>;

Widget _app(Widget home, {String language = 'es'}) => MaterialApp(
  locale: Locale(language),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: home,
);

Future<void> _pumpFrames(WidgetTester tester, {int count = 40}) async {
  for (var index = 0; index < count; index++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

const _testMapDefinition = MapDefinition(
  layer: MapLayer.surface,
  texture: 'assets/g2/map/surface.webp',
  textureSize: Size(1000, 1000),
  coordinateTransform: MapCoordinateTransform(
    worldBounds: Rect.fromLTWH(0, 0, 1, 1),
    sourceTextureSize: Size(1000, 1000),
    contentPixelBounds: Rect.fromLTWH(0, 0, 1000, 1000),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('asset resolver keeps cover/card usages and games independent', () {
    final cover = EntityAssetResolver.resolveCreature(
      game: 'g2',
      usage: EntityAssetUsage.cover,
      coverAsset: 'assets/g2/creatures/photos/Creature.webp',
      cardAsset: 'assets/g2/creatures/cards/Creature.png',
      thumbnailAsset: 'assets/g2/creatures/thumbnails/Creature.webp',
    );
    final card = EntityAssetResolver.resolveCreature(
      game: 'g2',
      usage: EntityAssetUsage.card,
      coverAsset: 'assets/g2/creatures/photos/Creature.webp',
      cardAsset: 'assets/g2/creatures/cards/Creature.png',
      thumbnailAsset: 'assets/g2/creatures/thumbnails/Creature.webp',
    );
    final thumbnail = EntityAssetResolver.resolveCreature(
      game: 'g2',
      usage: EntityAssetUsage.thumbnail,
      coverAsset: 'assets/g2/creatures/photos/Creature.webp',
      cardAsset: 'assets/g2/creatures/cards/Creature.png',
      thumbnailAsset: 'assets/g2/creatures/thumbnails/Creature.webp',
    );
    final rejectedCrossGame = EntityAssetResolver.resolveCreature(
      game: 'g2',
      usage: EntityAssetUsage.cover,
      coverAsset: 'assets/g1/creatures/photos/Creature.webp',
    );
    final approvedOrchidMantis = EntityAssetResolver.resolveCreature(
      publicId: EntityAssetResolver.approvedCrossGameCreatureId,
      game: 'g2',
      usage: EntityAssetUsage.cover,
      coverAsset: 'assets/g1/creatures/photos/Orchid_Mantis.webp',
    );

    expect(cover.asset, contains('/photos/'));
    expect(card.asset, contains('/cards/'));
    expect(thumbnail.asset, contains('/thumbnails/'));
    expect(rejectedCrossGame.fallbackUsed, isTrue);
    expect(rejectedCrossGame.asset, startsWith('assets/global/'));
    expect(approvedOrchidMantis.fallbackUsed, isFalse);
    expect(approvedOrchidMantis.source, 'approved_cross_game_exception');
  });

  test('repository rejects a game/id cross-scope request', () {
    expect(
      () => EnemyRepository.loadDetail('g2', 'g1_ladybug', 'en'),
      throwsStateError,
    );
  });

  test('declared entity assets exist and no mapping crosses games', () {
    final report = _json(
      'outputs/aphidex_1_3/entity_asset_coverage_report.json',
    );
    final summary = report['summary'] as Map<String, dynamic>;
    expect(summary['crossGameAssetMappings'], 0);
    expect(summary['approvedCrossGameExceptions'], 1);
    expect(summary['knownPendingAssets'], 2);
    for (final raw in report['entities'] as List) {
      final row = (raw as Map).cast<String, dynamic>();
      final status = row['mappingStatus'];
      if (status == 'known_pending_assets') continue;
      expect(File(row['coverAsset'] as String).existsSync(), isTrue);
      expect(File(row['cardAsset'] as String).existsSync(), isTrue);
      final game = row['game'];
      final cover = row['coverAsset'] as String;
      final approved = row['approvedCrossGameException'] == true;
      expect(
        game == 'g2' && cover.startsWith('assets/g1/') && !approved,
        isFalse,
      );
      expect(game == 'g1' && cover.startsWith('assets/g2/'), isFalse);
    }
  });

  test('all eight reviewed placeholder replacements are materialized', () {
    const ids = {
      'g2_ogrr_green_shield_bug',
      'g2_ogrr_striped_bark_scorpion',
      'g2_ogrr_tiger_mosquito',
      'g2_ogrr_toe_biter',
      'g2_orc_striped_bark_scorpion_jr',
      'g2_orc_striped_bark_scorpion',
      'g2_orc_striped_bark_scorpling',
      'g2_orc_toe_biter',
    };
    final report = _json(
      'outputs/aphidex_1_3/cover_image_coverage_report.json',
    );
    final rows = (report['creatures'] as List)
        .where((raw) => ids.contains((raw as Map)['publicId']))
        .cast<Map>();
    expect(rows, hasLength(ids.length));
    for (final row in rows) {
      expect(row['source'], 'provided_capture_explicit_review');
      expect(row['fallbackUsed'], isFalse);
      expect(File(row['resolvedAsset'] as String).existsSync(), isTrue);
    }
  });

  test('equipment and effect coverage have no known gaps', () {
    final classifications = _json(
      'outputs/aphidex_1_3/equipment_classification_coverage_report.json',
    );
    expect(classifications['items'], hasLength(209));
    expect((classifications['summary'] as Map)['unclassified'], 0);
    for (final raw in classifications['items'] as List) {
      final row = raw as Map;
      expect(row['normalizedType'], isNot(anyOf('', 'unknown')));
      expect(row['normalizedSubtype'], isNot(anyOf('', 'unknown')));
      expect(row['localizedTypeES'].toString(), isNot(contains('::')));
    }
    final effects = _json(
      'outputs/aphidex_1_3/effect_icon_coverage_report.json',
    );
    expect((effects['summary'] as Map)['knownEffectsWithoutIcon'], 0);
  });

  test('O.R.C. Broodmother shares only Subject V appearance coordinates', () {
    final broodmother = _json(
      'assets/data/creatures/en/details/g2_orc_broodmother.json',
    );
    final subject = _json(
      'assets/data/creatures/en/details/g2_masked_fighter.json',
    );
    expect(broodmother['appearanceSourceId'], 'subject_v_greenhouse');
    expect(broodmother['locations'], hasLength(1));
    expect(subject['locations'], hasLength(1));
    final broodLocation = (broodmother['locations'] as List).single as Map;
    final subjectLocation = (subject['locations'] as List).single as Map;
    expect(broodLocation['world'], subjectLocation['world']);
    expect(broodmother['description'], isNot(subject['description']));
    expect(broodmother['photo'], isNot(subject['photo']));
    expect(broodmother['attacks'], isNot(subject['attacks']));
  });

  test('G1 and G2 creature asset declarations never cross directories', () {
    for (final game in ['g1', 'g2']) {
      final index = _jsonList('assets/data/creatures/en/index_$game.json');
      for (final raw in index) {
        final row = raw as Map;
        for (final key in ['cardNormal', 'cardGold', 'listIconAsset']) {
          final asset = row[key]?.toString() ?? '';
          if (asset.isEmpty) continue;
          final approvedOrchidMantis =
              game == 'g2' &&
              row['id'] == EntityAssetResolver.approvedCrossGameCreatureId &&
              asset.startsWith('assets/g1/');
          expect(
            asset.startsWith('assets/$game/') ||
                asset.startsWith('assets/global/') ||
                approvedOrchidMantis,
            isTrue,
          );
        }
      }
    }
  });

  test('localized creature details remain scoped to their declared game', () {
    for (final language in ['es', 'en', 'ru']) {
      final indexes = {
        for (final game in ['g1', 'g2'])
          game: _jsonList(
            'assets/data/creatures/$language/index_$game.json',
          ).cast<Map>(),
      };
      for (final game in ['g1', 'g2']) {
        for (final row in indexes[game]!) {
          final id = row['id'] as String;
          final detail = _json(
            'assets/data/creatures/$language/details/$id.json',
          );
          expect(detail['id'], id);
          expect(detail['game'], game);
          expect(id, startsWith('${game}_'));
          if (game == 'g1') {
            expect(detail['locations'] as List? ?? const [], isEmpty);
            expect(detail['eventAppearances'] as List? ?? const [], isEmpty);
          }
        }
      }

      final g2BySpecies = {
        for (final row in indexes['g2']!) row['speciesKey']: row,
      };
      for (final g1 in indexes['g1']!) {
        final g2 = g2BySpecies[g1['speciesKey']];
        if (g2 == null) continue;
        final g1Detail = _json(
          'assets/data/creatures/$language/details/${g1['id']}.json',
        );
        final g2Detail = _json(
          'assets/data/creatures/$language/details/${g2['id']}.json',
        );
        final g1Description = g1Detail['description']?.toString().trim() ?? '';
        final g2Description = g2Detail['description']?.toString().trim() ?? '';
        if (g1Description.isNotEmpty && g2Description.isNotEmpty) {
          expect(
            g2Description,
            isNot(g1Description),
            reason: '${g2['id']} inherited the $language G1 description',
          );
        }
      }
    }
  });

  test('equipment classifications and presentation hide technical enums', () {
    expect(
      EquipmentPresentation.slotLabel('EEquipmentSlot::MainHand', 'es'),
      'Mano principal',
    );
    expect(
      EquipmentPresentation.acquisitionMethod('crafting', 'es'),
      'Fabricación',
    );
    expect(
      EquipmentPresentation.effectLabel('TarantulaBowChargeAttackUp', 'es'),
      isNot(anyOf(contains('::'), contains('ChargeAttackUp'))),
    );
    expect(EquipmentPresentation.cleanIdentifier('Type::unknown'), isEmpty);

    final equipment = _json('assets/data/g2/equipment.json');
    final items = (equipment['items'] as List).cast<Map>();
    final itemIds = items.map((item) => item['id']).toSet();
    final sets = (equipment['armorSets'] as List).cast<Map>();
    for (final set in sets) {
      final pieces = (set['pieces'] as List).cast<String>();
      expect(pieces, isNotEmpty);
      expect(pieces.every(itemIds.contains), isTrue, reason: '${set['id']}');
      expect(set['iconStrategy'], isNot(anyOf(null, '')));
    }
    expect(
      sets.singleWhere(
        (set) => set['name']['en'] == 'Lady Bug Armor',
      )['pieces'],
      hasLength(3),
    );
  });

  test('semantic immunity icons retain the underlying effect identity', () {
    final poison = UiMapper.effectIcon('poison');
    final acid = UiMapper.effectIcon('acid');
    final generic = UiMapper.effectIcon('generic');
    expect(poison, isNot(generic));
    expect(acid, isNot(generic));
    expect(File(poison).existsSync(), isTrue);
    expect(File(acid).existsSync(), isTrue);
  });

  test('map performance policy culls the complete dataset within budget', () {
    final report = _json('outputs/aphidex_1_3/map_performance_report.json');
    expect(report['datasetMarkers'], greaterThan(4000));
    expect(report['withinWidgetBudget'], isTrue);
    expect(
      report['estimatedMaximumRenderedMarkerWidgets'],
      lessThanOrEqualTo(report['widgetBudget'] as int),
    );
  });

  test('viewport culling includes only visible marker coordinates', () {
    final markers = [
      const LocationRecord(
        id: 'a',
        targetType: MapTargetType.creature,
        targetId: 'g2_a',
        layer: MapLayer.surface,
        u: .25,
        v: .25,
        type: 'spawn',
        conditional: false,
      ),
      const LocationRecord(
        id: 'b',
        targetType: MapTargetType.creature,
        targetId: 'g2_b',
        layer: MapLayer.surface,
        u: .75,
        v: .75,
        type: 'spawn',
        conditional: false,
      ),
    ];
    final visible = MapRepository.cull(
      markers,
      const Rect.fromLTWH(0, 0, .5, .5),
    );
    expect(visible.map((marker) => marker.id), ['a']);
  });

  test('G1 detail never authorizes the Grounded 2 map action', () {
    final enemy = Enemy(
      order: 1,
      defaultGold: false,
      id: 'g1_test_creature',
      speciesKey: 'test_creature',
      name: const LocalizedText(en: 'Test creature'),
      game: 'g1',
      tier: 1,
      danger: 'low',
      isBoss: false,
      weaknesses: const [],
      resistances: const [],
      cardNormal: '',
      cardGold: '',
      photo: '',
      locations: const [
        LocationRecord(
          id: 'invalid_g2_location',
          targetType: MapTargetType.creature,
          targetId: 'g1_test_creature',
          layer: MapLayer.surface,
          u: .5,
          v: .5,
          type: 'spawn',
          conditional: false,
        ),
      ],
      eventAppearances: const ['mixr_greenhouse'],
    );
    expect(canOpenCreatureMap(enemy), isFalse);
  });

  testWidgets('context map supports pinch, pan and marker selection', (
    tester,
  ) async {
    const markerRecord = LocationRecord(
      id: 'marker',
      targetType: MapTargetType.creature,
      targetId: 'g2_masked_fighter',
      layer: MapLayer.surface,
      u: .5,
      v: .5,
      type: 'spawn',
      conditional: false,
    );
    tester.view.physicalSize = const Size(430, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Builder(
            builder: (context) => buildMapCanvasForTesting(
              definition: _testMapDefinition,
              markers: const [markerRecord],
              onMarkerTap: (_) {
                showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => const SafeArea(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Ver criatura'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await _pumpFrames(tester, count: 80);
    final interactiveFinder = find.byKey(
      const ValueKey('map-interactive-viewer'),
    );
    expect(interactiveFinder, findsOneWidget);
    final viewer = tester.widget<InteractiveViewer>(interactiveFinder);
    final controller = viewer.transformationController!;
    final marker = find.byKey(const ValueKey('map-mini-card-marker'));
    expect(marker, findsAtLeastNWidgets(1));
    expect(marker.hitTestable(), findsAtLeastNWidgets(1));
    expect(tester.getSize(marker.first).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(marker.first).height, greaterThanOrEqualTo(48));
    await tester.tap(marker.first);
    await _pumpFrames(tester, count: 10);
    expect(find.text('Ver criatura'), findsOneWidget);
    await tester.tapAt(const Offset(8, 8));
    await _pumpFrames(tester, count: 5);

    final beforePinch = controller.value.storage.toList();
    final first = await tester.startGesture(const Offset(150, 420));
    final second = await tester.startGesture(const Offset(280, 420));
    await first.moveTo(const Offset(110, 420));
    await second.moveTo(const Offset(320, 420));
    await first.up();
    await second.up();
    await tester.pump();
    expect(controller.value.storage, isNot(equals(beforePinch)));

    final beforePan = controller.value.storage.toList();
    await tester.drag(interactiveFinder, const Offset(25, 20));
    await tester.pump();
    expect(controller.value.storage, isNot(equals(beforePan)));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('map progresses from clusters to pointers and cards by zoom', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const markers = [
      LocationRecord(
        id: 'a',
        targetType: MapTargetType.creature,
        targetId: 'g2_a',
        layer: MapLayer.surface,
        u: .49,
        v: .5,
        type: 'spawn',
        conditional: false,
      ),
      LocationRecord(
        id: 'b',
        targetType: MapTargetType.creature,
        targetId: 'g2_b',
        layer: MapLayer.surface,
        u: .51,
        v: .5,
        type: 'spawn',
        conditional: false,
      ),
    ];
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: buildMapCanvasForTesting(
            definition: _testMapDefinition,
            markers: markers,
            focusResults: false,
            onMarkerTap: (_) {},
          ),
        ),
      ),
    );
    await _pumpFrames(tester, count: 10);
    final viewerFinder = find.byKey(const ValueKey('map-interactive-viewer'));
    final viewer = tester.widget<InteractiveViewer>(viewerFinder);
    final controller = viewer.transformationController!;
    final cluster = find.byKey(const ValueKey('map-cluster-marker'));
    expect(cluster.hitTestable(), findsAtLeastNWidgets(1));
    final beforeClusterTap = controller.value.storage.toList();
    await tester.tap(cluster.first);
    await _pumpFrames(tester, count: 5);
    expect(controller.value.storage, isNot(equals(beforeClusterTap)));
    expect(
      find.byKey(const ValueKey('map-mini-card-marker')),
      findsAtLeastNWidgets(1),
    );

    controller.value = MapViewportTransform.frame(
      viewport: const Size(430, 800),
      texture: _testMapDefinition.textureSize,
      normalizedBounds: const Rect.fromLTWH(.37, .25, .26, .5),
    );
    await _pumpFrames(tester, count: 5);
    expect(
      find.byKey(const ValueKey('map-pointer-marker')),
      findsAtLeastNWidgets(1),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
