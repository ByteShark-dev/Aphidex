import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aphidex/controllers/favorites_controller.dart';
import 'package:aphidex/controllers/gold_controller.dart';
import 'package:aphidex/controllers/monetization_controller.dart';
import 'package:aphidex/controllers/review_prompt_controller.dart';
import 'package:aphidex/controllers/tutorial_controller.dart';
import 'package:aphidex/data/local_storage.dart';
import 'package:aphidex/data/creature_card_state.dart';
import 'package:aphidex/i18n/app_localizations.dart';
import 'package:aphidex/models/enemy_index_entry.dart';
import 'package:aphidex/models/game_pick.dart';
import 'package:aphidex/screens/enemy_detail_screen.dart';
import 'package:aphidex/screens/enemy_list_screen.dart';
import 'package:aphidex/widgets/state_panels.dart';
import 'package:aphidex/widgets/tutorial_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

final TestFlutterView regressionListView =
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('aphidex_list_regression_');
    Hive.init(hiveDir.path);
    await Hive.openBox('aphidex');
  });

  tearDownAll(() {
    unawaited(Hive.box('aphidex').close());
  });

  setUp(() {
    regressionListView.physicalSize = const Size(390, 844);
    regressionListView.devicePixelRatio = 1.0;

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
        });
  });

  tearDown(() {
    regressionListView.resetPhysicalSize();
    regressionListView.resetDevicePixelRatio();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  testWidgets('gold progress keeps the filtered result stable on first load', (
    tester,
  ) async {
    await _prepareRegressionState(tester);
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

    await tester.pumpWidget(_buildApp());
    await tester.pump();

    expect(find.byType(AphidexLoadingPanel), findsOneWidget);
    expect(find.byKey(const ValueKey('enemy-tile-regular_test')), findsNothing);

    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const ValueKey('enemy-tile-regular_test')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('enemy-tile-g2_event_test')),
      findsNothing,
    );
  });

  testWidgets(
    'favorites empty state stays in the left pane during master-detail',
    (tester) async {
      await _prepareRegressionState(tester);
      regressionListView.physicalSize = const Size(1024, 768);

      await tester.pumpWidget(_buildApp());
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 100));

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
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    },
  );

  testWidgets('favorite and progress taps do not open the detail route', (
    tester,
  ) async {
    await _prepareRegressionState(tester);
    await tester.pumpWidget(_buildApp());
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(
      find.byKey(const ValueKey('favorite-toggle-g2_regular_test')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(EnemyDetailScreen), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('card-progress-g2_regular_test')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(EnemyDetailScreen), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  });
}

Future<void> _prepareRegressionState(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Hive.box('aphidex').clear();
    await FavoritesController.instance.reset();
    await GoldController.instance.reset();
    await LocalStorage.setBool(TutorialController.completionKey, true);
    await LocalStorage.setBool('review_prompt_disabled_forever', true);
    await LocalStorage.setBool('monetization_ads_removed', true);
    await LocalStorage.setInt('ui_game_pick', GamePick.g2.index);
  });
  MonetizationController.instance.adsRemoved.value = true;
}

Widget _buildApp() {
  return DefaultAssetBundle(
    bundle: _RegressionAssetBundle(),
    child: MaterialApp(
      navigatorKey: ReviewPromptController.navigatorKey,
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) =>
          TutorialHost(child: child ?? const SizedBox.shrink()),
      home: EnemyListScreen(
        enemiesLoaderOverride: (_) async => _testEntries,
        persistViewStateOnDispose: false,
      ),
    ),
  );
}

ByteData _stringData(String value) {
  final bytes = Uint8List.fromList(utf8.encode(value));
  return ByteData.view(bytes.buffer);
}

class _RegressionAssetBundle extends CachingAssetBundle {
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

const _svg =
    '<svg viewBox="0 0 32 32" xmlns="http://www.w3.org/2000/svg">'
    '<rect width="32" height="32" fill="#ffffff"/></svg>';

final ByteData _transparentImage = ByteData.sublistView(
  File('assets/global/CreatureTier5.png').readAsBytesSync(),
);

final List<EnemyIndexEntry> _testEntries = [
  EnemyIndexEntry.fromJson({
    'id': 'g2_regular_test',
    'speciesKey': 'regular_test',
    'game': 'g2',
    'name': 'Regular entry',
    'tier': 2,
    'danger': 'media',
    'isBoss': false,
    'order': 1,
    'defaultGold': false,
    'cardNormal': 'assets/test/Card.webp',
    'cardGold': 'assets/test/Card_Gold.webp',
    'listIconAsset': '',
    'hasCreatureCard': true,
    'hasGoldCreatureCard': true,
    'hasSelectableCardVariants': true,
    'defaultCardVariant': 'normal',
    'weaknesses': ['fresh'],
    'resistances': [],
    'temperament': 'neutral',
    'health': {'rating': 2, 'value': 450},
  }),
  EnemyIndexEntry.fromJson({
    'id': 'g2_event_test',
    'speciesKey': 'g2_event_test',
    'game': 'g2',
    'name': 'Event entry',
    'tier': 2,
    'danger': 'alta',
    'isBoss': false,
    'order': 2,
    'defaultGold': false,
    'cardNormal': '',
    'cardGold': '',
    'listIconAsset': 'assets/global/effects_damage/Generic_Damage.webp',
    'hasCreatureCard': false,
    'hasGoldCreatureCard': false,
    'hasSelectableCardVariants': false,
    'defaultCardVariant': null,
    'weaknesses': [],
    'resistances': [],
    'temperament': 'other',
  }),
];
