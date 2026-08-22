import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aphidex/controllers/tutorial_controller.dart';
import 'package:aphidex/data/enemy_repository.dart';
import 'package:aphidex/data/effect_catalog.dart';
import 'package:aphidex/data/local_storage.dart';
import 'package:aphidex/i18n/app_localizations.dart';
import 'package:aphidex/models/enemy.dart';
import 'package:aphidex/screens/effect_codex_screen.dart';
import 'package:aphidex/screens/enemy_detail_screen.dart';
import 'package:aphidex/screens/enemy_list_screen.dart';
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

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('aphidex_test_');
    Hive.init(hiveDir.path);
    await Hive.openBox('aphidex');
    await LocalStorage.setBool(TutorialController.completionKey, true);
  });

  tearDownAll(() async {
    await Hive.box('aphidex').close();
    await hiveDir.delete(recursive: true);
  });

  group('effect catalog', () {
    test('contains all canonical effect ids', () {
      expect(effectCatalogEntries.map((entry) => entry.id).toSet(), {
        'slashing',
        'chopping',
        'busting',
        'stabbing',
        'generic',
        'explosive',
        'water',
        'fresh',
        'chill',
        'spicy',
        'salty',
        'sour',
        'acid',
        'venom',
        'poison',
        'gas',
        'bleed',
        'dust',
        'shock',
        'burning',
        'sizzle',
        'tang_buildup',
        'infection',
      });
    });

    test('normalizes aliases to canonical ids', () {
      expect(canonicalEffectId('gas_hazard'), 'gas');
      expect(canonicalEffectId('electricity'), 'shock');
      expect(canonicalEffectId('electric'), 'shock');
      expect(canonicalEffectId('burn'), 'burning');
      expect(canonicalEffectId('chilling'), 'chill');
      expect(canonicalEffectId('heat'), 'sizzle');
      expect(canonicalEffectId('tang'), 'tang_buildup');
      expect(canonicalEffectId('stabbing_arrows_only'), 'stabbing');
      expect(effectCatalogEntryById('gas_hazard')?.id, 'gas');
      expect(effectCatalogEntryById('electricity')?.id, 'shock');
      expect(effectCatalogEntryById('chilling')?.id, 'chill');
      expect(effectCatalogEntryById('heat')?.id, 'sizzle');
      expect(effectCatalogEntryById('tang')?.id, 'tang_buildup');
    });

    test('resolves localized names and descriptions', () {
      final shock = effectCatalogEntryById('shock')!;
      final gas = effectCatalogEntryById('gas')!;
      final water = effectCatalogEntryById('water')!;

      expect(shock.name.resolve('es'), 'Electricidad');
      expect(shock.name.resolve('en'), 'Shock');
      expect(shock.name.resolve('ru'), 'Электрошок');
      expect(water.category, EffectCategory.damage);
      expect(gas.description.resolve('es'), isNotEmpty);
      expect(gas.description.resolve('en'), isNotEmpty);
      expect(gas.description.resolve('ru'), isNotEmpty);
    });
  });

  group('effect codex localizations', () {
    test('exposes category and placeholder labels in supported locales', () {
      expect(
        AppLocalizations(const Locale('es')).effectCategoryLabel('damage'),
        'Tipos de daño',
      );
      expect(
        AppLocalizations(const Locale('en')).effectCategoryLabel('status'),
        'Status effects',
      );
      expect(
        AppLocalizations(const Locale('ru')).effectEquipmentComingSoon,
        'Скоро.',
      );
    });
  });

  group('effect codex navigation', () {
    late Future<ByteData?> Function(ByteData?) handler;

    setUp(() {
      EnemyRepository.clearCaches();
      handler = (message) async {
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
          return _stringData(_TestAssetBundle._svg);
        }
        if (key.endsWith('assets/data/creatures/en/index_g1.json')) {
          return _stringData(jsonEncode([_indexEntry(_sampleEnemyJson)]));
        }
        if (key.endsWith('assets/data/creatures/en/index_g2.json')) {
          return _stringData('[]');
        }
        if (key.endsWith(
          'assets/data/creatures/en/details/g1_test_enemy.json',
        )) {
          return _stringData(jsonEncode(_sampleEnemyJson));
        }
        return _transparentImage;
      };

      testerView.physicalSize = const Size(1080, 2400);
      testerView.devicePixelRatio = 1.0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', handler);
    });

    tearDown(() {
      testerView.resetPhysicalSize();
      testerView.resetDevicePixelRatio();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
    });

    testWidgets('opens from an enemy resistance icon', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          EnemyDetailScreen(enemy: Enemy.fromJson(_sampleEnemyJson)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('effect-bonus-resistance-gas')).first,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(
        find.byKey(const ValueKey('effect-bonus-resistance-gas')).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Gas'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Effect Codex'), findsOneWidget);
    });

    testWidgets('opens from a weak point damage icon', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          EnemyDetailScreen(enemy: Enemy.fromJson(_sampleEnemyJson)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('weakpoint-effect-chopping')).first,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(
        find.byKey(const ValueKey('weakpoint-effect-chopping')).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Chopping'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('opens from the home app bar button', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(const EnemyListScreen(persistViewStateOnDispose: false)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byKey(const ValueKey('open-effect-codex')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Effect Codex'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('effect-card-slashing')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('highlights the focused effect when opened with an id', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          const EffectCodexScreen(
            initialEffectId: 'gas_hazard',
            autoScrollToInitialEffect: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final highlighted = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('effect-card-gas')),
      );
      final regular = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('effect-card-dust')),
      );

      final highlightedDecoration = highlighted.decoration! as BoxDecoration;
      final regularDecoration = regular.decoration! as BoxDecoration;

      expect(highlightedDecoration.color, isNotNull);
      expect((highlightedDecoration.border! as Border).top.width, 2);
      expect((regularDecoration.border! as Border).top.width, 1);
    });
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
    if (enemy.health != null)
      'health': {
        'rating': enemy.health!.rating,
        if (enemy.health!.value != null) 'value': enemy.health!.value,
      },
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

final Map<String, dynamic> _sampleEnemyJson = {
  'id': 'g1_test_enemy',
  'name': {
    'es': 'Enemigo de prueba',
    'en': 'Test Enemy',
    'ru': 'Тестовый враг',
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
