import 'dart:io';

import 'package:aphidex/controllers/game_selection_controller.dart';
import 'package:aphidex/config/app_links.dart';
import 'package:aphidex/controllers/player_profile_controller.dart';
import 'package:aphidex/data/creature_card_state.dart';
import 'package:aphidex/data/player_character_catalog.dart';
import 'package:aphidex/data/player_character_themes.dart';
import 'package:aphidex/data/player_profile_stats.dart';
import 'package:aphidex/i18n/app_localizations.dart';
import 'package:aphidex/models/creature_card_support.dart';
import 'package:aphidex/models/game_pick.dart';
import 'package:aphidex/models/player_character.dart';
import 'package:aphidex/screens/player_profile_screen.dart';
import 'package:aphidex/controllers/player_display_name_controller.dart';
import 'package:aphidex/services/player_profile_share_service.dart';
import 'package:aphidex/widgets/game_brand_mark.dart';
import 'package:aphidex/widgets/player_character_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('aphidex_profile_');
    Hive.init(hiveDirectory.path);
    await Hive.openBox('aphidex');
  });

  tearDownAll(() async {
    await Hive.box('aphidex').close();
    await hiveDirectory.delete(recursive: true);
  });

  setUp(() async {
    await Hive.box('aphidex').clear();
    PlayerProfileController.instance.reloadFromStorage();
    PlayerDisplayNameController.instance.reloadFromStorage();
  });

  test('catalog keeps G1 and G2 character options separate', () {
    final grounded = PlayerCharacterCatalog.forGame(AphidexGame.grounded);
    final groundedTwo = PlayerCharacterCatalog.forGame(AphidexGame.groundedTwo);

    expect(grounded, hasLength(6));
    expect(groundedTwo, hasLength(5));
    expect(
      grounded.map((character) => character.id),
      everyElement(startsWith('g1_')),
    );
    expect(
      groundedTwo.map((character) => character.id),
      everyElement(startsWith('g2_')),
    );
    expect(
      groundedTwo.map((character) => character.id),
      contains('g2_masked_stranger'),
    );
    expect(
      grounded.map((character) => character.id),
      isNot(contains('g2_masked_stranger')),
    );
    for (final character in PlayerCharacterCatalog.all) {
      expect(File(character.assetPath).existsSync(), isTrue);
      expect(character.avatar.scale, greaterThan(0));
      expect(character.avatar.alignment.x.isFinite, isTrue);
      expect(character.avatar.alignment.y.isFinite, isTrue);
    }
    expect(
      PlayerCharacterCatalog.byId('g1_burgl')!.type,
      PlayerCharacterType.portrait,
    );
    expect(
      PlayerCharacterCatalog.byId('g1_wendell')!.type,
      PlayerCharacterType.portrait,
    );
    final burgl = PlayerCharacterCatalog.byId('g1_burgl')!;
    final wendell = PlayerCharacterCatalog.byId('g1_wendell')!;
    expect(burgl.avatar.scale, 1.3);
    expect(burgl.avatar.padding, EdgeInsets.zero);
    expect(wendell.avatar.scale, 1.3);
    expect(wendell.avatar.padding, EdgeInsets.zero);
    final groundedTwoTeens = [
      'g2_max',
      'g2_willow',
      'g2_pete',
      'g2_hoops',
    ].map((id) => PlayerCharacterCatalog.byId(id)!.avatar).toList();
    expect(
      groundedTwoTeens.map((avatar) => avatar.scale),
      everyElement(greaterThan(1.1)),
    );
    expect(
      groundedTwoTeens.map((avatar) => avatar.scale).toSet(),
      hasLength(4),
    );
    expect(PlayerCharacterCatalog.byId('g2_pete')!.avatar.scale, 1.18);
  });

  test('profiles start empty and persist independently by game', () async {
    final profile = PlayerProfileController.instance;

    expect(profile.selectedIdFor(AphidexGame.grounded), isNull);
    expect(profile.selectedIdFor(AphidexGame.groundedTwo), isNull);

    await profile.select(AphidexGame.grounded, 'g1_max');
    await profile.select(AphidexGame.groundedTwo, 'g2_masked_stranger');
    profile.reloadFromStorage();

    expect(profile.selectedIdFor(AphidexGame.grounded), 'g1_max');
    expect(
      profile.selectedIdFor(AphidexGame.groundedTwo),
      'g2_masked_stranger',
    );

    await profile.clear(AphidexGame.grounded);
    expect(profile.selectedIdFor(AphidexGame.grounded), isNull);
    expect(
      profile.selectedIdFor(AphidexGame.groundedTwo),
      'g2_masked_stranger',
    );
  });

  test('a profile cannot be assigned to a different game', () async {
    await expectLater(
      PlayerProfileController.instance.select(AphidexGame.grounded, 'g2_max'),
      throwsArgumentError,
    );
  });

  test(
    'the local display name is shared, trimmed, persistent and limited',
    () async {
      final name = PlayerDisplayNameController.instance;

      expect(name.displayName.value, isEmpty);
      await name.save('  ByteShark Explorer  ');
      expect(name.displayName.value, 'ByteShark Explorer');

      await PlayerProfileController.instance.select(
        AphidexGame.grounded,
        'g1_max',
      );
      await PlayerProfileController.instance.select(
        AphidexGame.groundedTwo,
        'g2_hoops',
      );
      name.reloadFromStorage();
      expect(name.displayName.value, 'ByteShark Explorer');

      await name.save('x' * 30);
      expect(name.displayName.value, hasLength(24));
      expect(
        PlayerDisplayNameController.normalize('  name across languages  '),
        'name across languages',
      );
    },
  );

  test(
    'profile share helpers use a safe filename and contain capture failures',
    () async {
      expect(
        PlayerProfileShareService.fileNameFor(AphidexGame.grounded),
        'aphidex_profile_grounded.png',
      );
      expect(
        PlayerProfileShareService.fileNameFor(AphidexGame.groundedTwo),
        'aphidex_profile_grounded_2.png',
      );
      await expectLater(
        PlayerProfileShareService.capturePanel(GlobalKey()),
        completion(isNull),
      );
    },
  );

  test('localized share messages include progress and the public site', () {
    final english = AppLocalizations(const Locale('en'));
    final spanish = AppLocalizations(const Locale('es'));
    final russian = AppLocalizations(const Locale('ru'));
    final englishMessage = english.playerProfileShareMessage(
      displayName: 'Gam3r1Shark',
      game: 'Grounded 2',
      creatureCards: '1/91',
      goldCards: '0/91',
      kills: '27',
      website: AphidexLinks.publicWebsite,
    );
    final spanishMessage = spanish.playerProfileShareMessage(
      game: 'Grounded',
      creatureCards: '2/10',
      goldCards: '1/10',
      kills: '12',
      website: AphidexLinks.publicWebsite,
    );
    final russianMessage = russian.playerProfileShareMessage(
      displayName: 'Игрок',
      game: 'Grounded 2',
      creatureCards: '3/91',
      goldCards: '2/91',
      kills: '8',
      website: AphidexLinks.publicWebsite,
    );

    for (final message in [englishMessage, russianMessage]) {
      expect(message, contains(AphidexLinks.publicWebsite));
      expect(message, contains('Creature Cards'));
    }
    expect(spanishMessage, contains(AphidexLinks.publicWebsite));
    expect(englishMessage, allOf(contains('Gam3r1Shark'), contains('1/91')));
    expect(
      spanishMessage,
      allOf(
        contains('Grounded'),
        contains('2/10'),
        contains('12 eliminaciones'),
      ),
    );
    expect(russianMessage, allOf(contains('Игрок'), contains('3/91')));
  });

  test('profile game resolver uses the last concrete game for Both', () {
    expect(
      GameSelectionController.resolveProfileGame(
        gamePick: GamePick.g1,
        lastConcreteGame: GamePick.g2,
      ),
      AphidexGame.grounded,
    );
    expect(
      GameSelectionController.resolveProfileGame(
        gamePick: GamePick.g2,
        lastConcreteGame: GamePick.g1,
      ),
      AphidexGame.groundedTwo,
    );
    expect(
      GameSelectionController.resolveProfileGame(
        gamePick: GamePick.all,
        lastConcreteGame: GamePick.g2,
      ),
      AphidexGame.groundedTwo,
    );
    expect(
      GameSelectionController.resolveProfileGame(gamePick: GamePick.all),
      AphidexGame.grounded,
    );
  });

  test('profile card labels are localized for all supported languages', () {
    expect(
      AppLocalizations(const Locale('es')).playerProfileCreatureCards,
      'Tarjetas de criatura',
    );
    expect(
      AppLocalizations(const Locale('en')).playerProfileCreatureCards,
      'Creature Cards',
    );
    expect(
      AppLocalizations(const Locale('ru')).playerProfileCreatureCards,
      isNot('Creature Cards'),
    );
  });

  test('each character has the required visual theme', () {
    expect(
      PlayerCharacterThemes.forCharacter(
        PlayerCharacterCatalog.byId('g1_max'),
      ).backgroundEnd,
      const Color(0xFFE78625),
    );
    expect(
      PlayerCharacterThemes.forCharacter(
        PlayerCharacterCatalog.byId('g1_willow'),
      ).backgroundEnd,
      const Color(0xFF0C7A7A),
    );
    expect(
      PlayerCharacterThemes.forCharacter(
        PlayerCharacterCatalog.byId('g1_hoops'),
      ).backgroundEnd,
      const Color(0xFFA72D68),
    );
    expect(
      PlayerCharacterThemes.forCharacter(
        PlayerCharacterCatalog.byId('g1_pete'),
      ).backgroundEnd,
      const Color(0xFF4EA0D8),
    );
    expect(
      PlayerCharacterThemes.forCharacter(
        PlayerCharacterCatalog.byId('g1_burgl'),
      ).backgroundStart,
      const Color(0xFF071B3B),
    );
    expect(
      PlayerCharacterThemes.forCharacter(
        PlayerCharacterCatalog.byId('g1_wendell'),
      ).backgroundStart,
      const Color(0xFF1D3821),
    );
    expect(
      PlayerCharacterThemes.forCharacter(
        PlayerCharacterCatalog.byId('g2_masked_stranger'),
      ).backgroundStart,
      const Color(0xFF31124A),
    );
    expect(
      PlayerCharacterThemes.forCharacter(null),
      PlayerCharacterThemes.empty,
    );
  });

  test('card totals are calculated only from the supplied game entries', () {
    const groundedCard = _FakeCardCarrier(
      id: 'g1_card',
      game: 'g1',
      normalAsset: 'normal.webp',
      goldAsset: 'gold.webp',
    );
    const groundedTwoCard = _FakeCardCarrier(
      id: 'g2_card',
      game: 'g2',
      normalAsset: 'normal.webp',
    );
    final progress = <String, CreatureCardProgress>{
      creatureCardProgressKey(groundedCard): CreatureCardProgress.gold,
      creatureCardProgressKey(groundedTwoCard): CreatureCardProgress.obtained,
    };

    expect(
      summarizePlayerProfileStats([groundedCard], progress),
      isA<PlayerProfileStats>()
          .having((stats) => stats.cardsObtained, 'cards obtained', 1)
          .having((stats) => stats.cardsTotal, 'cards total', 1)
          .having((stats) => stats.goldCardsObtained, 'gold obtained', 1)
          .having((stats) => stats.goldCardsTotal, 'gold total', 1),
    );
    expect(
      summarizePlayerProfileStats([groundedTwoCard], progress),
      isA<PlayerProfileStats>()
          .having((stats) => stats.cardsObtained, 'cards obtained', 1)
          .having((stats) => stats.goldCardsTotal, 'gold total', 0),
    );
  });

  test('linked base and Buggie entries count as one profile card', () {
    const base = _FakeCardCarrier(
      id: 'g2_ladybug',
      game: 'g2',
      normalAsset: 'normal.webp',
      goldAsset: 'gold.webp',
    );
    const buggy = _FakeCardCarrier(
      id: 'g2_buggy_ladybug',
      game: 'g2',
      goldLinkId: 'g2_ladybug',
      normalAsset: 'buggy-normal.webp',
      goldAsset: 'buggy-gold.webp',
    );

    final stats = summarizePlayerProfileStats(
      [base, buggy],
      const <String, CreatureCardProgress>{
        'g2:g2_ladybug': CreatureCardProgress.gold,
      },
    );

    expect(stats.cardsTotal, 1);
    expect(stats.cardsObtained, 1);
    expect(stats.goldCardsTotal, 1);
    expect(stats.goldCardsObtained, 1);
  });

  test('profile copy is available in Spanish, English, and Russian', () {
    final spanish = AppLocalizations(const Locale('es'));
    final english = AppLocalizations(const Locale('en'));
    final russian = AppLocalizations(const Locale('ru'));

    expect(spanish.playerProfileChooseAction, 'Elegir personaje');
    expect(english.playerProfileChangeAction, 'Change character');
    expect(russian.playerProfileTitle, 'Профиль игрока');
    expect(russian.playerProfileGoldCards, 'Золотые карты');
    expect(
      russian.playerCharacterName('g2_masked_stranger'),
      'Таинственная незнакомка в маске',
    );
  });

  testWidgets(
    'only one dynamic panel is shown and it follows the active game',
    (tester) async {
      await tester.pumpWidget(
        _testApp(
          PlayerProfileGamePanel(
            game: AphidexGame.grounded,
            character: PlayerCharacterCatalog.byId('g1_max'),
            stats: const PlayerProfileStats.empty(),
            onChangeCharacter: () {},
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('player-profile-dynamic-panel')),
        findsOne,
      );
      expect(find.byType(PlayerCharacterAvatar), findsOneWidget);
      expect(find.text('Max'), findsOneWidget);
      expect(find.text('Grounded 2'), findsNothing);
      expect(find.text('Eliminations'), findsOneWidget);

      await tester.pumpWidget(
        _testApp(
          PlayerProfileGamePanel(
            game: AphidexGame.groundedTwo,
            character: PlayerCharacterCatalog.byId('g2_masked_stranger'),
            stats: const PlayerProfileStats.empty(),
            onChangeCharacter: () {},
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('player-profile-dynamic-panel')),
        findsOne,
      );
      expect(find.byType(PlayerCharacterAvatar), findsOneWidget);
      expect(find.text('Masked Stranger'), findsOneWidget);
      expect(find.text('Max'), findsNothing);
    },
  );

  testWidgets('empty profile panel keeps its size and shows a plus action', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        PlayerProfileGamePanel(
          game: AphidexGame.grounded,
          character: null,
          stats: null,
          onChangeCharacter: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('+'), findsOneWidget);
    expect(find.text('Choose character'), findsOneWidget);
    expect(find.byKey(const ValueKey('change-player-character')), findsOne);
    expect(find.byType(PlayerCharacterAvatar), findsOneWidget);
  });

  testWidgets('avatars remain square and selector uses compact avatars', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        SizedBox(
          height: 420,
          child: PlayerProfileCharacterSelector(game: AphidexGame.groundedTwo),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(PlayerCharacterAvatar), findsAtLeastNWidgets(1));
    expect(
      find.byKey(const ValueKey('player-profile-option-g1_max')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('player-profile-option-g2_max')),
      findsOneWidget,
    );
    final avatarSize = tester.getSize(
      find.byKey(const ValueKey('player-character-avatar')).first,
    );
    expect(avatarSize.width, avatarSize.height);
  });

  testWidgets('avatars keep two rings and clip transformed portraits', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            PlayerCharacterAvatar(
              character: PlayerCharacterCatalog.byId('g1_burgl'),
              size: 150,
              theme: PlayerCharacterThemes.forCharacter(
                PlayerCharacterCatalog.byId('g1_burgl'),
              ),
            ),
            PlayerCharacterAvatar(
              character: PlayerCharacterCatalog.byId('g1_wendell'),
              size: 150,
              theme: PlayerCharacterThemes.forCharacter(
                PlayerCharacterCatalog.byId('g1_wendell'),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('player-character-avatar-outer-ring')),
      findsNWidgets(2),
    );
    expect(
      find.byKey(const ValueKey('player-character-avatar-inner-ring')),
      findsNWidgets(2),
    );
    expect(
      find.byKey(const ValueKey('player-character-avatar-clip')),
      findsNWidgets(2),
    );
    for (final avatar
        in find.byKey(const ValueKey('player-character-avatar')).evaluate()) {
      final size = tester.getSize(
        find.byElementPredicate((element) => element == avatar),
      );
      expect(size.width, size.height);
    }
  });

  testWidgets('game selector uses the existing game brand marks', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        const PlayerProfileGameSelector(activeGame: AphidexGame.grounded),
      ),
    );
    await tester.pump();

    expect(find.byType(GameBrandMark), findsNWidgets(2));
    expect(find.byIcon(Icons.grass_outlined), findsNothing);
    expect(find.byIcon(Icons.science_outlined), findsNothing);
  });

  testWidgets(
    'game selector resolves matching adaptive colors for SVGs and labels',
    (tester) async {
      final themes = [
        ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
        ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: Brightness.dark,
          ),
        ),
      ];

      for (final theme in themes) {
        await tester.pumpWidget(
          _testApp(
            const PlayerProfileGameSelector(activeGame: AphidexGame.grounded),
            theme: theme,
          ),
        );
        await tester.pump();

        final colorScheme = Theme.of(
          tester.element(find.byType(PlayerProfileGameSelector)),
        ).colorScheme;
        final marks = tester.widgetList<GameBrandMark>(
          find.byType(GameBrandMark),
        );
        expect(marks.first.color, colorScheme.onSecondaryContainer);
        expect(marks.last.color, colorScheme.onSurfaceVariant);
        expect(
          tester.widget<Text>(find.text('Grounded')).style!.color,
          colorScheme.onSecondaryContainer,
        );
        expect(
          tester.widget<Text>(find.text('Grounded 2')).style!.color,
          colorScheme.onSurfaceVariant,
        );
      }
    },
  );

  testWidgets('display names use symmetric edit slots and remain centered', (
    tester,
  ) async {
    for (final name in ['Ana', 'ByteShark Dev', 'x' * 24]) {
      await tester.pumpWidget(
        _testApp(
          PlayerProfileGamePanel(
            game: AphidexGame.grounded,
            character: PlayerCharacterCatalog.byId('g1_max'),
            stats: const PlayerProfileStats.empty(),
            displayName: name,
            onChangeCharacter: () {},
            onEditDisplayName: () {},
          ),
          width: 390,
        ),
      );
      await tester.pump();

      expect(
        tester.getSize(
          find.byKey(const ValueKey('player-display-name-left-slot')),
        ),
        tester.getSize(
          find.byKey(const ValueKey('player-display-name-edit-slot')),
        ),
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('player-display-name-text')),
            )
            .textAlign,
        TextAlign.center,
      );
      expect(
        tester
            .getCenter(find.byKey(const ValueKey('player-display-name-group')))
            .dx,
        closeTo(
          tester
              .getCenter(
                find.byKey(const ValueKey('player-profile-dynamic-panel')),
              )
              .dx,
          1,
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'vertical panel places complete stat cards below the avatar and hides controls for export',
    (tester) async {
      await tester.pumpWidget(
        _testApp(
          PlayerProfileGamePanel(
            game: AphidexGame.grounded,
            character: PlayerCharacterCatalog.byId('g1_hoops'),
            stats: const PlayerProfileStats.empty(),
            displayName: 'Player',
            isExporting: true,
            onChangeCharacter: () {},
          ),
          width: 390,
        ),
      );
      await tester.pump();

      final avatar = find.byType(PlayerCharacterAvatar);
      final cards = find.text('Creature Cards');
      expect(
        tester.getTopLeft(cards).dy,
        greaterThan(tester.getCenter(avatar).dy),
      );
      expect(
        find.byKey(const ValueKey('change-player-character')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('share-player-profile')), findsNothing);
      expect(find.text('Aphidex'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('player-profile-export-watermark-logo')),
        findsOneWidget,
      );
      final boundary = find.byType(RepaintBoundary);
      expect(
        find.descendant(
          of: boundary,
          matching: find.byKey(
            const ValueKey('player-profile-export-watermark'),
          ),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .getCenter(find.byKey(const ValueKey('player-display-name-group')))
            .dx,
        closeTo(
          tester
              .getCenter(
                find.byKey(const ValueKey('player-profile-dynamic-panel')),
              )
              .dx,
          1,
        ),
      );
    },
  );

  testWidgets('sharing is disabled when no character is selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        PlayerProfileGamePanel(
          game: AphidexGame.grounded,
          character: null,
          stats: null,
          onChangeCharacter: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('share-player-profile')), findsOneWidget);
  });
}

Widget _testApp(Widget home, {double width = 420, ThemeData? theme}) {
  return MaterialApp(
    theme: theme,
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, child: home),
      ),
    ),
  );
}

class _FakeCardCarrier implements CreatureCardCarrier {
  const _FakeCardCarrier({
    required this.id,
    required this.game,
    this.normalAsset = '',
    this.goldAsset = '',
    this.goldLinkId,
  });

  @override
  final String id;
  @override
  final String game;
  final String normalAsset;
  final String goldAsset;

  @override
  final String? goldLinkId;

  @override
  bool get defaultGold => false;

  @override
  bool get hasCreatureCard => normalAsset.isNotEmpty || goldAsset.isNotEmpty;

  @override
  bool get hasGoldCreatureCard => goldAsset.isNotEmpty;

  @override
  bool get hasSelectableCardVariants =>
      normalAsset.isNotEmpty && goldAsset.isNotEmpty;

  @override
  CreatureCardVariant? get defaultCardVariant => normalAsset.isNotEmpty
      ? CreatureCardVariant.normal
      : goldAsset.isNotEmpty
      ? CreatureCardVariant.gold
      : null;

  @override
  String? assetForCardVariant(CreatureCardVariant variant) => switch (variant) {
    CreatureCardVariant.normal => normalAsset.isEmpty ? null : normalAsset,
    CreatureCardVariant.gold => goldAsset.isEmpty ? null : goldAsset,
  };
}
