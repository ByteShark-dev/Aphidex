import 'dart:convert';
import 'dart:io';

import 'package:aphidex/data/entity_asset_resolver.dart';
import 'package:aphidex/data/creature_card_state.dart';
import 'package:aphidex/data/ui_mapper.dart';
import 'package:aphidex/data/weakpoint_resolver.dart';
import 'package:aphidex/i18n/app_localizations.dart';
import 'package:aphidex/models/catalog_entry_kind.dart';
import 'package:aphidex/models/creature_card_support.dart';
import 'package:aphidex/models/defense_event.dart';
import 'package:aphidex/models/enemy.dart';
import 'package:aphidex/models/enemy_index_entry.dart';
import 'package:aphidex/screens/defense_detail_screen.dart';
import 'package:aphidex/screens/map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

dynamic readJson(String path) => jsonDecode(File(path).readAsStringSync());

Map<String, dynamic> detail(String language, String id) =>
    (readJson('assets/data/creatures/$language/details/$id.json') as Map)
        .cast<String, dynamic>();

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'aphidex-final-unification-test',
    );
    Hive.init(hiveDirectory.path);
    await Hive.openBox('aphidex');
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  group('presentation overrides', () {
    for (final language in ['es', 'en', 'ru']) {
      test('tadpole and water boatman are peaceful in $language', () {
        final index =
            (readJson('assets/data/creatures/$language/index_g2.json') as List)
                .cast<Map<String, dynamic>>();
        for (final id in ['g2_tadpole', 'g2_water_boatman']) {
          final entry = index.singleWhere((row) => row['id'] == id);
          expect(entry['temperament'], 'peaceful');
          expect(entry['collectionGroup'], 'harmless');
          final enemy = detail(language, id);
          expect(enemy['temperament'], 'peaceful');
          expect(enemy['collectionGroup'], 'harmless');
        }
      });
    }

    test('all four Koi keep source HP but hide it in presentation', () {
      for (final id in [
        'g2_koi_calico',
        'g2_koi_dagon',
        'g2_koi_oriole',
        'g2_koi_sunny',
      ]) {
        final raw = detail('en', id);
        final enemy = Enemy.fromJson(raw);
        expect(enemy.hideHealth, isTrue);
        expect(enemy.combatStats?.health, 2000000000);
        expect(enemy.health?.value, 2000000000);
        expect(enemy.cardNormal, isEmpty);
        expect(enemy.cardGold, isNotEmpty);
        expect(enemy.defaultGold, isTrue);
        expect(enemy.hasSelectableCardVariants, isFalse);
        expect(enemy.defaultCardVariant, CreatureCardVariant.gold);
        expect(
          nextCreatureCardProgress(enemy, CreatureCardProgress.unowned),
          CreatureCardProgress.gold,
        );
      }
    });

    test('C.R.O. Broodmother inherits appearance reference only', () {
      final raw = detail('en', 'g2_orc_broodmother');
      expect(raw['appearanceSourceId'], 'subject_v_greenhouse');
      expect(raw['appearanceSourceTargetId'], 'g2_masked_fighter');
      expect(raw['technicalId'], 'SpiderBossBroodmother');
      expect(raw['id'], 'g2_orc_broodmother');
    });

    test('community danger calibration covers bosses and new entries', () {
      final index = (readJson('assets/data/creatures/en/index_g2.json') as List)
          .cast<Map<String, dynamic>>();
      Map<String, dynamic> entry(String id) =>
          index.singleWhere((row) => row['id'] == id);

      for (final id in ['g2_tadpole', 'g2_water_boatman', 'g2_woolly_aphid']) {
        expect(entry(id)['danger'], 'baja', reason: id);
      }
      expect(entry('g2_masked_fighter')['danger'], 'alta');
      expect(entry('g2_masked_stranger')['danger'], 'muy_alta');
      expect(entry('g2_orc_broodmother')['danger'], 'muy_alta');
      expect(entry('g2_axl')['danger'], 'imposible_superior');
      expect(entry('g2_king_dozer')['danger'], 'imposible_superior');
      expect(entry('g2_ogrr_toe_biter_leviathan')['danger'], 'extrema');
      expect(entry('g2_orchid_mantis')['danger'], 'proximamente');
      expect(index.where((row) => row['danger'] == 'unknown'), isEmpty);
    });
  });

  group('strict asset usages', () {
    test('special catalog entries use the supplied logos', () {
      final index = (readJson('assets/data/creatures/en/index_g2.json') as List)
          .cast<Map<String, dynamic>>();
      final waves = EnemyIndexEntry.fromJson(
        index.singleWhere((row) => row['id'] == 'g2_masked_stranger_orc_waves'),
      );
      final mixr = EnemyIndexEntry.fromJson(
        index.singleWhere((row) => row['id'] == 'g2_mixr_defenses'),
      );
      expect(waves.entryKind, CatalogEntryKind.special);
      expect(
        EntityAssetResolver.resolveEnemyIndex(
          waves,
          EntityAssetUsage.customEntry,
        ).asset,
        'assets/g2/defenses/Masked_Stranger_ORC_Waves_Icon.png',
      );
      expect(
        EntityAssetResolver.resolveEnemyIndex(
          mixr,
          EntityAssetUsage.customEntry,
        ).asset,
        'assets/g2/defenses/MIXR_Entry_Icon.png',
      );
      expect(File(UiMapper.rewardIcon('raw_science')).existsSync(), isTrue);
    });

    test('derived thumbnails never replace list or map Creature Cards', () {
      final index = (readJson('assets/data/creatures/en/index_g2.json') as List)
          .cast<Map<String, dynamic>>();
      for (final row in index) {
        expect(
          (row['listIconAsset'] ?? '').toString(),
          isNot(startsWith('assets/g2/creatures/thumbnails/')),
        );
      }
      final bee = EnemyIndexEntry.fromJson(
        index.singleWhere((row) => row['id'] == 'g2_bee'),
      );
      final card = EntityAssetResolver.resolveEnemyIndex(
        bee,
        EntityAssetUsage.card,
      );
      expect(card.asset, bee.cardNormal);
      expect(card.asset, isNot(bee.mapMarkerAsset));
      expect(mapCreatureCardAsset(bee), bee.cardNormal);
      expect(mapCreatureCardAsset(bee), isNot(bee.mapMarkerAsset));
    });

    test('G1 special entries retain their historical list assets', () {
      final index = (readJson('assets/data/creatures/en/index_g1.json') as List)
          .cast<Map<String, dynamic>>();
      for (final id in [
        'g1_enemy_infused',
        'g1_enemy_orc',
        'g1_factional_raids',
        'g1_mixr_defenses',
        'g1_spicy_coaltana_event',
        'g1_javamatic_cable_defense',
      ]) {
        final entry = EnemyIndexEntry.fromJson(
          index.singleWhere((row) => row['id'] == id),
        );
        final resolved = EntityAssetResolver.resolveListEntry(entry);
        expect(resolved.asset, entry.listIconAsset, reason: id);
        expect(resolved.fallbackUsed, isFalse, reason: id);
        expect(File(resolved.asset).existsSync(), isTrue, reason: id);
      }
    });

    test('all 48 trinkets resolve a real material icon', () {
      final equipment = (readJson('assets/data/g2/equipment.json') as Map)
          .cast<String, dynamic>();
      final trinkets = (equipment['items'] as List)
          .whereType<Map>()
          .map((row) => row.cast<String, dynamic>())
          .where((row) => row['domain'] == 'trinket')
          .toList();
      expect(trinkets, hasLength(48));
      for (final item in trinkets) {
        expect(item['icon'], isNotEmpty, reason: item['id'].toString());
        expect(File(item['icon'].toString()).existsSync(), isTrue);
        expect(item['iconProvenance'], 'material_instance_icon_parameter');
      }
    });
  });

  group('weakpoints and actions', () {
    test('Bee families retain eyes, projectile piercing and bows', () {
      const resolver = AphidexWeakpointResolver();
      for (final id in ['g2_bee', 'g2_orc_bee']) {
        final enemy = Enemy.fromJson(detail('en', id));
        final presentation = resolver.resolve(enemy.resolvedWeakPoints.single);
        expect(presentation.region, 'eyes');
        expect(presentation.effectiveDamage, 'projectile_piercing');
        expect(presentation.weaponFamilies, ['bow', 'crossbow']);
        expect(presentation.iconAsset, contains('Weakspot_Eyes'));
      }
    });

    test('unknown weakpoint never borrows another region icon', () {
      const resolver = AphidexWeakpointResolver();
      final presentation = resolver.resolve(
        const WeakPointInfo(
          part: 'unknown appendage',
          susceptibleDamage: 'unknown',
        ),
      );
      expect(presentation.region, 'unknown');
      expect(presentation.iconAsset, contains('Generic_Damage'));
    });

    test('non-offensive actions carry explicit classifications', () {
      final report =
          (readJson('outputs/aphidex_1_3/attack_action_classification_report.json')
                  as Map)
              .cast<String, dynamic>();
      final actions = (report['actions'] as List).cast<Map<String, dynamic>>();
      expect(
        actions.any((row) => row['actionType'] == 'defensive_action'),
        isTrue,
      );
      expect(
        actions.any((row) => row['actionType'] == 'movement_action'),
        isTrue,
      );
      expect(
        actions
            .where(
              (row) => const {
                'defensive_action',
                'movement_action',
                'summon_action',
              }.contains(row['actionType']),
            )
            .every((row) => row['offensiveFieldsVisible'] == false),
        isTrue,
      );
    });
  });

  group('defense domain', () {
    test('MIX.R and Ice Sickles share DefenseDetail contracts', () {
      final payload = (readJson('assets/data/g2/defenses.json') as Map)
          .cast<String, dynamic>();
      final entries = (payload['entries'] as List)
          .whereType<Map>()
          .map((row) => DefenseDetail.fromJson(row.cast<String, dynamic>()))
          .toList();
      expect(entries, hasLength(2));
      final mixr = entries.singleWhere((row) => row.id == 'g2_mixr_defenses');
      final ice = entries.singleWhere(
        (row) => row.id == 'g2_ice_sickles_event',
      );
      expect(mixr.variants, hasLength(3));
      expect(
        mixr.variants.every((row) => row.rewards.rawScience == 4000),
        isTrue,
      );
      expect(
        mixr.variants.every(
          (row) => row.markerAsset == 'assets/g2/defenses/MIXR_Map_Marker.png',
        ),
        isTrue,
      );
      expect(ice.variants, hasLength(1));
      expect(ice.variants.single.groups, hasLength(29));
      expect(ice.variants.single.totalCreatures, 31);
      expect(
        ice.variants.single.rewards.equipment.single.id,
        'EarwigSicklesUnique',
      );
      expect(
        ice.variants.single.rewards.mutationProgress.single.amount,
        isNull,
      );
    });

    test('pending MIX.R images stay out of missing images', () {
      final pending =
          (readJson('outputs/aphidex_1_3/known_pending_assets.json')
                  as Map)['items']
              as List;
      final missing =
          (readJson('outputs/aphidex_1_3/missing_images_report.json')
                  as Map)['items']
              as List;
      expect(pending.map((row) => (row as Map)['id']).toSet(), {
        'mixr_picnic',
        'mixr_resting',
      });
      expect(
        missing.any(
          (row) => const {
            'mixr_picnic',
            'mixr_resting',
          }.contains((row as Map)['id']),
        ),
        isFalse,
      );
    });

    testWidgets('MIX.R renders the shared defense composition on mobile', (
      tester,
    ) async {
      final rawDefenses =
          (readJson('assets/data/g2/defenses.json')
                  as Map<String, dynamic>)['entries']
              as List;
      final defense = DefenseDetail.fromJson(
        rawDefenses
            .whereType<Map>()
            .singleWhere((row) => row['id'] == 'g2_mixr_defenses')
            .cast<String, dynamic>(),
      );
      final enemies =
          (readJson('assets/data/creatures/es/index_g2.json') as List)
              .whereType<Map>()
              .map(
                (row) => EnemyIndexEntry.fromJson(row.cast<String, dynamic>()),
              )
              .toList();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: DefenseDetailScreen(
            defenseId: 'g2_mixr_defenses',
            defenseOverride: defense,
            enemiesOverride: enemies,
          ),
        ),
      );
      for (var i = 0; i < 20 && find.text('MIX.R').evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      final mixrText = tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data)
          .whereType<String>()
          .toList();
      expect(find.text('MIX.R'), findsOneWidget, reason: '$mixrText');
      expect(find.text('Grupos/oleadas programadas'), findsOneWidget);
      expect(find.text('Recompensas'), findsOneWidget);
      expect(find.textContaining('Ciencia pura'), findsOneWidget);
      expect(find.textContaining('4000'), findsWidgets);
      expect(
        find.byKey(const ValueKey('raw-science-reward-icon')),
        findsOneWidget,
      );
    });

    testWidgets('Ice Sickles reuses defense UI on tablet', (tester) async {
      final rawDefenses =
          (readJson('assets/data/g2/defenses.json')
                  as Map<String, dynamic>)['entries']
              as List;
      final defense = DefenseDetail.fromJson(
        rawDefenses
            .whereType<Map>()
            .singleWhere((row) => row['id'] == 'g2_ice_sickles_event')
            .cast<String, dynamic>(),
      );
      final enemies =
          (readJson('assets/data/creatures/en/index_g2.json') as List)
              .whereType<Map>()
              .map(
                (row) => EnemyIndexEntry.fromJson(row.cast<String, dynamic>()),
              )
              .toList();
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: DefenseDetailScreen(
            defenseId: 'g2_ice_sickles_event',
            defenseOverride: defense,
            enemiesOverride: enemies,
          ),
        ),
      );
      for (
        var i = 0;
        i < 20 && find.text('Scheduled groups').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      final iceText = tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data)
          .whereType<String>()
          .toList();
      expect(find.text('Ice Sickles'), findsWidgets, reason: '$iceText');
      expect(find.text('Scheduled groups'), findsOneWidget);
      expect(find.text('Attackers: 31'), findsOneWidget);
      expect(find.text('EarwigSicklesUnique'), findsNothing);
    });
  });
}
