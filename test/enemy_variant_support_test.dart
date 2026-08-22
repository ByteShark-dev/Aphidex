import 'dart:convert';
import 'dart:io';

import 'package:aphidex/controllers/tutorial_controller.dart';
import 'package:aphidex/data/enemy_repository.dart';
import 'package:aphidex/data/enemy_variants.dart';
import 'package:aphidex/data/local_storage.dart';
import 'package:aphidex/i18n/app_localizations.dart';
import 'package:aphidex/models/enemy.dart';
import 'package:aphidex/models/enemy_index_entry.dart';
import 'package:aphidex/models/game_pick.dart';
import 'package:aphidex/screens/enemy_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

final TestFlutterView testerView = TestWidgetsFlutterBinding.ensureInitialized()
    .platformDispatcher
    .views
    .first;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;
  late Enemy g1BlackWorkerAnt;
  late Enemy g2BlackWorkerAnt;
  late Enemy g2Cricket;
  late Enemy g2Crow;
  late Future<ByteData?> Function(ByteData?) handler;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('aphidex_variants_');
    Hive.init(hiveDir.path);
    await Hive.openBox('aphidex');
  });

  tearDownAll(() async {
    await Hive.box('aphidex').close();
    await hiveDir.delete(recursive: true);
  });

  setUp(() async {
    await Hive.box('aphidex').clear();
    EnemyRepository.clearCaches();
    await LocalStorage.setBool(TutorialController.completionKey, true);
    await LocalStorage.setInt('ui_game_pick', GamePick.all.index);

    g1BlackWorkerAnt = Enemy.fromJson(_g1BlackWorkerAntJson);
    g2BlackWorkerAnt = Enemy.fromJson(_g2BlackWorkerAntJson);
    g2Cricket = Enemy.fromJson(_g2CricketJson);
    g2Crow = Enemy.fromJson(_g2CrowJson);

    handler = (message) async {
      final key = utf8.decode(
        message!.buffer.asUint8List(
          message.offsetInBytes,
          message.lengthInBytes,
        ),
      );

      if (key == 'AssetManifest.bin') {
        return const StandardMessageCodec().encodeMessage(<Object?, Object?>{});
      }
      if (key == 'AssetManifest.json') {
        return _stringData('{}');
      }
      if (key == 'FontManifest.json') {
        return _stringData('[]');
      }
      if (key.endsWith('assets/data/creatures/en/index_g1.json')) {
        return _stringData(jsonEncode([_indexEntry(_g1BlackWorkerAntJson)]));
      }
      if (key.endsWith('assets/data/creatures/en/index_g2.json')) {
        return _stringData(
          jsonEncode([
            _indexEntry(_g2BlackWorkerAntJson),
            _indexEntry(_g2CricketJson),
            _indexEntry(_g2CrowJson),
          ]),
        );
      }
      for (final entry in [
        _g1BlackWorkerAntJson,
        _g2BlackWorkerAntJson,
        _g2CricketJson,
        _g2CrowJson,
      ]) {
        if (key.endsWith(
          'assets/data/creatures/en/details/${entry['id']}.json',
        )) {
          return _stringData(jsonEncode(entry));
        }
      }
      return _transparentImage;
    };

    testerView.physicalSize = const Size(1080, 2400);
    testerView.devicePixelRatio = 1;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', handler);
  });

  tearDown(() {
    testerView.resetPhysicalSize();
    testerView.resetDevicePixelRatio();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  test('parses extended enemy content fields', () {
    expect(g2BlackWorkerAnt.speciesKey, 'black_worker_ant');
    expect(g2BlackWorkerAnt.temperament, 'neutral');
    expect(g2BlackWorkerAnt.loot, isNotEmpty);
    expect(g2BlackWorkerAnt.advancedLootTable, isNotEmpty);
    expect(g2BlackWorkerAnt.combatStats?.stunThreshold, 25);
    expect(g2BlackWorkerAnt.abilities, isNotEmpty);
    expect(g2BlackWorkerAnt.description?.resolve('en'), contains('veggie'));
    expect(g2Crow.collectionGroup, 'harmless');
    expect(g2Crow.tier, 5);
  });

  test('parses collection groups and boss phases', () {
    final boss = Enemy.fromJson(_g2BossPhaseJson);

    expect(boss.collectionGroup, 'angry');
    expect(boss.bossPhases, hasLength(2));
    expect(boss.bossPhases.first.attacks, isNotEmpty);
    expect(boss.bossPhases.last.startsAtHealthPct, 40);
  });

  test('parses multiple weak points and exposes them for the UI', () {
    final scorpion = Enemy.fromJson({
      ..._g2CricketJson,
      'id': 'g2_test_scorpion',
      'speciesKey': 'test_scorpion',
      'name': {
        'es': 'Escorpión de prueba',
        'en': 'Test Scorpion',
        'ru': 'Test Scorpion',
      },
      'weakPoint': {'part': 'stinger', 'susceptibleDamage': 'stabbing'},
      'weakPoints': [
        {'part': 'stinger', 'susceptibleDamage': 'stabbing'},
        {'part': 'rump', 'susceptibleDamage': 'any'},
      ],
    });

    expect(scorpion.weakPoint?.part, 'stinger');
    expect(scorpion.weakPoints, hasLength(2));
    expect(scorpion.resolvedWeakPoints.map((point) => point.part), [
      'stinger',
      'rump',
    ]);
  });

  test('groups shared species once in both games', () {
    final entries = groupEnemyListEntries([
      g1BlackWorkerAnt,
      g2BlackWorkerAnt,
      g2Cricket,
    ], mergeSharedSpecies: true);

    expect(entries, hasLength(2));
    expect(
      entries
          .firstWhere((entry) => entry.speciesKey == 'black_worker_ant')
          .variants,
      hasLength(2),
    );
    expect(
      entries.where((entry) => entry.speciesKey == 'black_worker_ant'),
      hasLength(1),
    );
  });

  test('shared species entries prefer the G2 variant by default', () {
    final entry = groupEnemyListEntries([
      g1BlackWorkerAnt,
      g2BlackWorkerAnt,
    ], mergeSharedSpecies: true).single;

    expect(entry.preferredVariant(preferG2Default: true).game, 'g2');
    expect(entry.preferredVariant(preferredGame: 'g1').game, 'g1');
  });

  test('shared index entries keep G1 as the default sort variant', () {
    final g1Mantis = EnemyIndexEntry.fromJson({
      'id': 'g1_mantis',
      'speciesKey': 'orchid_mantis',
      'name': 'Mantis',
      'game': 'g1',
      'tier': 3,
      'danger': 'imposible_alta',
      'isBoss': true,
      'order': 152,
      'defaultGold': false,
      'cardNormal': 'assets/g1/creatures/cards/normal/Creaturecard_Mantis.webp',
      'cardGold': 'assets/g1/creatures/cards/gold/Creaturecardgold_Mantis.webp',
      'weaknesses': ['salty'],
      'resistances': ['spicy'],
    });
    final g2OrchidMantis = EnemyIndexEntry.fromJson({
      'id': 'g2_orchid_mantis',
      'speciesKey': 'orchid_mantis',
      'collectionGroup': 'other',
      'name': 'Orchid Mantis',
      'game': 'g2',
      'tier': 3,
      'danger': 'imposible_alta',
      'isBoss': true,
      'order': 287,
      'defaultGold': false,
      'cardNormal': 'assets/g1/creatures/cards/normal/Creaturecard_Mantis.webp',
      'cardGold': 'assets/g1/creatures/cards/gold/Creaturecardgold_Mantis.webp',
      'weaknesses': ['salty'],
      'resistances': ['spicy'],
    });

    final entry = groupEnemyIndexEntries([
      g1Mantis,
      g2OrchidMantis,
    ], mergeSharedSpecies: true).single;

    expect(entry.preferredVariant(preferG2Default: true).game, 'g2');
    expect(entry.sortVariant().game, 'g1');
    expect(entry.sortVariant().order, 152);
  });

  test('variant preference key can be persisted per species', () async {
    await LocalStorage.setString('species_variant:black_worker_ant', 'g1');

    expect(LocalStorage.getString('species_variant:black_worker_ant'), 'g1');
  });

  testWidgets('single-game species detail does not show a variant switch', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(EnemyDetailScreen(enemy: g2Cricket)));
    await tester.pumpAndSettle();

    expect(find.byType(SegmentedButton<String>), findsNothing);
    expect(find.text('Cricket'), findsOneWidget);
  });

  testWidgets('Named C.R.O. selector applies stats and restores the base', (
    tester,
  ) async {
    final enemy = Enemy.fromJson(
      jsonDecode(
            File(
              'assets/data/creatures/en/details/g2_orc_black_soldier_ant.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>,
    );
    testerView.physicalSize = const Size(390, 844);

    await tester.pumpWidget(_buildTestApp(EnemyDetailScreen(enemy: enemy)));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('encounter-variant-picker')),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('encounter-variant-picker')),
    );
    await tester.tap(find.byKey(const ValueKey('encounter-variant-picker')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey(
          'encounter-variant-g2_wave_ant_soldier_black_augusta_orc_wave',
        ),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(
        const ValueKey(
          'encounter-variant-Ant_Soldier_Black_Augusta_ORC_A_Named',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Officer Tang'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('1350 HP'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('1350 HP'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 1600));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('encounter-variant-picker')),
    );
    await tester.tap(find.byKey(const ValueKey('encounter-variant-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('encounter-variant-base')));
    await tester.pumpAndSettle();
    expect(find.text(enemy.name.resolve('en')), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('${enemy.health!.value} HP'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('${enemy.health!.value} HP'), findsOneWidget);
  });

  testWidgets('Koi selector navigates only across the four G2 entries', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final key = utf8.decode(
            message!.buffer.asUint8List(
              message.offsetInBytes,
              message.lengthInBytes,
            ),
          );
          if (key == 'AssetManifest.bin') {
            return const StandardMessageCodec().encodeMessage(
              <Object?, Object?>{},
            );
          }
          if (key == 'AssetManifest.json') return _stringData('{}');
          if (key == 'FontManifest.json') return _stringData('[]');
          final assetOffset = key.indexOf('assets/data/');
          if (key.endsWith('.json') && assetOffset != -1) {
            final file = File(key.substring(assetOffset));
            if (file.existsSync()) {
              return _stringData(file.readAsStringSync());
            }
          }
          return _transparentImage;
        });
    EnemyRepository.clearCaches();
    final rows =
        (jsonDecode(
                  File(
                    'assets/data/creatures/en/index_g2.json',
                  ).readAsStringSync(),
                )
                as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(EnemyIndexEntry.fromJson)
            .where((entry) => entry.groupId == 'koi')
            .toList(growable: false);
    final sunny = rows.singleWhere((entry) => entry.id == 'g2_koi_sunny');
    await tester.runAsync(() async {
      for (final entry in rows) {
        await EnemyRepository.loadDetail(entry.game, entry.id, 'en');
      }
    });

    await tester.pumpWidget(
      _buildTestApp(
        EnemyDetailScreen(
          summary: sunny,
          variantSummaries: [sunny],
          relatedSummaries: rows,
        ),
      ),
    );
    await _pumpUntilVisible(
      tester,
      find.byKey(const ValueKey('related-entry-picker')),
    );
    await tester.tap(find.byKey(const ValueKey('related-entry-picker')));
    await tester.pumpAndSettle();
    final calicoOption = find.byKey(
      const ValueKey('related-entry-g2_koi_calico'),
    );
    await _pumpUntilVisible(tester, calicoOption);

    for (final entry in rows) {
      expect(find.byKey(ValueKey('related-entry-${entry.id}')), findsOneWidget);
    }

    await tester.tap(calicoOption);
    await _pumpUntilVisible(tester, find.text('Calico'));

    expect(find.text('Calico'), findsWidgets);
    final nextButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('related-entry-next')),
    );
    expect(nextButton.onPressed, isNotNull);
    nextButton.onPressed!();
    await tester.pumpAndSettle();
    await _pumpUntilVisible(tester, find.text('Oriole'));
    expect(find.text('Oriole'), findsWidgets);
  });

  testWidgets('detail rebuilds cleanly when the selected entry key changes', (
    tester,
  ) async {
    final selectedEnemy = ValueNotifier<Enemy>(g2Cricket);

    await tester.pumpWidget(
      _buildTestApp(
        ValueListenableBuilder<Enemy>(
          valueListenable: selectedEnemy,
          builder: (context, enemy, _) {
            return Scaffold(
              body: Column(
                children: [
                  Expanded(
                    child: EnemyDetailScreen(
                      key: ValueKey('detail:${enemy.id}'),
                      enemy: enemy,
                    ),
                  ),
                  TextButton(
                    onPressed: () => selectedEnemy.value = g2Crow,
                    child: const Text('switch'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('A powerful Grounded 2 insect.'), findsOneWidget);

    await tester.tap(find.text('switch'));
    await tester.pumpAndSettle();

    expect(find.text('Crow.'), findsOneWidget);
  });

  testWidgets(
    'detail shows inflicts icon row and collapsible sections start closed',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(EnemyDetailScreen(enemy: g2Cricket)),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('inflicts-effect-stabbing')),
        findsOneWidget,
      );
      expect(find.text('Cricket Drumstick'), findsNothing);
      expect(find.text('Fabulous Femur'), findsNothing);

      await tester.tap(find.text('Loot'));
      await tester.pumpAndSettle();

      expect(find.text('Cricket Drumstick'), findsOneWidget);
      expect(find.text('Fabulous Femur'), findsOneWidget);
    },
  );

  testWidgets('detail shows dedicated boss phases when available', (
    tester,
  ) async {
    final boss = Enemy.fromJson(_g2BossPhaseJson);

    await tester.pumpWidget(_buildTestApp(EnemyDetailScreen(enemy: boss)));
    await tester.pumpAndSettle();

    expect(find.text('Boss Phases'), findsOneWidget);
    expect(find.text('Phase 1'), findsOneWidget);
    expect(find.text('Phase 2'), findsOneWidget);
    expect(find.text('Opening duel phase.'), findsOneWidget);

    await tester.tap(find.text('Phase 2'));
    await tester.pumpAndSettle();

    expect(find.text('Escalates with faster pressure.'), findsOneWidget);
  });

  test('grouping without merge keeps real game variants separate', () {
    final entries = groupEnemyListEntries([
      g1BlackWorkerAnt,
      g2BlackWorkerAnt,
      g2Cricket,
    ], mergeSharedSpecies: false);

    expect(entries, hasLength(3));
    expect(
      entries.where((entry) => entry.speciesKey == 'black_worker_ant'),
      hasLength(2),
    );
  });
}

Widget _buildTestApp(Widget home) {
  return DefaultAssetBundle(
    bundle: _TestAssetBundle(),
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    ),
  );
}

Future<void> _pumpUntilVisible(WidgetTester tester, Finder finder) async {
  for (var tick = 0; tick < 40 && finder.evaluate().isEmpty; tick++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

ByteData _stringData(String value) {
  final bytes = Uint8List.fromList(utf8.encode(value));
  return ByteData.view(bytes.buffer);
}

Map<String, dynamic> _indexEntry(Map<String, dynamic> json) {
  final enemy = Enemy.fromJson(json);
  return {
    'id': enemy.id,
    'speciesKey': enemy.speciesKey,
    'name': enemy.name.resolve('en'),
    'game': enemy.game,
    'tier': enemy.tier,
    'danger': enemy.danger,
    'isBoss': enemy.isBoss,
    'order': enemy.order,
    'defaultGold': enemy.defaultGold,
    'cardNormal': enemy.cardNormal,
    'cardGold': enemy.cardGold,
    'weaknesses': enemy.weaknesses,
    'resistances': enemy.resistances,
    if (enemy.temperament != null) 'temperament': enemy.temperament,
    if (enemy.health != null)
      'health': {
        'rating': enemy.health!.rating,
        if (enemy.health!.value != null) 'value': enemy.health!.value,
      },
    if (enemy.collectionGroup != null) 'collectionGroup': enemy.collectionGroup,
  };
}

final ByteData _transparentImage = ByteData.view(
  Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4////fwAJ+wP9KobjigAAAABJRU5ErkJggg==',
    ),
  ).buffer,
);

class _TestAssetBundle extends CachingAssetBundle {
  static const _svg =
      '<svg viewBox="0 0 32 32" xmlns="http://www.w3.org/2000/svg">'
      '<rect width="32" height="32" fill="#ffffff"/></svg>';

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage(<Object?, Object?>{})!;
    }
    if (key == 'AssetManifest.json') {
      return _stringData('{}');
    }
    if (key == 'FontManifest.json') {
      return _stringData('[]');
    }
    if (key.endsWith('.svg')) {
      return _stringData(_svg);
    }
    return _transparentImage;
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key.endsWith('.svg')) {
      return _svg;
    }
    if (key == 'AssetManifest.json') {
      return '{}';
    }
    if (key == 'FontManifest.json') {
      return '[]';
    }
    return '';
  }
}

const Map<String, dynamic> _g1BlackWorkerAntJson = {
  'id': 'g1_black_worker_ant',
  'speciesKey': 'black_worker_ant',
  'name': {
    'es': 'Hormiga obrera negra',
    'en': 'Black Worker Ant',
    'ru': 'Чёрный рабочий муравей',
  },
  'game': 'g1',
  'temperament': 'neutral',
  'tier': 2,
  'danger': 'intermedia',
  'isBoss': false,
  'order': 102,
  'defaultGold': false,
  'cardNormal':
      'assets/g1/creatures/cards/normal/Creaturecard_Black_Worker_Ant.webp',
  'cardGold':
      'assets/g1/creatures/cards/gold/Creaturecardgold_Black_Worker_Ant.webp',
  'photo': 'assets/g1/creatures/photos/Black_Worker_Ant.webp',
  'description': {
    'es': 'Una hormiga más resistente del hormiguero negro.',
    'en': 'A tougher ant from the Black Anthill.',
    'ru': 'Более крепкий муравей из Чёрного муравейника.',
  },
  'environments': [
    {
      'es': 'Hormiguero negro',
      'en': 'Black Anthill',
      'ru': 'Чёрный муравейник',
    },
  ],
  'weaknesses': ['spicy', 'stabbing'],
  'resistances': ['fresh'],
  'health': {'rating': 2, 'value': 425},
  'elementalWeaknesses': [
    {'type': 'spicy', 'bonusPct': 50},
  ],
  'damageWeaknesses': [
    {'type': 'stabbing', 'bonusPct': 25},
  ],
  'resistancesV2': [
    {'type': 'fresh', 'bonusPct': 50},
  ],
  'loot': [
    {
      'section': 'loot',
      'item': {
        'es': 'Cabeza de hormiga negra',
        'en': 'Black Ant Head',
        'ru': 'Голова чёрного муравья',
      },
      'minCount': 0,
      'maxCount': 1,
    },
  ],
  'advancedLootTable': [
    {
      'item': {
        'es': 'Cabeza de hormiga negra',
        'en': 'Black Ant Head',
        'ru': 'Голова чёрного муравья',
      },
      'countLabel': 'x1',
      'chancePct': 30,
    },
  ],
  'combatStats': {
    'health': 425,
    'attackDamageSummary': {
      'es': 'Mordisco: ~36.',
      'en': 'Nibble: ~36.',
      'ru': 'Укус: ~36.',
    },
  },
  'inflicts': [
    {'es': 'Daño cortante', 'en': 'Chopping damage', 'ru': 'Рубящий урон'},
  ],
  'abilities': [
    {
      'name': {'es': 'Mordisco', 'en': 'Nibble', 'ru': 'Укус'},
      'blockable': true,
      'breaksGuard': false,
      'staggers': false,
      'description': {
        'es': 'Ataque rápido.',
        'en': 'Quick bite.',
        'ru': 'Быстрый укус.',
      },
    },
  ],
  'behavior': {
    'es': 'Patrulla con otras hormigas negras.',
    'en': 'It patrols with other black ants.',
    'ru': 'Патрулирует вместе с другими чёрными муравьями.',
  },
  'interactionWithPlayer': {
    'es': 'Permanece neutral hasta que la provocas.',
    'en': 'It stays neutral until provoked.',
    'ru': 'Остаётся нейтральной, пока её не спровоцируют.',
  },
  'interactionWithCreatures': {
    'es': 'Acude rápido cuando otra hormiga entra en combate.',
    'en': 'It joins quickly when another ant enters combat.',
    'ru': 'Быстро подключается, когда другая муравьиха вступает в бой.',
  },
  'strategy': {
    'es': 'Usa picante y perforación.',
    'en': 'Use spicy and stabbing damage.',
    'ru': 'Используйте острый и колющий урон.',
  },
};

const Map<String, dynamic> _g2BlackWorkerAntJson = {
  'id': 'g2_black_worker_ant',
  'speciesKey': 'black_worker_ant',
  'name': {
    'es': 'Hormiga obrera negra',
    'en': 'Black Worker Ant',
    'ru': 'Чёрный рабочий муравей',
  },
  'game': 'g2',
  'temperament': 'neutral',
  'tier': 2,
  'danger': 'intermedia',
  'isBoss': false,
  'order': 201,
  'defaultGold': false,
  'cardNormal': 'assets/g2/creatures/cards/Creaturecard_Black_Worker_AntG2.png',
  'cardGold':
      'assets/g2/creatures/cards_golden/Creaturecardgold_Black_Worker_Ant.png',
  'photo': 'assets/g1/creatures/photos/Black_Worker_Ant.webp',
  'description': {
    'es': 'Ahora aparece en el huerto vegetal y el hormiguero en guerra.',
    'en': 'It now appears around the veggie garden and the war-torn anthill.',
    'ru': 'Теперь встречается в огороде и разорённом муравейнике.',
  },
  'environments': [
    {'es': 'Huerto vegetal', 'en': 'Veggie Garden', 'ru': 'Огород'},
  ],
  'respawnInfo': {'es': '1 día', 'en': '1 day', 'ru': '1 день'},
  'weaknesses': ['spicy', 'stabbing'],
  'resistances': ['sour'],
  'health': {'rating': 2, 'value': 270},
  'elementalWeaknesses': [
    {'type': 'spicy', 'bonusPct': 25},
  ],
  'damageWeaknesses': [
    {'type': 'stabbing', 'bonusPct': 25},
  ],
  'resistancesV2': [
    {'type': 'sour', 'bonusPct': 75},
  ],
  'weakPoint': {'part': 'eyes', 'susceptibleDamage': 'stabbing_arrows_only'},
  'loot': [
    {
      'section': 'loot',
      'item': {
        'es': 'Cabeza de hormiga negra',
        'en': 'Black Ant Head',
        'ru': 'Голова чёрного муравья',
      },
      'minCount': 0,
      'maxCount': 1,
    },
  ],
  'advancedLootTable': [
    {
      'item': {
        'es': 'Huevo de hormiga negra',
        'en': 'Black Ant Egg',
        'ru': 'Яйцо чёрного муравья',
      },
      'countLabel': 'x2',
      'chancePct': 1,
    },
  ],
  'combatStats': {
    'health': 270,
    'stunThreshold': 25,
    'stunCooldownSeconds': 15,
    'attackDamageSummary': {
      'es': 'Mordisco: 48.',
      'en': 'Bite: 48.',
      'ru': 'Укус: 48.',
    },
  },
  'inflicts': [
    {'es': 'Daño cortante', 'en': 'Chopping damage', 'ru': 'Рубящий урон'},
  ],
  'specialTraits': [
    {
      'es': 'Debilidad al agua: +100%',
      'en': 'Water weakness: +100%',
      'ru': 'Слабость к воде: +100%',
    },
  ],
  'abilities': [
    {
      'name': {'es': 'Mordisco', 'en': 'Bite', 'ru': 'Укус'},
      'blockable': true,
      'breaksGuard': false,
      'staggers': false,
      'description': {
        'es': 'Mordisco directo.',
        'en': 'Direct bite.',
        'ru': 'Прямой укус.',
      },
    },
  ],
  'behavior': {
    'es': 'Patrulla el hormiguero y el jardín.',
    'en': 'It patrols the anthill and the garden.',
    'ru': 'Патрулирует муравейник и сад.',
  },
  'interactionWithPlayer': {
    'es': 'Se vuelve hostil si la provocas.',
    'en': 'It turns hostile if provoked.',
    'ru': 'Становится враждебной при провокации.',
  },
  'interactionWithCreatures': {
    'es': 'Se apoya en otras hormigas negras.',
    'en': 'It relies on other black ants.',
    'ru': 'Опирается на других чёрных муравьёв.',
  },
  'strategy': {
    'es': 'Aprovecha el picante y la perforación.',
    'en': 'Exploit spicy and stabbing damage.',
    'ru': 'Используйте острый и колющий урон.',
  },
};

const Map<String, dynamic> _g2CricketJson = {
  'id': 'g2_cricket',
  'speciesKey': 'cricket',
  'name': {'es': 'Grillo', 'en': 'Cricket', 'ru': 'Сверчок'},
  'game': 'g2',
  'temperament': 'neutral',
  'tier': 3,
  'danger': 'alta',
  'isBoss': false,
  'order': 202,
  'defaultGold': false,
  'cardNormal': 'assets/g2/creatures/cards/Creaturecard_Cricket.png',
  'cardGold': 'assets/g2/creatures/cards_golden/Creaturecardgold_Cricket.png',
  'photo': 'assets/global/Aphidex_Proximamente.webp',
  'description': {
    'es': 'Un insecto potente de Grounded 2.',
    'en': 'A powerful Grounded 2 insect.',
    'ru': 'Мощное насекомое Grounded 2.',
  },
  'weaknesses': ['fresh', 'busting'],
  'resistances': ['spicy', 'stabbing'],
  'health': {'rating': 4, 'value': 1400},
  'elementalWeaknesses': [
    {'type': 'fresh', 'bonusPct': 50},
  ],
  'damageWeaknesses': [
    {'type': 'busting', 'bonusPct': 25},
  ],
  'resistancesV2': [
    {'type': 'spicy', 'bonusPct': 25},
    {'type': 'stabbing', 'bonusPct': 25},
  ],
  'loot': [
    {
      'section': 'loot',
      'item': {
        'es': 'Muslo de grillo',
        'en': 'Cricket Drumstick',
        'ru': 'Ножка сверчка',
      },
      'minCount': 0,
      'maxCount': 2,
    },
  ],
  'advancedLootTable': [
    {
      'item': {
        'es': 'Fémur fabuloso',
        'en': 'Fabulous Femur',
        'ru': 'Чудесная бедренная кость',
      },
      'countLabel': 'x1',
      'chancePct': 4,
    },
  ],
  'combatStats': {
    'health': 1400,
    'stunThreshold': 75,
    'stunCooldownSeconds': 5,
    'attackDamageSummary': {
      'es': 'Salto mortal: 120.',
      'en': 'Leap of Faith: 120.',
      'ru': 'Прыжок веры: 120.',
    },
  },
  'inflictsEffects': ['stabbing'],
  'inflicts': [
    {'es': 'Daño perforante', 'en': 'Stabbing damage', 'ru': 'Колющий урон'},
  ],
  'abilities': [
    {
      'name': {
        'es': 'Salto mortal',
        'en': 'Leap of Faith',
        'ru': 'Прыжок веры',
      },
      'blockable': false,
      'breaksGuard': false,
      'staggers': false,
      'description': {
        'es': 'Salta encima del objetivo.',
        'en': 'Leaps onto the target.',
        'ru': 'Прыгает на цель.',
      },
    },
  ],
};

const Map<String, dynamic> _g2CrowJson = {
  'id': 'g2_crow',
  'speciesKey': 'crow',
  'collectionGroup': 'harmless',
  'name': {'es': 'Cuervo', 'en': 'Crow', 'ru': 'Ð§Ñ‘Ñ€Ð½Ñ‹Ð¹ Ñ€ÐµÐºÑ?'},
  'game': 'g2',
  'temperament': 'peaceful',
  'tier': 5,
  'danger': 'baja',
  'isBoss': false,
  'order': 275,
  'defaultGold': false,
  'cardNormal': 'assets/g2/creatures/cards/Creaturecard_Crow.png',
  'cardGold': 'assets/g2/creatures/cards_golden/Creaturecardgold_Crow.png',
  'photo': 'assets/g1/creatures/photos/Crow.jpg',
  'description': {'es': 'Cuervo.', 'en': 'Crow.', 'ru': 'Crow.'},
  'behavior': {'es': 'Neutral.', 'en': 'Neutral.', 'ru': 'Neutral.'},
  'interactionWithPlayer': {
    'es': 'Neutral.',
    'en': 'Neutral.',
    'ru': 'Neutral.',
  },
};

const Map<String, dynamic> _g2BossPhaseJson = {
  'id': 'g2_masked_stranger',
  'speciesKey': 'masked_stranger',
  'collectionGroup': 'angry',
  'name': {
    'es': 'Desconocida Enmascarada',
    'en': 'Masked Stranger',
    'ru': 'Masked Stranger',
  },
  'game': 'g2',
  'temperament': 'aggressive',
  'tier': 5,
  'danger': 'extrema',
  'isBoss': true,
  'order': 256,
  'defaultGold': false,
  'cardNormal': 'assets/g2/creatures/cards/Creaturecard_Masked_Stranger.png',
  'cardGold':
      'assets/g2/creatures/cards_golden/Creaturecardgold_Masked_Stranger.png',
  'photo': 'assets/global/Aphidex_Proximamente.webp',
  'description': {
    'es': 'Jefe de historia de Grounded 2.',
    'en': 'Story boss from Grounded 2.',
    'ru': 'Story boss from Grounded 2.',
  },
  'health': {'rating': 5, 'value': 1875},
  'bossPhases': [
    {
      'id': 'phase1',
      'label': {'es': 'Fase 1', 'en': 'Phase 1', 'ru': 'Фаза 1'},
      'summary': {
        'es': 'Fase inicial de duelo.',
        'en': 'Opening duel phase.',
        'ru': 'Opening duel phase.',
      },
      'attacks': [
        {
          'name': {
            'es': 'Ataque básico',
            'en': 'Basic Attack',
            'ru': 'Basic Attack',
          },
          'tags': ['melee'],
          'notes': {
            'es': 'Tajo base.',
            'en': 'Base slash.',
            'ru': 'Base slash.',
          },
        },
      ],
    },
    {
      'id': 'phase2',
      'label': {'es': 'Fase 2', 'en': 'Phase 2', 'ru': 'Фаза 2'},
      'startsAtHealthPct': 40,
      'summary': {
        'es': 'Escala la presión.',
        'en': 'Escalates with faster pressure.',
        'ru': 'Escalates with faster pressure.',
      },
      'aggressionChange': {
        'es': 'Más agresiva.',
        'en': 'More aggressive.',
        'ru': 'More aggressive.',
      },
      'abilities': [
        {
          'name': {
            'es': 'Combo giratorio',
            'en': 'Spin Combo',
            'ru': 'Spin Combo',
          },
          'description': {
            'es': 'Combo más rápido.',
            'en': 'Faster combo.',
            'ru': 'Faster combo.',
          },
        },
      ],
    },
  ],
};
