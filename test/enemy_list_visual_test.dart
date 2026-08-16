import 'dart:convert';
import 'dart:io';

import 'package:aphidex/controllers/favorites_controller.dart';
import 'package:aphidex/controllers/gold_controller.dart';
import 'package:aphidex/controllers/monetization_controller.dart';
import 'package:aphidex/controllers/tutorial_controller.dart';
import 'package:aphidex/data/enemy_repository.dart';
import 'package:aphidex/data/creature_card_state.dart';
import 'package:aphidex/data/local_storage.dart';
import 'package:aphidex/i18n/app_localizations.dart';
import 'package:aphidex/models/creature_card_support.dart';
import 'package:aphidex/models/enemy.dart';
import 'package:aphidex/models/enemy_index_entry.dart';
import 'package:aphidex/models/game_pick.dart';
import 'package:aphidex/controllers/review_prompt_controller.dart';
import 'package:aphidex/screens/enemy_detail_screen.dart';
import 'package:aphidex/screens/enemy_list_screen.dart';
import 'package:aphidex/widgets/state_panels.dart';
import 'package:aphidex/widgets/tutorial_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

final TestFlutterView listTesterView =
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;
  late Future<ByteData?> Function(ByteData?) handler;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('aphidex_list_visual_');
    Hive.init(hiveDir.path);
    await Hive.openBox('aphidex');
  });

  tearDownAll(() async {
    await Hive.box('aphidex').close();
  });

  setUp(() async {
    await Hive.box('aphidex').clear();
    await FavoritesController.instance.reset();
    await GoldController.instance.reset();
    EnemyRepository.clearCaches();
    await LocalStorage.setBool(TutorialController.completionKey, true);
    await LocalStorage.setInt('ui_game_pick', GamePick.g2.index);
    await LocalStorage.setBool('review_prompt_disabled_forever', true);
    await LocalStorage.setBool('monetization_ads_removed', true);
    MonetizationController.instance.adsRemoved.value = true;

    listTesterView.physicalSize = const Size(390, 844);
    listTesterView.devicePixelRatio = 1.0;

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
      if (key.endsWith('.svg')) {
        return _stringData(_svg);
      }
      if (key.endsWith('assets/data/creatures/en/index_g1.json')) {
        return _stringData('[]');
      }
      if (key.endsWith('assets/data/creatures/en/index_g2.json')) {
        return _stringData(
          jsonEncode([
            _indexEntry(_regularEnemyJson),
            _indexEntry(_eventEntryJson),
          ]),
        );
      }
      for (final entry in [_regularEnemyJson, _eventEntryJson]) {
        if (key.endsWith(
          'assets/data/creatures/en/details/${entry['id']}.json',
        )) {
          return _stringData(jsonEncode(entry));
        }
      }
      return _transparentImage;
    };

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', handler);
  });

  tearDown(() {
    listTesterView.resetPhysicalSize();
    listTesterView.resetDevicePixelRatio();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  testWidgets('filters stay on one row and list cards keep a uniform height', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        EnemyListScreen(enemiesLoaderOverride: (_) async => _testEntries),
      ),
    );
    await _pumpListReady(tester);

    final favoritesTop = tester.getTopLeft(
      find.byKey(const ValueKey('favorites-filter-chip')),
    );
    final goldTop = tester.getTopLeft(
      find.byKey(const ValueKey('gold-filter-chip')),
    );
    final filtersTop = tester.getTopLeft(
      find.byKey(const ValueKey('open-secondary-filters')),
    );

    expect(favoritesTop.dy, goldTop.dy);
    expect(favoritesTop.dy, filtersTop.dy);

    final regularSize = tester.getSize(
      find.byKey(const ValueKey('enemy-tile-card-regular_test')),
    );
    final eventSize = tester.getSize(
      find.byKey(const ValueKey('enemy-tile-card-g2_event_test')),
    );

    expect(regularSize.height, eventSize.height);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('enemy-tile-g2_event_test')),
        matching: find.byIcon(Icons.layers_outlined),
      ),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('card-progress-g2_event_test')),
      findsNothing,
    );

    await _disposeTestApp(tester);
  });

  testWidgets('phone list never paints a persistent selected card', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        EnemyListScreen(enemiesLoaderOverride: (_) async => _testEntries),
      ),
    );
    await _pumpListReady(tester);

    final card = tester.widget<Card>(
      find.byKey(const ValueKey('enemy-tile-card-regular_test')),
    );
    expect(card.color, isNull);

    await _disposeTestApp(tester);
  });

  testWidgets('master-detail keeps selection visible in the list', (
    tester,
  ) async {
    listTesterView.physicalSize = const Size(1400, 1000);

    await tester.pumpWidget(
      _buildTestApp(
        EnemyListScreen(enemiesLoaderOverride: (_) async => _testEntries),
      ),
    );
    await _pumpListReady(tester);

    final card = tester.widget<Card>(
      find.byKey(const ValueKey('enemy-tile-card-regular_test')),
    );
    expect(card.color, isNotNull);

    await _disposeTestApp(tester);
  });

  testWidgets('gold filter only keeps entries whose current progress is gold', (
    tester,
  ) async {
    await tester.runAsync(
      () => GoldController.instance.setProgress(
        _testEntries.first,
        CreatureCardProgress.gold,
      ),
    );

    await tester.pumpWidget(
      _buildTestApp(
        EnemyListScreen(enemiesLoaderOverride: (_) async => _testEntries),
      ),
    );
    await _pumpListReady(tester);

    await tester.tap(find.byKey(const ValueKey('gold-filter-chip')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('enemy-tile-regular_test')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('enemy-tile-g2_event_test')),
      findsNothing,
    );

    await tester.runAsync(
      () => GoldController.instance.setProgress(
        _testEntries.first,
        CreatureCardProgress.unowned,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('No gold cards'), findsOneWidget);
    await _disposeTestApp(tester);
    await _flushTestWrites(tester);
  });

  testWidgets(
    'stored gold progress shows a loader first and rebuilds the filter',
    (tester) async {
      await tester.runAsync(() async {
        await LocalStorage.setBool('ui_filter_gold', true);
        await LocalStorage.setStringSet('gold_cards', {'g2_regular_test'});
        await LocalStorage.setString(
          creatureCardProgressStorageKey,
          encodeCreatureCardProgressMap({
            'g2:g2_regular_test': CreatureCardProgress.gold,
          }),
        );
      });
      GoldController.instance.reloadFromStorage();

      await tester.pumpWidget(
        _buildTestApp(
          EnemyListScreen(enemiesLoaderOverride: (_) async => _testEntries),
        ),
      );

      await tester.pump();
      expect(find.byType(AphidexLoadingPanel), findsOneWidget);
      expect(
        find.byKey(const ValueKey('enemy-tile-regular_test')),
        findsNothing,
      );

      await _pumpListReady(tester);

      expect(
        find.byKey(const ValueKey('enemy-tile-regular_test')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('enemy-tile-g2_event_test')),
        findsNothing,
      );
      await _disposeTestApp(tester);
      await _flushTestWrites(tester);
    },
  );

  testWidgets(
    'master-detail keeps the right pane while favorites is empty and buttons stay uniform',
    (tester) async {
      listTesterView.physicalSize = const Size(1024, 768);

      await tester.pumpWidget(
        _buildTestApp(
          EnemyListScreen(enemiesLoaderOverride: (_) async => _testEntries),
        ),
      );
      await _pumpListReady(tester);

      final favoritesSize = tester.getSize(
        find.byKey(const ValueKey('favorites-filter-chip')),
      );
      final goldSize = tester.getSize(
        find.byKey(const ValueKey('gold-filter-chip')),
      );
      final filtersSize = tester.getSize(
        find.byKey(const ValueKey('open-secondary-filters')),
      );

      expect(favoritesSize, goldSize);
      expect(favoritesSize, filtersSize);

      await tester.tap(find.byKey(const ValueKey('favorites-filter-chip')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('No favorites yet'), findsOneWidget);
      expect(find.byType(EnemyDetailScreen), findsNothing);
      await _disposeTestApp(tester);
    },
  );

  testWidgets('empty search state stays stable on a short phone layout', (
    tester,
  ) async {
    listTesterView.physicalSize = const Size(844, 390);

    await tester.pumpWidget(
      _buildTestApp(
        EnemyListScreen(enemiesLoaderOverride: (_) async => _testEntries),
      ),
    );
    await _pumpListReady(tester);

    await tester.enterText(find.byType(TextField), 'no-match');
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('No results'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _disposeTestApp(tester);
  });
}

Widget _buildTestApp(Widget home) {
  return DefaultAssetBundle(
    bundle: _TestAssetBundle(),
    child: MaterialApp(
      navigatorKey: ReviewPromptController.navigatorKey,
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) =>
          TutorialHost(child: child ?? const SizedBox.shrink()),
      home: home,
    ),
  );
}

Future<void> _pumpListReady(WidgetTester tester) async {
  await _pumpUntilVisible(
    tester,
    find.byKey(const ValueKey('favorites-filter-chip')),
  );
  await _pumpUntilVisible(
    tester,
    find.byKey(const ValueKey('enemy-tile-regular_test')),
  );
}

Future<void> _pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 250),
  int maxTicks = 40,
}) async {
  for (var i = 0; i < maxTicks; i++) {
    await tester.pump(step);
    final exception = tester.takeException();
    if (exception != null) {
      Error.throwWithStackTrace(exception, StackTrace.current);
    }
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  expect(finder, findsOneWidget);
}

Future<void> _disposeTestApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _flushTestWrites(WidgetTester tester) => tester.runAsync(
  () => Future<void>.delayed(const Duration(milliseconds: 100)),
);

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
    'listIconAsset': enemy.listIconAsset,
    'hasCreatureCard': enemy.hasCreatureCard,
    'hasGoldCreatureCard': enemy.hasGoldCreatureCard,
    'hasSelectableCardVariants': enemy.hasSelectableCardVariants,
    'defaultCardVariant': enemy.defaultCardVariant?.storageValue,
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

ByteData _stringData(String value) {
  final bytes = Uint8List.fromList(utf8.encode(value));
  return ByteData.view(bytes.buffer);
}

final ByteData _transparentImage = ByteData.sublistView(
  File('assets/global/CreatureTier5.png').readAsBytesSync(),
);

const String _svg =
    '<svg viewBox="0 0 32 32" xmlns="http://www.w3.org/2000/svg">'
    '<rect width="32" height="32" fill="#ffffff"/></svg>';

class _TestAssetBundle extends CachingAssetBundle {
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

const _regularEnemyJson = {
  'id': 'g2_regular_test',
  'speciesKey': 'regular_test',
  'name': {'en': 'Regular Test Creature'},
  'game': 'g2',
  'tier': 2,
  'danger': 'media',
  'isBoss': false,
  'order': 10,
  'defaultGold': false,
  'cardNormal': 'assets/test/Card.webp',
  'cardGold': 'assets/test/Card_Gold.webp',
  'photo': 'assets/test/Photo.webp',
  'weaknesses': ['fresh'],
  'resistances': ['gas'],
  'health': {'rating': 2, 'value': 220},
  'description': {'en': 'Regular detail entry'},
};

const _eventEntryJson = {
  'id': 'g2_event_test',
  'speciesKey': 'g2_event_test',
  'collectionGroup': 'other',
  'name': {'en': 'Event Defense Reference'},
  'game': 'g2',
  'tier': 3,
  'danger': 'alta',
  'isBoss': false,
  'order': 11,
  'defaultGold': false,
  'cardNormal': '',
  'cardGold': '',
  'listIconAsset': 'assets/global/effects_damage/Summon_HP.webp',
  'photo': 'assets/test/Event.webp',
  'weaknesses': <String>[],
  'resistances': <String>[],
  'temperament': 'other',
  'isKillable': false,
  'healthDisplay': 'hidden',
  'description': {'en': 'Event detail entry'},
};

final List<EnemyIndexEntry> _testEntries = [
  EnemyIndexEntry.fromJson(_indexEntry(_regularEnemyJson)),
  EnemyIndexEntry.fromJson(_indexEntry(_eventEntryJson)),
];
