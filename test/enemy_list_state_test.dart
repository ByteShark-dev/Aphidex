import 'dart:convert';
import 'dart:io';

import 'package:aphidex/controllers/favorites_controller.dart';
import 'package:aphidex/controllers/review_prompt_controller.dart';
import 'package:aphidex/controllers/tutorial_controller.dart';
import 'package:aphidex/controllers/gold_controller.dart';
import 'package:aphidex/controllers/monetization_controller.dart';
import 'package:aphidex/data/aphidex_view_state.dart';
import 'package:aphidex/data/enemy_repository.dart';
import 'package:aphidex/data/local_storage.dart';
import 'package:aphidex/i18n/app_localizations.dart';
import 'package:aphidex/models/enemy.dart';
import 'package:aphidex/models/enemy_index_entry.dart';
import 'package:aphidex/models/game_pick.dart';
import 'package:aphidex/screens/enemy_detail_screen.dart';
import 'package:aphidex/screens/enemy_list_screen.dart';
import 'package:aphidex/widgets/tutorial_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

final TestFlutterView stateTesterView =
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;
  late Future<ByteData?> Function(ByteData?) handler;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('aphidex_list_state_');
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
    await LocalStorage.setBool('review_prompt_disabled_forever', true);
    await LocalStorage.setBool('monetization_ads_removed', true);
    MonetizationController.instance.adsRemoved.value = true;

    stateTesterView.physicalSize = const Size(390, 844);
    stateTesterView.devicePixelRatio = 1.0;

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
      for (final entry in [_primaryEnemyJson, _secondaryEnemyJson]) {
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
    stateTesterView.resetPhysicalSize();
    stateTesterView.resetDevicePixelRatio();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  test('view state serialization round-trips the focused UI state', () {
    const state = AphidexViewState(
      gamePickIndex: 2,
      sortModeIndex: 3,
      sortDescending: true,
      query: 'wasp',
      filterFavorites: true,
      filterGold: false,
      tierFilters: {'3', 'boss'},
      classFilters: {'orc'},
      dangerFilters: {'extrema'},
      selectedSpeciesKey: 'wolf_spider',
      detailEnemyId: 'g2_orc_wolf_spider',
      detailGame: 'g2',
      detailOpen: true,
      listScrollOffset: 184,
    );

    final restored = AphidexViewState.fromStorageString(
      state.toStorageString(),
    );

    expect(restored, isNotNull);
    expect(restored!.gamePickIndex, 2);
    expect(restored.sortModeIndex, 3);
    expect(restored.sortDescending, isTrue);
    expect(restored.query, 'wasp');
    expect(restored.tierFilters, {'3', 'boss'});
    expect(restored.classFilters, {'orc'});
    expect(restored.detailEnemyId, 'g2_orc_wolf_spider');
    expect(restored.detailOpen, isTrue);
    expect(restored.listScrollOffset, 184);
  });

  testWidgets(
    'master-detail restores the selected species into the right pane',
    (tester) async {
      stateTesterView.physicalSize = const Size(1400, 1000);
      await tester.runAsync(() async {
        await LocalStorage.setInt('ui_game_pick', GamePick.g2.index);
        await LocalStorage.setString(
          aphidexViewStateStorageKey,
          const AphidexViewState(
            gamePickIndex: 2,
            sortModeIndex: 0,
            sortDescending: false,
            query: '',
            filterFavorites: false,
            filterGold: false,
            tierFilters: <String>{},
            classFilters: <String>{},
            dangerFilters: <String>{},
            selectedSpeciesKey: 'state_secondary',
            detailEnemyId: 'g2_state_secondary',
            detailGame: 'g2',
            detailOpen: false,
            listScrollOffset: 0,
          ).toStorageString(),
        );
      });

      await tester.pumpWidget(
        _buildTestApp(
          EnemyListScreen(
            enemiesLoaderOverride: (_) async => _testEntries,
            persistViewStateOnDispose: false,
          ),
        ),
      );
      await _pumpUntilVisible(
        tester,
        find.byKey(const ValueKey('enemy-tile-card-state_secondary')),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final selectedCard = tester.widget<Card>(
        find.byKey(const ValueKey('enemy-tile-card-state_secondary')),
      );
      expect(selectedCard.color, isNotNull);
      expect(find.byType(EnemyDetailScreen), findsOneWidget);
      expect(find.text('State Secondary'), findsWidgets);
      await _disposeTestApp(tester);
    },
  );

  testWidgets('phone restores the last open detail route from saved state', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await LocalStorage.setInt('ui_game_pick', GamePick.g2.index);
      await LocalStorage.setString(
        aphidexViewStateStorageKey,
        const AphidexViewState(
          gamePickIndex: 2,
          sortModeIndex: 0,
          sortDescending: false,
          query: '',
          filterFavorites: false,
          filterGold: false,
          tierFilters: <String>{},
          classFilters: <String>{},
          dangerFilters: <String>{},
          selectedSpeciesKey: 'state_secondary',
          detailEnemyId: 'g2_state_secondary',
          detailGame: 'g2',
          detailOpen: true,
          listScrollOffset: 0,
        ).toStorageString(),
      );
    });

    await tester.pumpWidget(
      _buildTestApp(
        EnemyListScreen(
          enemiesLoaderOverride: (_) async => _testEntries,
          persistViewStateOnDispose: false,
        ),
      ),
    );
    await _pumpUntilVisible(tester, find.byType(EnemyDetailScreen));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(EnemyDetailScreen), findsOneWidget);
    expect(find.text('State Secondary'), findsWidgets);
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

const _primaryEnemyJson = {
  'id': 'g2_state_primary',
  'speciesKey': 'state_primary',
  'name': {'en': 'State Primary'},
  'game': 'g2',
  'tier': 2,
  'danger': 'media',
  'isBoss': false,
  'order': 20,
  'defaultGold': false,
  'cardNormal': 'assets/test/Card.webp',
  'cardGold': 'assets/test/Card_Gold.webp',
  'photo': 'assets/test/Photo.webp',
  'weaknesses': ['fresh'],
  'resistances': ['gas'],
  'health': {'rating': 2, 'value': 200},
  'description': {'en': 'Primary detail entry'},
};

const _secondaryEnemyJson = {
  'id': 'g2_state_secondary',
  'speciesKey': 'state_secondary',
  'name': {'en': 'State Secondary'},
  'game': 'g2',
  'tier': 3,
  'danger': 'alta',
  'isBoss': false,
  'order': 21,
  'defaultGold': false,
  'cardNormal': 'assets/test/Card.webp',
  'cardGold': 'assets/test/Card_Gold.webp',
  'photo': 'assets/test/Photo.webp',
  'weaknesses': ['salty'],
  'resistances': ['gas'],
  'health': {'rating': 3, 'value': 320},
  'description': {'en': 'Secondary detail entry'},
};

final List<EnemyIndexEntry> _testEntries = [
  EnemyIndexEntry.fromJson(_indexEntry(_primaryEnemyJson)),
  EnemyIndexEntry.fromJson(_indexEntry(_secondaryEnemyJson)),
];
