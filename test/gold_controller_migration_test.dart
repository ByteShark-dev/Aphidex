import 'dart:io';

import 'package:aphidex/controllers/gold_controller.dart';
import 'package:aphidex/data/creature_card_state.dart';
import 'package:aphidex/models/creature_card_support.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDirectory;
  late GoldController controller;

  const base = _FakeCardCarrier(id: 'g2_ladybug');
  const buggy = _FakeCardCarrier(
    id: 'g2_buggy_ladybug',
    goldLinkId: 'g2_ladybug',
  );

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('aphidex_gold_');
    Hive.init(hiveDirectory.path);
    await Hive.openBox('aphidex');
    controller = GoldController.instance;
  });

  setUp(() async {
    await Hive.box('aphidex').clear();
    controller.reloadFromStorage();
  });

  tearDownAll(() async {
    await Hive.box('aphidex').close();
    await hiveDirectory.delete(recursive: true);
  });

  test('build 24 linked keys migrate once without deleting the base', () async {
    await Hive.box('aphidex').put(
      creatureCardProgressStorageKey,
      encodeCreatureCardProgressMap({
        'g2:g2_ladybug': CreatureCardProgress.obtained,
        'g2:g2_buggy_ladybug': CreatureCardProgress.gold,
      }),
    );
    await Hive.box(
      'aphidex',
    ).put('gold_cards', ['g2_buggy_ladybug', 'g2:g2_buggy_ladybug']);
    controller.reloadFromStorage();

    expect(controller.needsMigration([base, buggy]), isTrue);
    await controller.ensureMigrated([base, buggy]);

    expect(controller.progressFor(base), CreatureCardProgress.gold);
    expect(controller.progressFor(buggy), CreatureCardProgress.gold);
    expect(controller.progress.value, {
      'g2:g2_ladybug': CreatureCardProgress.gold,
    });
    expect(controller.gold.value, {'g2_ladybug', 'g2_buggy_ladybug'});
    expect(controller.needsMigration([base, buggy]), isFalse);

    await controller.ensureMigrated([base, buggy]);
    controller.reloadFromStorage();
    expect(controller.progressFor(base), CreatureCardProgress.gold);
    expect(controller.progressFor(buggy), CreatureCardProgress.gold);
    expect(controller.needsMigration([base, buggy]), isFalse);
  });

  test('updates made through either linked entry survive reload', () async {
    await controller.ensureMigrated([base, buggy]);
    await controller.setProgress(buggy, CreatureCardProgress.obtained);
    expect(controller.progressFor(base), CreatureCardProgress.obtained);

    await controller.setProgress(base, CreatureCardProgress.gold);
    controller.reloadFromStorage();
    expect(controller.progressFor(base), CreatureCardProgress.gold);
    expect(controller.progressFor(buggy), CreatureCardProgress.gold);
    expect(controller.needsMigration([base, buggy]), isFalse);
  });

  test('rapid cycles are serialized in user action order', () async {
    await controller.ensureMigrated([base, buggy]);

    await Future.wait([
      controller.cycle(base),
      controller.cycle(buggy),
      controller.cycle(base),
    ]);

    expect(controller.progressFor(base), CreatureCardProgress.unowned);
    controller.reloadFromStorage();
    expect(controller.progressFor(buggy), CreatureCardProgress.unowned);
  });

  test('invalid carriers no-op and Grounded 1 remains independent', () async {
    const invalid = _FakeCardCarrier(id: '', game: '');
    const noCard = _FakeCardCarrier(
      id: 'g2_global',
      cardNormal: '',
      cardGold: '',
    );
    const groundedOne = _FakeCardCarrier(id: 'g1_ladybug', game: 'g1');

    await controller.setProgress(invalid, CreatureCardProgress.gold);
    await controller.setProgress(noCard, CreatureCardProgress.gold);
    expect(controller.progress.value, isEmpty);

    await controller.ensureMigrated([base, buggy]);
    await controller.toggle('');
    await controller.toggle('g2_unknown');
    await controller.toggleLinked(['', null, 'g2_unknown']);
    expect(controller.progress.value, isEmpty);
    expect(controller.gold.value, isEmpty);

    await controller.setProgress(base, CreatureCardProgress.gold);
    await controller.setProgress(groundedOne, CreatureCardProgress.obtained);
    expect(controller.progressFor(base), CreatureCardProgress.gold);
    expect(controller.progressFor(groundedOne), CreatureCardProgress.obtained);
    expect(controller.progress.value.keys, contains('g1:g1_ladybug'));
  });

  test('a failed Hive write does not wedge later queued updates', () async {
    await Hive.box('aphidex').close();
    await expectLater(
      controller.setProgress(base, CreatureCardProgress.gold),
      throwsA(isA<HiveError>()),
    );

    await Hive.openBox('aphidex');
    controller.reloadFromStorage();
    await controller.setProgress(base, CreatureCardProgress.obtained);
    expect(controller.progressFor(base), CreatureCardProgress.obtained);
  });
}

class _FakeCardCarrier implements CreatureCardCarrier {
  const _FakeCardCarrier({
    required this.id,
    this.game = 'g2',
    this.goldLinkId,
    this.cardNormal = 'normal.webp',
    this.cardGold = 'gold.webp',
  });

  @override
  final String id;
  @override
  final String game;
  @override
  final String? goldLinkId;
  final String cardNormal;
  final String cardGold;

  @override
  bool get defaultGold => false;

  @override
  bool get hasCreatureCard => cardNormal.isNotEmpty || cardGold.isNotEmpty;

  @override
  bool get hasGoldCreatureCard => cardGold.isNotEmpty;

  @override
  bool get hasSelectableCardVariants =>
      cardNormal.isNotEmpty && cardGold.isNotEmpty;

  @override
  CreatureCardVariant? get defaultCardVariant => cardNormal.isNotEmpty
      ? CreatureCardVariant.normal
      : cardGold.isNotEmpty
      ? CreatureCardVariant.gold
      : null;

  @override
  String? assetForCardVariant(CreatureCardVariant variant) => switch (variant) {
    CreatureCardVariant.normal => cardNormal.isEmpty ? null : cardNormal,
    CreatureCardVariant.gold => cardGold.isEmpty ? null : cardGold,
  };
}
