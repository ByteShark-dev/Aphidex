import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aphidex/controllers/review_prompt_controller.dart';
import 'package:aphidex/controllers/tutorial_controller.dart';
import 'package:aphidex/data/enemy_repository.dart';
import 'package:aphidex/i18n/app_localizations.dart';
import 'package:aphidex/models/enemy.dart';
import 'package:aphidex/models/enemy_index_entry.dart';
import 'package:aphidex/screens/enemy_detail_screen.dart';
import 'package:aphidex/screens/enemy_list_screen.dart';
import 'package:aphidex/screens/effect_codex_screen.dart';
import 'package:aphidex/widgets/tutorial_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

final TestFlutterView tutorialTesterView =
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;
  late Future<ByteData?> Function(ByteData?) handler;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('aphidex_tutorial_test_');
    Hive.init(hiveDir.path);
    await Hive.openBox('aphidex');
  });

  tearDownAll(() async {
    await Hive.box('aphidex').close();
  });

  setUp(() async {
    await Hive.box('aphidex').clear();
    EnemyRepository.clearCaches();
    TutorialController.instance.debugResetForTests();

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
        return _stringData(_TestAssetBundle._svg);
      }
      if (key.endsWith('assets/data/creatures/en/index_g1.json')) {
        return _stringData(
          jsonEncode([
            _indexEntry(_tutorialEnemyJson),
            _indexEntry(_invalidTutorialEnemyJson),
          ]),
        );
      }
      if (key.endsWith('assets/data/creatures/en/index_g2.json')) {
        return _stringData(jsonEncode([_indexEntry(_tutorialEnemyG2Json)]));
      }
      if (key.endsWith(
        'assets/data/creatures/en/details/g1_tutorial_enemy.json',
      )) {
        return _stringData(jsonEncode(_tutorialEnemyJson));
      }
      if (key.endsWith(
        'assets/data/creatures/en/details/g2_tutorial_enemy.json',
      )) {
        return _stringData(jsonEncode(_tutorialEnemyG2Json));
      }
      return _transparentImage;
    };

    tutorialTesterView.physicalSize = const Size(1080, 2400);
    tutorialTesterView.devicePixelRatio = 1.0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', handler);
  });

  tearDown(() {
    tutorialTesterView.resetPhysicalSize();
    tutorialTesterView.resetDevicePixelRatio();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    TutorialController.instance.debugResetForTests();
  });

  test('pickTutorialEnemy only returns valid candidates', () {
    final picked = pickTutorialEnemy([
      Enemy.fromJson(_invalidTutorialEnemyJson),
      Enemy.fromJson(_tutorialEnemyJson),
    ]);

    expect(picked?.id, 'g1_tutorial_enemy');
    expect(tutorialEffectIdsForEnemy(picked!), contains('gas'));
  });

  test('pickTutorialEnemyVariants prefers a shared species when available', () {
    final picked = pickTutorialEnemyVariants([
      Enemy.fromJson(_tutorialEnemyJson),
      Enemy.fromJson(_tutorialEnemyG2Json),
    ]);

    expect(picked, isNotNull);
    expect(picked!.map((enemy) => enemy.game), containsAll(['g1', 'g2']));
  });

  testWidgets('maybeStart asks before launching the tutorial', (tester) async {
    await tester.pumpWidget(
      _buildTutorialApp(
        const EnemyListScreen(persistViewStateOnDispose: false),
      ),
    );
    await _pumpAppReady(tester);

    await _requestTutorial(tester);

    expect(find.byKey(const ValueKey('tutorial-prompt-start')), findsOneWidget);
    expect(find.text('Would you like a quick intro tutorial?'), findsOneWidget);
  });

  testWidgets('maybeStart activates the tutorial when it is accepted', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTutorialApp(
        const EnemyListScreen(persistViewStateOnDispose: false),
      ),
    );
    await _pumpAppReady(tester);

    await _showTutorial(tester);

    expect(find.text('Search enemies fast'), findsOneWidget);
    expect(find.byKey(const ValueKey('tutorial-skip')), findsOneWidget);
  });

  testWidgets('tutorial walks from list to detail and effect codex', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTutorialApp(
        const EnemyListScreen(persistViewStateOnDispose: false),
      ),
    );
    await _pumpAppReady(tester);
    await _showTutorial(tester);

    for (
      var i = 0;
      i < 30 && find.byType(EffectCodexScreen).evaluate().isEmpty;
      i++
    ) {
      await _tapTutorialNext(tester);
      await _pumpAppReady(tester, milliseconds: 900);
    }

    expect(
      find.byType(EffectCodexScreen),
      findsOneWidget,
      reason: 'step=${TutorialController.instance.step}',
    );
    expect(find.byType(EnemyDetailScreen), findsNothing);
    expect(find.byKey(const ValueKey('effect-card-gas')), findsOneWidget);
  });

  testWidgets(
    'tutorial survives phone landscape when some detail targets are hidden',
    (tester) async {
      tutorialTesterView.physicalSize = const Size(844, 390);

      await tester.pumpWidget(
        _buildTutorialApp(
          const EnemyListScreen(persistViewStateOnDispose: false),
        ),
      );
      await _pumpAppReady(tester);
      await _showTutorial(tester);
      expect(tester.takeException(), isNull);

      for (
        var i = 0;
        i < 30 && find.byType(EffectCodexScreen).evaluate().isEmpty;
        i++
      ) {
        await _tapTutorialNext(tester);
        await _pumpAppReady(tester, milliseconds: 900);
        final exception = tester.takeException();
        expect(exception, isNull, reason: 'iteration ${i + 1}');
      }

      expect(
        find.byType(EffectCodexScreen),
        findsOneWidget,
        reason: 'step=${TutorialController.instance.step}',
      );
    },
  );

  testWidgets(
    'tablet tutorial keeps footer actions visible and removes the overlay when it ends',
    (tester) async {
      tutorialTesterView.physicalSize = const Size(1024, 768);

      await tester.pumpWidget(
        _buildTutorialApp(
          const EnemyListScreen(persistViewStateOnDispose: false),
        ),
      );
      await _pumpAppReady(tester);
      await _showTutorial(tester);

      for (var i = 0; i < 4; i++) {
        _expectInViewport(tester, find.byKey(const ValueKey('tutorial-skip')));
        _expectInViewport(tester, find.byKey(const ValueKey('tutorial-next')));
        await _tapTutorialNext(tester);
        await _pumpAppReady(tester, milliseconds: 900);
        expect(tester.takeException(), isNull, reason: 'iteration ${i + 1}');
      }

      TutorialController.instance.debugResetForTests();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('tutorial-next')), findsNothing);
      expect(find.byKey(const ValueKey('tutorial-skip')), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    },
  );

  testWidgets(
    'tutorial ignores rapid double advance during route transitions',
    (tester) async {
      await tester.pumpWidget(
        _buildTutorialApp(
          const EnemyListScreen(persistViewStateOnDispose: false),
        ),
      );
      await _pumpAppReady(tester);
      await _showTutorial(tester);

      for (
        var i = 0;
        i < 15 && TutorialController.instance.step != TutorialStep.codex;
        i++
      ) {
        await _tapTutorialNext(tester);
        await _pumpAppReady(tester, milliseconds: 500);
      }
      expect(TutorialController.instance.step, TutorialStep.codex);

      final nextButton = find.byKey(const ValueKey('tutorial-next'));
      for (
        var i = 0;
        i < 10 && tester.widget<FilledButton>(nextButton).onPressed == null;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final onPressed = tester.widget<FilledButton>(nextButton).onPressed;
      expect(onPressed, isNotNull);
      onPressed!();
      onPressed();
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(tester.takeException(), isNull);
      expect(TutorialController.instance.step, TutorialStep.detailSummary);
    },
  );
}

Widget _buildTutorialApp(Widget home) {
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

ByteData _stringData(String value) {
  final bytes = Uint8List.fromList(utf8.encode(value));
  return ByteData.view(bytes.buffer);
}

Future<void> _pumpAppReady(
  WidgetTester tester, {
  int milliseconds = 900,
}) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: milliseconds));
}

Future<void> _showTutorial(WidgetTester tester) async {
  await _requestTutorial(tester);
  await tester.tap(find.byKey(const ValueKey('tutorial-prompt-start')));
  await _pumpAppReady(tester);
}

Future<void> _requestTutorial(WidgetTester tester) async {
  final context = tester.element(find.byType(EnemyListScreen));
  unawaited(
    TutorialController.instance.maybeStart(context, [
      EnemyIndexEntry.fromEnemy(Enemy.fromJson(_tutorialEnemyJson), 'en'),
      EnemyIndexEntry.fromEnemy(Enemy.fromJson(_tutorialEnemyG2Json), 'en'),
    ]),
  );
  await _pumpAppReady(tester);
}

Future<void> _tapTutorialNext(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('tutorial-next'));
  await tester.ensureVisible(button);
  await tester.tap(button, warnIfMissed: false);
}

void _expectInViewport(WidgetTester tester, Finder finder) {
  expect(finder, findsOneWidget);
  final rect = tester.getRect(finder);
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(size.height));
  expect(rect.right, lessThanOrEqualTo(size.width));
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

  @override
  Future<T> loadStructuredBinaryData<T>(
    String key,
    FutureOr<T> Function(ByteData data) parser,
  ) {
    return Future<T>.value(
      parser(const StandardMessageCodec().encodeMessage(<Object?, Object?>{})!),
    );
  }
}

final Map<String, dynamic> _tutorialEnemyJson = {
  'id': 'g1_tutorial_enemy',
  'speciesKey': 'tutorial_shared_enemy',
  'name': {
    'es': 'Enemigo tutorial',
    'en': 'Tutorial Enemy',
    'ru': 'Обучающий враг',
  },
  'game': 'g1',
  'tier': 2,
  'danger': 'media',
  'isBoss': false,
  'order': 120,
  'defaultGold': false,
  'cardNormal': 'assets/test/Card.webp',
  'cardGold': 'assets/test/Card_Gold.webp',
  'photo': 'assets/test/Photo.webp',
  'weaknesses': ['salty'],
  'resistances': ['poison'],
  'health': {'rating': 2, 'value': 100},
  'elementalWeaknesses': [
    {'type': 'salty', 'bonusPct': 50},
  ],
  'damageWeaknesses': [
    {'type': 'busting', 'bonusPct': 25},
  ],
  'resistancesV2': [
    {'type': 'gas', 'bonusPct': 100},
  ],
  'weakPoint': {'part': 'back', 'susceptibleDamage': 'chopping and slashing'},
  'attacks': [],
};

final Map<String, dynamic> _tutorialEnemyG2Json = {
  'id': 'g2_tutorial_enemy',
  'speciesKey': 'tutorial_shared_enemy',
  'name': {
    'es': 'Enemigo tutorial',
    'en': 'Tutorial Enemy',
    'ru': 'ÐžÐ±ÑƒÑ‡Ð°ÑŽÑ‰Ð¸Ð¹ Ð²Ñ€Ð°Ð³',
  },
  'game': 'g2',
  'tier': 3,
  'danger': 'alta',
  'isBoss': false,
  'order': 220,
  'defaultGold': false,
  'cardNormal': 'assets/test/Card.webp',
  'cardGold': 'assets/test/Card_Gold.webp',
  'photo': 'assets/test/Photo.webp',
  'weaknesses': ['fresh'],
  'resistances': ['gas'],
  'health': {'rating': 3, 'value': 150},
  'elementalWeaknesses': [
    {'type': 'fresh', 'bonusPct': 50},
  ],
  'damageWeaknesses': [
    {'type': 'stabbing', 'bonusPct': 25},
  ],
  'resistancesV2': [
    {'type': 'gas', 'bonusPct': 100},
  ],
  'attacks': [],
};

final Map<String, dynamic> _invalidTutorialEnemyJson = {
  'id': 'g1_invalid_tutorial_enemy',
  'speciesKey': 'invalid_tutorial_enemy',
  'name': {'es': 'Inválido', 'en': 'Invalid', 'ru': 'Неверный'},
  'game': 'g1',
  'tier': 1,
  'danger': 'baja',
  'isBoss': false,
  'order': 121,
  'defaultGold': false,
  'cardNormal': 'assets/test/Card.webp',
  'cardGold': 'assets/test/Card_Gold.webp',
  'photo': '',
  'weaknesses': [],
  'resistances': [],
};
