import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  group('Aphidex 1.3 normalized snapshots', () {
    final manifest = _json('migration/aphidex_1_3/source_manifest.json');
    final equipment = _json('assets/data/g2/equipment.json');
    final map = _json('assets/data/g2/map.json');
    final mixr = _json('assets/data/g2/mixr.json');
    final creatures = _json('assets/data/g2/creatures.json');

    test('keeps the source-backed scope and reproducibility metadata', () {
      expect(manifest['version'], '1.3.0');
      expect((manifest['excludedTechnicalIds'] as List), hasLength(24));
      expect((manifest['editorialMappings'] as List), hasLength(38));
      expect(
        (manifest['snapshotSha256'] as Map).keys,
        containsAll(<String>['equipment.json', 'map.json', 'mixr.json']),
      );
    });

    test(
      'maps all editorial rows and retains all four fields in every language',
      () {
        for (final mapping
            in (manifest['editorialMappings'] as List).cast<Map>()) {
          final id = mapping['id'];
          for (final language in const ['es', 'en', 'ru']) {
            final detail = _json(
              'assets/data/creatures/$language/details/$id.json',
            );
            for (final field in const [
              'behavior',
              'interactionWithPlayer',
              'interactionWithCreatures',
              'strategy',
            ]) {
              expect(
                detail[field],
                isA<String>().having(
                  (value) => value.trim(),
                  field,
                  isNotEmpty,
                ),
              );
            }
          }
        }
      },
    );

    test('equipment and unresolved acquisition status stay explicit', () {
      final items = (equipment['items'] as List).cast<Map>();
      expect(items, hasLength(209));
      expect(equipment['armorSets'], hasLength(29));
      expect(
        items.where(
          (item) =>
              (item['acquisition'] as Map)['status'] ==
              'unresolved_acquisition',
        ),
        hasLength(11),
      );
      for (final item in items) {
        expect((item['name'] as Map).keys, containsAll(['en', 'es', 'ru']));
        expect(
          (item['translationStatus'] as Map)['ru'],
          'pending_native_review',
        );
      }
    });

    test(
      'coordinates are normalized and event-only creatures have no natural marker',
      () {
        final markers = (map['markers'] as List).cast<Map>();
        expect(
          markers.where((item) => item['targetType'] == 'creature'),
          hasLength(4452),
        );
        expect(
          markers.where((item) => item['targetType'] == 'equipment'),
          hasLength(13),
        );
        for (final marker in markers) {
          expect(marker['u'] as num, inInclusiveRange(0, 1));
          expect(marker['v'] as num, inInclusiveRange(0, 1));
        }
        final eventOnly = Directory('assets/data/creatures/en/details')
            .listSync()
            .whereType<File>()
            .map((file) => _json(file.path))
            .where(
              (item) =>
                  (item['eventAppearances'] as List? ?? const []).isNotEmpty,
            )
            .toList();
        expect(eventOnly, hasLength(2));
        expect(
          eventOnly.every((item) => (item['locations'] as List).isEmpty),
          isTrue,
        );
      },
    );

    test('MIX.R uses three variants and source schedule groups', () {
      final variants = (mixr['variants'] as List).cast<Map>();
      expect(variants, hasLength(3));
      expect(
        variants.expand((item) => item['scheduledGroups'] as List),
        hasLength(67),
      );
      expect(mixr['scheduledGroupPolicy'], 'source_index_not_official_wave');
    });

    test('known MIX.R pending assets are isolated from missing images', () {
      final pending = _json('outputs/aphidex_1_3/known_pending_assets.json');
      final missing = _json('outputs/aphidex_1_3/missing_images_report.json');
      final pendingIds = (pending['items'] as List)
          .cast<Map>()
          .map((item) => item['id'])
          .toSet();
      expect(pendingIds, {'mixr_picnic', 'mixr_resting'});
      expect(
        (missing['items'] as List).cast<Map>().where(
          (item) => pendingIds.contains(item['id']),
        ),
        isEmpty,
      );
    });

    test('creature UI parity has no silent important data loss', () {
      final parity = _json(
        'outputs/aphidex_1_3/creature_ui_data_parity_report.json',
      );
      expect(parity['importantDataLossCount'], 0);
      expect(parity['creatures'], hasLength(132));
    });

    test('legacy exclusions never enter the normalized UI snapshot', () {
      final excluded = (manifest['excludedTechnicalIds'] as List).toSet();
      final technicalIds = (creatures['creatures'] as List)
          .cast<Map>()
          .map((row) => row['technicalId'])
          .whereType<String>()
          .toSet();
      expect(technicalIds.intersection(excluded), isEmpty);
    });

    test('map validation includes five cases per layer and no outliers', () {
      final report = _json(
        'outputs/aphidex_1_3/map_coordinate_validation_report.json',
      );
      expect(report['pointsOutOfBounds'], isEmpty);
      final cases = report['verifiedCases'] as Map;
      expect(cases['surface'], hasLength(5));
      expect(cases['abyss'], hasLength(5));
    });
  });
}
