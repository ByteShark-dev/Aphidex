import 'package:flutter/material.dart';

import '../controllers/favorites_controller.dart';
import '../controllers/creature_kill_count_controller.dart';
import '../controllers/gold_controller.dart';
import '../controllers/monetization_controller.dart';
import '../controllers/tutorial_controller.dart';
import '../data/creature_card_state.dart';
import '../data/creature_kill_tracking.dart';
import '../data/enemy_repository.dart';
import '../data/effect_catalog.dart';
import '../data/local_storage.dart';
import '../data/tier_summary.dart';
import '../data/ui_mapper.dart';
import '../i18n/app_localizations.dart';
import '../layout/app_breakpoints.dart';
import '../models/enemy.dart';
import '../models/enemy_index_entry.dart';
import '../models/game_pick.dart';
import '../widgets/fallback_asset_image.dart';
import '../widgets/icon_badge.dart';
import '../widgets/inline_banner_ad_card.dart';
import '../widgets/overflow_marquee_text.dart';
import '../widgets/state_panels.dart';
import 'effect_codex_screen.dart';

String? _visibleText(LocalizedText? text, String languageCode) {
  final value = text?.resolve(languageCode).trim();
  return value == null || value.isEmpty ? null : value;
}

bool _hasLocalizedText(LocalizedText? text, String languageCode) =>
    _visibleText(text, languageCode) != null;

List<String> _visibleLocalizedValues(
  Iterable<LocalizedText> values,
  String languageCode,
) => values
    .map((item) => item.resolve(languageCode).trim())
    .where((item) => item.isNotEmpty)
    .toList(growable: false);

bool _hasVisibleLocalizedList(
  Iterable<LocalizedText> values,
  String languageCode,
) => _visibleLocalizedValues(values, languageCode).isNotEmpty;

Future<void> _openTutorialAwareEffectDetails(
  BuildContext context,
  String effectId, {
  String? tutorialEffectId,
}) async {
  final tutorial = TutorialController.instance;
  if (tutorial.step == TutorialStep.detailEffect &&
      tutorialEffectId == effectId) {
    await tutorial.next();
    return;
  }

  await showEffectInfoSheet(context, effectId: effectId);
}

List<BonusInfo> _mergeBonuses(
  Iterable<BonusInfo> base,
  Iterable<BonusInfo> overrides,
) {
  final merged = [...base];
  for (final bonus in overrides) {
    final index = merged.indexWhere((item) => item.type == bonus.type);
    if (index == -1) {
      merged.add(bonus);
    } else {
      merged[index] = bonus;
    }
  }
  return merged;
}

List<String> _mergeStringIds(
  Iterable<String> base,
  Iterable<String> additions,
) {
  final merged = <String>[];
  for (final item in [...base, ...additions]) {
    final normalized = item.trim();
    if (normalized.isEmpty || merged.contains(normalized)) {
      continue;
    }
    merged.add(normalized);
  }
  return merged;
}

List<LocalizedText> _mergeLocalizedTexts(
  Iterable<LocalizedText> base,
  Iterable<LocalizedText> additions,
) {
  final merged = <LocalizedText>[];
  final seen = <String>{};

  void addAll(Iterable<LocalizedText> values) {
    for (final value in values) {
      final key = '${value.es ?? ''}|${value.en ?? ''}|${value.ru ?? ''}';
      if (value.isEmpty || seen.contains(key)) {
        continue;
      }
      seen.add(key);
      merged.add(value);
    }
  }

  addAll(base);
  addAll(additions);
  return merged;
}

class EnemyDetailScreen extends StatefulWidget {
  final Enemy? enemy;
  final List<Enemy>? variants;
  final EnemyIndexEntry? summary;
  final List<EnemyIndexEntry>? variantSummaries;
  final List<EnemyIndexEntry>? relatedSummaries;
  final String? initialGame;
  final TutorialTargetScope tutorialTargetScope;

  const EnemyDetailScreen({
    super.key,
    this.enemy,
    this.variants,
    this.summary,
    this.variantSummaries,
    this.relatedSummaries,
    this.initialGame,
    this.tutorialTargetScope = TutorialTargetScope.inlineDetail,
  }) : assert(enemy != null || summary != null);

  @override
  State<EnemyDetailScreen> createState() => _EnemyDetailScreenState();
}

class _EnemyDetailScreenState extends State<EnemyDetailScreen> {
  late final List<Enemy>? _legacyVariants;
  late final List<EnemyIndexEntry>? _summaryVariants;
  late int _selectedIndex;
  int _selectedPhaseIndex = 0;
  int _selectedInfusionIndex = 0;
  int _selectedEncounterIndex = 0;
  String? _groupSelectedId;
  Future<Enemy>? _enemyFuture;
  Future<List<EnemyIndexEntry>>? _groupSummariesFuture;
  String? _loadedLanguageCode;

  bool get _usesLazyDetails => _summaryVariants != null;

  int get _variantCount =>
      _usesLazyDetails ? _summaryVariants!.length : _legacyVariants!.length;

  String get _currentId =>
      _groupSelectedId ??
      (_usesLazyDetails
          ? _summaryVariants![_selectedIndex].id
          : _legacyVariants![_selectedIndex].id);

  String get _currentSpeciesKey => _usesLazyDetails
      ? _summaryVariants![_selectedIndex].speciesKey
      : _legacyVariants![_selectedIndex].speciesKey;

  String _currentTitle(String languageCode) => _usesLazyDetails
      ? _summaryVariants![_selectedIndex].name
      : _legacyVariants![_selectedIndex].name.resolve(languageCode);

  @override
  void initState() {
    super.initState();
    if (widget.summary != null) {
      _summaryVariants = [
        ...(widget.variantSummaries ?? [widget.summary!]),
      ];
      _legacyVariants = null;
    } else {
      _legacyVariants = [
        ...(widget.variants ?? [widget.enemy!]),
      ];
      _summaryVariants = null;
    }
    _sortVariants();
    _selectedIndex = _resolveInitialIndex();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_usesLazyDetails) {
      return;
    }

    final languageCode = context.l10n.languageCode;
    if (_loadedLanguageCode == languageCode && _enemyFuture != null) {
      return;
    }
    _loadedLanguageCode = languageCode;
    _enemyFuture = EnemyRepository.loadDetail(_currentId, languageCode);
    _groupSummariesFuture = _loadGroupSummaries(
      languageCode,
      index: _selectedIndex,
    );
  }

  int _compareVariantGames(
    String aGame,
    int? aOrder,
    String bGame,
    int? bOrder,
  ) {
    if (aGame == bGame) {
      return (aOrder ?? 999999).compareTo(bOrder ?? 999999);
    }
    if (aGame == 'g1') {
      return -1;
    }
    if (bGame == 'g1') {
      return 1;
    }
    return aGame.compareTo(bGame);
  }

  Future<Enemy> _loadCurrentDetail() {
    return EnemyRepository.loadDetail(
      _currentId,
      _loadedLanguageCode ?? context.l10n.languageCode,
    );
  }

  Future<List<EnemyIndexEntry>>? _loadGroupSummaries(
    String languageCode, {
    required int index,
  }) {
    if (widget.relatedSummaries != null) {
      return Future.value(widget.relatedSummaries);
    }
    if (!_usesLazyDetails) {
      return null;
    }
    final groupId = _summaryVariants![index].groupId;
    if (groupId == null || groupId.isEmpty) {
      return null;
    }
    return EnemyRepository.loadGame('g2', languageCode).then(
      (entries) => entries
          .where((entry) => entry.groupId == groupId && entry.game == 'g2')
          .toList(growable: false),
    );
  }

  int _variantIndexWhereGame(String game) {
    if (_usesLazyDetails) {
      return _summaryVariants!.indexWhere((enemy) => enemy.game == game);
    }
    return _legacyVariants!.indexWhere((enemy) => enemy.game == game);
  }

  void _sortVariants() {
    if (_usesLazyDetails) {
      _summaryVariants!.sort(
        (a, b) => _compareVariantGames(a.game, a.order, b.game, b.order),
      );
      return;
    }
    _legacyVariants!.sort(
      (a, b) => _compareVariantGames(a.game, a.order, b.game, b.order),
    );
  }

  int _resolveInitialIndex() {
    final fallbackSpeciesKey = _usesLazyDetails
        ? _summaryVariants!.first.speciesKey
        : _legacyVariants!.first.speciesKey;
    final fallbackGame = _usesLazyDetails
        ? _summaryVariants!.first.game
        : _legacyVariants!.first.game;
    final preferredGame =
        widget.initialGame ??
        LocalStorage.getString(_variantPreferenceKey(fallbackSpeciesKey)) ??
        fallbackGame;

    for (var i = 0; i < _variantCount; i++) {
      final game = _usesLazyDetails
          ? _summaryVariants![i].game
          : _legacyVariants![i].game;
      if (game == preferredGame) {
        return i;
      }
    }

    return 0;
  }

  bool _hasV2(Enemy enemy) =>
      enemy.health != null ||
      enemy.elementalWeaknesses.isNotEmpty ||
      enemy.damageWeaknesses.isNotEmpty ||
      enemy.resistancesV2.isNotEmpty ||
      enemy.infusions.isNotEmpty ||
      enemy.resolvedWeakPoints.isNotEmpty ||
      enemy.attacks.isNotEmpty;

  bool _hasWikiContent(Enemy enemy) {
    final languageCode = context.l10n.languageCode;
    return _hasLocalizedText(enemy.description, languageCode) ||
        _hasVisibleLocalizedList(enemy.environments, languageCode) ||
        _hasLocalizedText(enemy.respawnInfo, languageCode) ||
        enemy.combatStats != null ||
        enemy.loot.isNotEmpty ||
        enemy.advancedLootTable.isNotEmpty ||
        enemy.lootTransformations.isNotEmpty ||
        enemy.inflictsEffects.isNotEmpty ||
        _hasVisibleLocalizedList(enemy.inflicts, languageCode) ||
        _hasVisibleLocalizedList(enemy.specialTraits, languageCode) ||
        _hasLocalizedText(enemy.lesserMutationsDescription, languageCode) ||
        _hasVisibleLocalizedList(enemy.lesserMutations, languageCode) ||
        enemy.infusions.isNotEmpty ||
        enemy.abilities.isNotEmpty ||
        _hasLocalizedText(enemy.behavior, languageCode) ||
        _hasLocalizedText(enemy.interactionWithPlayer, languageCode) ||
        _hasLocalizedText(enemy.interactionWithCreatures, languageCode) ||
        _hasLocalizedText(enemy.strategy, languageCode);
  }

  bool _hasCombatMoves(Enemy enemy) =>
      enemy.abilities.isNotEmpty ||
      enemy.attacks.isNotEmpty ||
      enemy.bossPhases.isNotEmpty;

  void _openEffectDetails(
    BuildContext context,
    String effectId, {
    String? tutorialEffectId,
  }) {
    _openTutorialAwareEffectDetails(
      context,
      effectId,
      tutorialEffectId: tutorialEffectId,
    );
  }

  GamePick _gamePickForEnemy(Enemy enemy) {
    return switch (enemy.game) {
      'g2' => GamePick.g2,
      _ => GamePick.g1,
    };
  }

  Future<void> _selectVariant(String game) async {
    final nextIndex = _variantIndexWhereGame(game);
    if (nextIndex == -1 || nextIndex == _selectedIndex) {
      return;
    }

    await LocalStorage.setString(
      _variantPreferenceKey(_currentSpeciesKey),
      game,
    );
    if (!mounted) {
      return;
    }
    final languageCode = _loadedLanguageCode ?? context.l10n.languageCode;
    final nextGroupSummaries = _loadGroupSummaries(
      languageCode,
      index: nextIndex,
    );
    setState(() {
      _selectedIndex = nextIndex;
      _selectedPhaseIndex = 0;
      _selectedInfusionIndex = 0;
      _selectedEncounterIndex = 0;
      _groupSelectedId = null;
      _groupSummariesFuture = nextGroupSummaries;
      if (_usesLazyDetails) {
        _enemyFuture = EnemyRepository.loadDetail(_currentId, languageCode);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TutorialController.instance.requestTargetRefresh();
    });
  }

  void _selectGroupedEntry(String id) {
    if (id == _currentId) return;
    setState(() {
      _groupSelectedId = id;
      _selectedPhaseIndex = 0;
      _selectedInfusionIndex = 0;
      _selectedEncounterIndex = 0;
      _enemyFuture = EnemyRepository.loadDetail(
        id,
        _loadedLanguageCode ?? context.l10n.languageCode,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_usesLazyDetails) {
      final future = _enemyFuture ??= _loadCurrentDetail();
      return FutureBuilder<Enemy>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _buildLoadingScaffold(context);
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _buildErrorScaffold(context, snapshot.error);
          }
          return _buildLoaded(context, snapshot.data!);
        },
      );
    }

    return _buildLoaded(context, _legacyVariants![_selectedIndex]);
  }

  Widget _buildLoadingScaffold(BuildContext context) {
    final languageCode = context.l10n.languageCode;
    return Scaffold(
      appBar: AppBar(
        title: OverflowMarqueeText(
          _currentTitle(languageCode),
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: AphidexLoadingPanel(
            gamePick: GamePick.all,
            title: context.l10n.loadingCreaturesTitle,
            subtitle: context.l10n.loadingCreatureDetailSubtitle,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScaffold(BuildContext context, Object? error) {
    final languageCode = context.l10n.languageCode;
    return Scaffold(
      appBar: AppBar(
        title: OverflowMarqueeText(
          _currentTitle(languageCode),
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: AphidexStatePanel(
            gamePick: GamePick.all,
            icon: Icons.cloud_off_rounded,
            title: context.l10n.dataUnavailableTitle,
            subtitle: error == null
                ? context.l10n.dataUnavailableSubtitle
                : '${context.l10n.errorLoadingJson}\n$error',
          ),
        ),
      ),
    );
  }

  Widget _buildLoaded(BuildContext context, Enemy enemy) {
    final l10n = context.l10n;
    final languageCode = l10n.languageCode;
    final viewportSize = MediaQuery.sizeOf(context);
    final surface = AppBreakpoints.surfaceForWidth(viewportSize.width);
    final pagePadding = surface.pagePadding;
    final useSummaryRow = surface.isExpanded || surface.isWide;
    final showCreatureCards = AppBreakpoints.shouldShowCreatureCards(
      viewportSize,
    );
    final favorites = FavoritesController.instance;
    final gold = GoldController.instance;
    final namedVariants = enemy.encounterVariants;
    final selectedEncounter =
        namedVariants.isEmpty || _selectedEncounterIndex == 0
        ? null
        : namedVariants[(_selectedEncounterIndex - 1).clamp(
            0,
            namedVariants.length - 1,
          )];
    final displayName =
        selectedEncounter?.name.resolve(languageCode).trim().isNotEmpty == true
        ? selectedEncounter!.name.resolve(languageCode)
        : enemy.name.resolve(languageCode);
    final effectiveHealth = selectedEncounter?.health ?? enemy.health;
    final effectiveAttacks = selectedEncounter?.attacks.isNotEmpty == true
        ? selectedEncounter!.attacks
        : enemy.attacks;
    final selectedInfusion = enemy.infusions.isEmpty
        ? null
        : enemy.infusions[_selectedInfusionIndex.clamp(
            0,
            enemy.infusions.length - 1,
          )];
    final visiblePhotoAsset =
        selectedInfusion?.resolvedImageAsset(enemy.photo) ?? enemy.photo;
    final weaknessesV1 = enemy.weaknesses
        .where((item) => item.trim().isNotEmpty)
        .toList();
    final resistancesV1 = enemy.resistances
        .where((item) => item.trim().isNotEmpty)
        .toList();
    final encounterElemental = selectedEncounter?.elementalWeaknesses;
    final encounterDamage = selectedEncounter?.damageWeaknesses;
    final encounterResistances = selectedEncounter?.resistances;
    final effectiveElementalWeaknesses = _mergeBonuses(
      encounterElemental?.isNotEmpty == true
          ? encounterElemental!
          : enemy.elementalWeaknesses,
      selectedInfusion?.elementalWeaknesses ?? const [],
    );
    final effectiveDamageWeaknesses = _mergeBonuses(
      encounterDamage?.isNotEmpty == true
          ? encounterDamage!
          : enemy.damageWeaknesses,
      selectedInfusion?.damageWeaknesses ?? const [],
    );
    final effectiveResistances = _mergeBonuses(
      encounterResistances?.isNotEmpty == true
          ? encounterResistances!
          : enemy.resistancesV2,
      selectedInfusion?.resistances ?? const [],
    );
    final effectiveInflictsEffects = _mergeStringIds(
      enemy.inflictsEffects,
      selectedInfusion?.effects ?? const [],
    );
    final effectiveTraits = _mergeLocalizedTexts(
      enemy.specialTraits,
      selectedInfusion?.specialTraits ?? const [],
    );
    final normalizedElementalWeaknesses = effectiveElementalWeaknesses
        .where((bonus) => bonus.type != 'water')
        .toList();
    final normalizedDamageWeaknesses = [
      ...effectiveDamageWeaknesses,
      ...effectiveElementalWeaknesses.where((bonus) => bonus.type == 'water'),
    ];
    final description = _visibleText(enemy.description, languageCode);
    final behavior = _visibleText(enemy.behavior, languageCode);
    final interactionWithPlayer = _visibleText(
      enemy.interactionWithPlayer,
      languageCode,
    );
    final interactionWithCreatures = _visibleText(
      enemy.interactionWithCreatures,
      languageCode,
    );
    final strategy = _visibleText(enemy.strategy, languageCode);
    final infusionRecommendations = _visibleText(
      selectedInfusion?.recommendations,
      languageCode,
    );
    final infusionCombatTips = _visibleLocalizedValues(
      selectedInfusion?.combatTips ?? const [],
      languageCode,
    );
    final tutorial = TutorialController.instance;
    final tutorialEffectId = tutorial.tutorialEffectIdForEnemy(enemy.id);
    final tutorialEffectKey = tutorialEffectId == null
        ? null
        : tutorial.keyFor(
            tutorialAnchorDetailEffect(tutorialEffectId),
            scope: widget.tutorialTargetScope,
          );
    var tutorialAnchorAssigned = false;
    var detailEffectsAnchorAssigned = false;

    GlobalKey? consumeTutorialEffectKey(String effectId) {
      if (tutorialEffectKey == null ||
          tutorialAnchorAssigned ||
          tutorialEffectId != effectId) {
        return null;
      }
      tutorialAnchorAssigned = true;
      return tutorialEffectKey;
    }

    Widget wrapTutorialAnchor(String anchorId, {required Widget child}) {
      return KeyedSubtree(
        key: tutorial.keyFor(anchorId, scope: widget.tutorialTargetScope),
        child: child,
      );
    }

    Widget wrapDetailEffectsAnchor(Widget child) {
      if (detailEffectsAnchorAssigned) {
        return child;
      }
      detailEffectsAnchorAssigned = true;
      return KeyedSubtree(
        key: tutorial.keyFor(
          tutorialAnchorDetailEffects,
          scope: widget.tutorialTargetScope,
        ),
        child: child,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: OverflowMarqueeText(
          displayName,
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
        actions: [
          ValueListenableBuilder<Set<String>>(
            valueListenable: favorites.favorites,
            builder: (context, favIds, _) {
              final favoriteKey = enemy.resolvedFavoriteKey;
              final isFavorite = favIds.contains(favoriteKey);
              return IconButton(
                icon: Icon(isFavorite ? Icons.star : Icons.star_border),
                onPressed: () => favorites.toggle(favoriteKey),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            pagePadding.left,
            pagePadding.top,
            pagePadding.right,
            pagePadding.bottom,
          ),
          children: [
            if (_variantCount > 1) ...[
              wrapTutorialAnchor(
                tutorialAnchorDetailVariant,
                child: _VariantSwitcher(
                  selectedGame: enemy.game,
                  onChanged: _selectVariant,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_groupSummariesFuture != null) ...[
              FutureBuilder<List<EnemyIndexEntry>>(
                future: _groupSummariesFuture,
                builder: (context, snapshot) {
                  final entries = snapshot.data ?? const <EnemyIndexEntry>[];
                  if (entries.length < 2) return const SizedBox.shrink();
                  return _RelatedEntrySwitcher(
                    entries: entries,
                    selectedId: enemy.id,
                    onChanged: _selectGroupedEntry,
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
            if (namedVariants.isNotEmpty) ...[
              _EncounterVariantSwitcher(
                baseName: enemy.name.resolve(languageCode),
                variants: namedVariants,
                selectedIndex: _selectedEncounterIndex,
                languageCode: languageCode,
                onChanged: (index) => setState(() {
                  _selectedEncounterIndex = index;
                  _selectedPhaseIndex = 0;
                }),
              ),
              const SizedBox(height: 12),
            ],
            useSummaryRow
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 11,
                        child: wrapTutorialAnchor(
                          tutorialAnchorDetailSummary,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeOutCubic,
                            child: _DetailPhotoPanel(
                              key: ValueKey(
                                'detail-photo-${enemy.id}-${selectedInfusion?.id ?? 'base'}',
                              ),
                              photoAsset: visiblePhotoAsset,
                              title: displayName,
                              gamePick: _gamePickForEnemy(enemy),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 9,
                        child: _DetailSummarySidebar(
                          enemy: enemy,
                          gold: gold,
                          l10n: l10n,
                          showCreatureCards: showCreatureCards,
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      wrapTutorialAnchor(
                        tutorialAnchorDetailSummary,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeOutCubic,
                          child: _DetailPhotoPanel(
                            key: ValueKey(
                              'detail-photo-${enemy.id}-${selectedInfusion?.id ?? 'base'}',
                            ),
                            photoAsset: visiblePhotoAsset,
                            title: displayName,
                            gamePick: _gamePickForEnemy(enemy),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DetailSummarySidebar(
                        enemy: enemy,
                        gold: gold,
                        l10n: l10n,
                        showCreatureCards: showCreatureCards,
                      ),
                    ],
                  ),
            const SizedBox(height: 18),
            if (CreatureKillTracking.supportsEnemy(enemy)) ...[
              _KillCountSection(enemyId: enemy.id),
              const SizedBox(height: 18),
            ],
            if (description != null) ...[
              _TextSection(title: l10n.descriptionTitle, value: description),
              const SizedBox(height: 18),
            ],
            if (enemy.healthDisplay.shouldRender) ...[
              _HealthBar(
                health: effectiveHealth,
                displayMode: enemy.healthDisplay,
              ),
              const SizedBox(height: 18),
            ],
            if (enemy.infusions.length > 1) ...[
              _InfusionSwitcher(
                infusions: enemy.infusions,
                selectedIndex: _selectedInfusionIndex.clamp(
                  0,
                  enemy.infusions.length - 1,
                ),
                languageCode: languageCode,
                onChanged: (index) =>
                    setState(() => _selectedInfusionIndex = index),
              ),
              const SizedBox(height: 18),
            ],
            if (_hasV2(enemy)) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (normalizedElementalWeaknesses.isNotEmpty) ...[
                    wrapDetailEffectsAnchor(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.elementalWeakness,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          _BonusWrap(
                            bonuses: normalizedElementalWeaknesses,
                            tutorialEffectId: tutorialEffectId,
                            tutorialEffectKeyBuilder: consumeTutorialEffectKey,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (normalizedDamageWeaknesses.isNotEmpty) ...[
                    wrapDetailEffectsAnchor(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.damageWeakness,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          _BonusWrap(
                            bonuses: normalizedDamageWeaknesses,
                            tutorialEffectId: tutorialEffectId,
                            tutorialEffectKeyBuilder: consumeTutorialEffectKey,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (effectiveResistances.isNotEmpty) ...[
                    wrapDetailEffectsAnchor(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.resistancesTitle,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          _BonusWrap(
                            bonuses: effectiveResistances,
                            dim: true,
                            tutorialEffectId: tutorialEffectId,
                            tutorialEffectKeyBuilder: consumeTutorialEffectKey,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
              const SizedBox(height: 18),
            ],
            if (!_hasV2(enemy) &&
                (weaknessesV1.isNotEmpty || resistancesV1.isNotEmpty)) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (weaknessesV1.isNotEmpty) ...[
                    wrapDetailEffectsAnchor(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.weaknessesTitle,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: weaknessesV1
                                .map(
                                  (weakness) => Container(
                                    key: consumeTutorialEffectKey(weakness),
                                    child: InkWell(
                                      key: ValueKey(
                                        'effect-legacy-weakness-$weakness',
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                      onTap: () => _openEffectDetails(
                                        context,
                                        weakness,
                                        tutorialEffectId: tutorialEffectId,
                                      ),
                                      child: IconBadge.asset(
                                        assetName: UiMapper.effectIcon(
                                          weakness,
                                        ),
                                        size: 26,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    if (resistancesV1.isNotEmpty) const SizedBox(height: 16),
                  ],
                  if (resistancesV1.isNotEmpty) ...[
                    wrapDetailEffectsAnchor(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.resistancesTitle,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: resistancesV1
                                .map(
                                  (resistance) => Opacity(
                                    opacity: 0.75,
                                    child: Container(
                                      key: consumeTutorialEffectKey(resistance),
                                      child: InkWell(
                                        key: ValueKey(
                                          'effect-legacy-resistance-$resistance',
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        onTap: () => _openEffectDetails(
                                          context,
                                          resistance,
                                          tutorialEffectId: tutorialEffectId,
                                        ),
                                        child: IconBadge.asset(
                                          assetName: UiMapper.effectIcon(
                                            resistance,
                                          ),
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),
            ],
            if (effectiveInflictsEffects.isNotEmpty ||
                enemy.inflicts.isNotEmpty ||
                effectiveTraits.isNotEmpty) ...[
              _InflictsTraitsSection(
                inflictsEffects: effectiveInflictsEffects,
                inflicts: enemy.inflicts,
                traits: effectiveTraits,
                l10n: l10n,
                languageCode: languageCode,
              ),
              const SizedBox(height: 18),
            ],
            if (infusionRecommendations != null ||
                infusionCombatTips.isNotEmpty) ...[
              _BulletTextSection(
                title: l10n.infusionRecommendationsTitle,
                value: infusionRecommendations,
                items: infusionCombatTips,
              ),
              const SizedBox(height: 18),
            ],
            if (_hasLocalizedText(
                  enemy.lesserMutationsDescription,
                  languageCode,
                ) ||
                _hasVisibleLocalizedList(
                  enemy.lesserMutations,
                  languageCode,
                )) ...[
              _BulletTextSection(
                title: l10n.lesserMutationsTitle,
                value: _visibleText(
                  enemy.lesserMutationsDescription,
                  languageCode,
                ),
                items: _visibleLocalizedValues(
                  enemy.lesserMutations,
                  languageCode,
                ),
              ),
              const SizedBox(height: 18),
            ],
            if (enemy.resolvedWeakPoints.isNotEmpty) ...[
              Text(
                l10n.weakPointTitle,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < enemy.resolvedWeakPoints.length; i++) ...[
                _WeakPointCard(
                  info: enemy.resolvedWeakPoints[i],
                  tutorialEffectId: i == 0 ? tutorialEffectId : null,
                  tutorialEffectKeyBuilder: consumeTutorialEffectKey,
                ),
                if (i != enemy.resolvedWeakPoints.length - 1)
                  const SizedBox(height: 10),
              ],
              const SizedBox(height: 18),
            ],
            if (enemy.combatStats != null) ...[
              _CombatStatsSection(
                stats: enemy.combatStats!,
                fallbackHealth: effectiveHealth?.value,
                l10n: l10n,
                languageCode: languageCode,
              ),
              const SizedBox(height: 18),
            ],
            if (enemy.bossPhases.isNotEmpty) ...[
              _BossPhasesSection(
                enemy: enemy,
                l10n: l10n,
                languageCode: languageCode,
                selectedIndex: _selectedPhaseIndex.clamp(
                  0,
                  enemy.bossPhases.length - 1,
                ),
                onChanged: (index) =>
                    setState(() => _selectedPhaseIndex = index),
              ),
              const SizedBox(height: 18),
            ],
            if (_hasVisibleLocalizedList(enemy.environments, languageCode) ||
                _hasLocalizedText(enemy.respawnInfo, languageCode)) ...[
              _CollapsibleCardSection(
                title: l10n.environmentRespawnTitle,
                child: _EnvironmentRespawnSection(
                  enemy: enemy,
                  l10n: l10n,
                  languageCode: languageCode,
                  embedded: true,
                ),
              ),
              const SizedBox(height: 18),
            ],
            if (enemy.loot.isNotEmpty ||
                enemy.advancedLootTable.isNotEmpty ||
                enemy.lootTransformations.isNotEmpty) ...[
              _CollapsibleCardSection(
                title: l10n.lootTitle,
                child: _LootSection(
                  loot: enemy.loot,
                  advancedLoot: enemy.advancedLootTable,
                  transformations: enemy.lootTransformations,
                  l10n: l10n,
                  languageCode: languageCode,
                  embedded: true,
                ),
              ),
              const SizedBox(height: 18),
            ],
            if (enemy.rewardUnlocks.isNotEmpty) ...[
              _RewardUnlocksSection(
                rewards: enemy.rewardUnlocks,
                title: l10n.rewardsUnlocksTitle,
                languageCode: languageCode,
              ),
              const SizedBox(height: 18),
            ],
            if ((_hasCombatMoves(enemy) || effectiveAttacks.isNotEmpty) &&
                enemy.bossPhases.isEmpty) ...[
              _CollapsibleCardSection(
                title: enemy.abilities.isNotEmpty
                    ? l10n.abilitiesTitle
                    : l10n.attacksTitle,
                child: enemy.abilities.isNotEmpty
                    ? _AbilitiesSection(
                        abilities: enemy.abilities,
                        l10n: l10n,
                        languageCode: languageCode,
                        embedded: true,
                      )
                    : _AttackListSection(
                        attacks: effectiveAttacks,
                        embedded: true,
                      ),
              ),
              const SizedBox(height: 18),
            ],
            if (behavior != null) ...[
              _TextSection(title: l10n.behaviorTitle, value: behavior),
              const SizedBox(height: 18),
            ],
            if (interactionWithPlayer != null) ...[
              _TextSection(
                title: l10n.interactionWithPlayerTitle,
                value: interactionWithPlayer,
              ),
              const SizedBox(height: 18),
            ],
            if (interactionWithCreatures != null) ...[
              _TextSection(
                title: l10n.interactionWithCreaturesTitle,
                value: interactionWithCreatures,
              ),
              const SizedBox(height: 18),
            ],
            if (strategy != null) ...[
              _TextSection(title: l10n.strategyTitle, value: strategy),
              const SizedBox(height: 18),
            ],
            if (!_hasWikiContent(enemy)) ...[
              Text(
                l10n.upcomingTitle,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(l10n.upcomingItems),
            ],
            const SizedBox(height: 8),
            ValueListenableBuilder<bool>(
              valueListenable: MonetizationController.instance.adsRemoved,
              builder: (context, _, child) {
                if (!MonetizationController.instance.shouldShowAds) {
                  return const SizedBox.shrink();
                }
                return child!;
              },
              child: const InlineBannerAdCard(),
            ),
          ],
        ),
      ),
    );
  }
}

class _VariantSwitcher extends StatelessWidget {
  final String selectedGame;
  final ValueChanged<String> onChanged;

  const _VariantSwitcher({required this.selectedGame, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(value: 'g1', label: Text(l10n.groundedOne)),
        ButtonSegment(value: 'g2', label: Text(l10n.groundedTwo)),
      ],
      selected: {selectedGame},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _RelatedEntrySwitcher extends StatelessWidget {
  final List<EnemyIndexEntry> entries;
  final String selectedId;
  final ValueChanged<String> onChanged;

  const _RelatedEntrySwitcher({
    required this.entries,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in entries)
          ChoiceChip(
            key: ValueKey('related-entry-${entry.id}'),
            label: Text(entry.name),
            selected: entry.id == selectedId,
            onSelected: (_) => onChanged(entry.id),
          ),
      ],
    );
  }
}

class _EncounterVariantSwitcher extends StatelessWidget {
  final String baseName;
  final List<EncounterVariant> variants;
  final int selectedIndex;
  final String languageCode;
  final ValueChanged<int> onChanged;

  const _EncounterVariantSwitcher({
    required this.baseName,
    required this.variants,
    required this.selectedIndex,
    required this.languageCode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          key: const ValueKey('encounter-variant-base'),
          label: Text(baseName),
          selected: selectedIndex == 0,
          onSelected: (_) => onChanged(0),
        ),
        for (var index = 0; index < variants.length; index++)
          ChoiceChip(
            key: ValueKey('encounter-variant-${variants[index].id}'),
            label: Text(variants[index].name.resolve(languageCode)),
            selected: selectedIndex == index + 1,
            onSelected: (_) => onChanged(index + 1),
          ),
      ],
    );
  }
}

class _SummaryStatCard extends StatelessWidget {
  final Widget icon;
  final String label;
  final String value;

  const _SummaryStatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                OverflowMarqueeText(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailPhotoPanel extends StatelessWidget {
  final String photoAsset;
  final String title;
  final GamePick gamePick;

  const _DetailPhotoPanel({
    super.key,
    required this.photoAsset,
    required this.title,
    required this.gamePick,
  });

  @override
  Widget build(BuildContext context) {
    if (photoAsset.trim().isEmpty) {
      return AphidexStatePanel(
        gamePick: gamePick,
        icon: Icons.image_not_supported_outlined,
        title: context.l10n.noImageTitle,
        subtitle: context.l10n.noImageSubtitle,
        compact: true,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Image.asset(
          photoAsset,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return AphidexStatePanel(
              gamePick: gamePick,
              icon: Icons.image_not_supported_outlined,
              title: context.l10n.noImageTitle,
              subtitle: title,
              compact: true,
            );
          },
        ),
      ),
    );
  }
}

class _DetailSummarySidebar extends StatelessWidget {
  final Enemy enemy;
  final GoldController gold;
  final AppLocalizations l10n;
  final bool showCreatureCards;

  const _DetailSummarySidebar({
    required this.enemy,
    required this.gold,
    required this.l10n,
    required this.showCreatureCards,
  });

  @override
  Widget build(BuildContext context) {
    final isBuggy = enemy.collectionGroup == 'buggy';
    return Column(
      children: [
        Row(
          children: [
            if (!isBuggy)
              Expanded(
                child: _SummaryStatCard(
                  icon: IconBadge.asset(
                    assetName: UiMapper.dangerIcon(
                      enemy.isUnderConstruction ? 'proximamente' : enemy.danger,
                    ),
                    size: 24,
                    padding: const EdgeInsets.all(4),
                    borderRadius: 12,
                  ),
                  label: enemy.isUnderConstruction
                      ? l10n.underConstructionLabel
                      : l10n.filterDanger,
                  value: enemy.isUnderConstruction
                      ? l10n.underConstructionLabel
                      : l10n.dangerLevelLabel(
                          UiMapper.canonicalDangerLevel(enemy.danger),
                        ),
                ),
              ),
            if (!isBuggy) const SizedBox(width: 10),
            Expanded(
              child: _SummaryStatCard(
                icon: Image.asset(
                  UiMapper.tierIcon(
                    tier: enemy.tier,
                    isBoss: enemy.isBoss,
                    game: enemy.game,
                    cardTier: enemy.cardTier,
                    bossCardStyle: enemy.bossCardStyle,
                  ),
                  width: 28,
                  height: 28,
                ),
                label: l10n.tierTitle,
                value: formatTierSummaryLabel(
                  tier: enemy.tier,
                  isBoss: enemy.isBoss,
                  bossLabel: l10n.filterBoss,
                ),
              ),
            ),
          ],
        ),
        if (showCreatureCards && enemy.hasCreatureCard) ...[
          const SizedBox(height: 16),
          ValueListenableBuilder<CreatureCardProgressMap>(
            valueListenable: gold.progress,
            builder: (context, progressByKey, _) {
              return _CreatureCardSection(
                enemy: enemy,
                progress: resolveCreatureCardProgress(
                  enemy,
                  progressByKey,
                  legacyGoldIds: gold.gold.value,
                ),
                showViewer: true,
              );
            },
          ),
        ],
        if (!showCreatureCards && enemy.hasCreatureCard) ...[
          const SizedBox(height: 16),
          ValueListenableBuilder<CreatureCardProgressMap>(
            valueListenable: gold.progress,
            builder: (context, progressByKey, _) {
              return _CreatureCardSection(
                enemy: enemy,
                progress: resolveCreatureCardProgress(
                  enemy,
                  progressByKey,
                  legacyGoldIds: gold.gold.value,
                ),
                showViewer: false,
              );
            },
          ),
        ],
      ],
    );
  }
}

class _CreatureCardSection extends StatelessWidget {
  final Enemy enemy;
  final CreatureCardProgress progress;
  final bool showViewer;

  const _CreatureCardSection({
    required this.enemy,
    required this.progress,
    required this.showViewer,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canToggle = shouldTrackCreatureCardProgress(enemy);
    final current = normalizeCreatureCardProgress(enemy, progress);
    final next = nextCreatureCardProgress(enemy, current);
    final cardAsset =
        resolveCreatureCardAsset(enemy, current) ?? enemy.defaultCardAsset;
    final accentColor = switch (current) {
      CreatureCardProgress.gold => const Color(0xFFFFD54F),
      CreatureCardProgress.obtained => Theme.of(context).colorScheme.primary,
      CreatureCardProgress.unowned => Theme.of(context).colorScheme.outline,
    };

    return Column(
      key: showViewer ? const ValueKey('creature-card-section') : null,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          showViewer ? l10n.creatureCardTitle : l10n.creatureCardProgressTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        _CreatureCardProgressButton(
          enemy: enemy,
          current: current,
          next: next,
          canToggle: canToggle,
          accentColor: accentColor,
        ),
        if (showViewer && cardAsset != null && cardAsset.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          _CreatureCardViewer(
            assetName: cardAsset,
            progress: current,
            accentColor: accentColor,
          ),
        ],
      ],
    );
  }
}

class _CreatureCardProgressButton extends StatelessWidget {
  final Enemy enemy;
  final CreatureCardProgress current;
  final CreatureCardProgress next;
  final bool canToggle;
  final Color accentColor;

  const _CreatureCardProgressButton({
    required this.enemy,
    required this.current,
    required this.next,
    required this.canToggle,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final actionLabel =
        '${l10n.creatureCardProgressTitle}: '
        '${l10n.creatureCardProgressLabel(current)}. '
        '${l10n.creatureCardProgressLabel(next)}.';

    return Semantics(
      button: canToggle,
      label: actionLabel,
      child: InkWell(
        key: ValueKey('detail-card-progress-${enemy.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: canToggle
            ? () => GoldController.instance.setProgress(enemy, next)
            : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withValues(alpha: 0.7)),
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          ),
          child: Row(
            children: [
              _CreatureCardProgressIcon(progress: current, color: accentColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.creatureCardProgressLabel(current),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (canToggle)
                Icon(
                  Icons.sync_rounded,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreatureCardViewer extends StatelessWidget {
  final String assetName;
  final CreatureCardProgress progress;
  final Color accentColor;

  const _CreatureCardViewer({
    required this.assetName,
    required this.progress,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final locked = progress == CreatureCardProgress.unowned;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: progress == CreatureCardProgress.gold
              ? accentColor
              : colorScheme.outlineVariant,
          width: progress == CreatureCardProgress.gold ? 2 : 1,
        ),
        boxShadow: progress == CreatureCardProgress.gold
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.18),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : const [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          alignment: Alignment.center,
          children: [
            FallbackAssetImage.asset(
              key: ValueKey('creature-card-${progress.name}-$assetName'),
              assetName: assetName,
              fallbackAssetName: 'assets/global/Creaturecard_Proximamente.webp',
              fit: BoxFit.contain,
            ),
            if (locked)
              Positioned.fill(
                child: ColoredBox(
                  color: const Color(0xB8000000),
                  child: Center(
                    child: Icon(
                      Icons.lock_rounded,
                      size: 34,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CreatureCardProgressIcon extends StatelessWidget {
  final CreatureCardProgress progress;
  final Color color;

  const _CreatureCardProgressIcon({
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(switch (progress) {
      CreatureCardProgress.unowned => Icons.radio_button_unchecked_rounded,
      CreatureCardProgress.obtained => Icons.radio_button_checked_rounded,
      CreatureCardProgress.gold => Icons.workspace_premium_rounded,
    }, color: color);
  }
}

class _InfusionSwitcher extends StatelessWidget {
  final List<CreatureInfusion> infusions;
  final int selectedIndex;
  final String languageCode;
  final ValueChanged<int> onChanged;

  const _InfusionSwitcher({
    required this.infusions,
    required this.selectedIndex,
    required this.languageCode,
    required this.onChanged,
  });

  ({Color background, Color border, Color foreground}) _paletteFor(
    BuildContext context,
    String infusionId,
    bool selected,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final base = switch (infusionId) {
      'fresh' => const Color(0xFF4CC2FF),
      'sour' => const Color(0xFF4FB64D),
      'spicy' => const Color(0xFFD34D47),
      'salty' => const Color(0xFFD2B98C),
      _ => colorScheme.primary,
    };

    return (
      background: selected
          ? base.withValues(alpha: 0.18)
          : colorScheme.surfaceContainerHighest,
      border: selected ? base : colorScheme.outlineVariant,
      foreground: selected ? base : colorScheme.onSurface,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.infusionSelectorTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(infusions.length, (index) {
              final infusion = infusions[index];
              final selected = index == selectedIndex;
              final palette = _paletteFor(context, infusion.id, selected);
              return Padding(
                padding: EdgeInsets.only(
                  right: index == infusions.length - 1 ? 0 : 8,
                ),
                child: ChoiceChip(
                  showCheckmark: false,
                  avatar: infusion.iconAsset.isEmpty
                      ? null
                      : Image.asset(infusion.iconAsset, width: 18, height: 18),
                  label: Text(
                    infusion.name.resolve(languageCode),
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: palette.foreground,
                    ),
                  ),
                  selected: selected,
                  selectedColor: palette.background,
                  backgroundColor: palette.background,
                  side: BorderSide(
                    color: palette.border,
                    width: selected ? 1.5 : 1,
                  ),
                  onSelected: (_) => onChanged(index),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _KillCountSection extends StatelessWidget {
  const _KillCountSection({required this.enemyId});

  final String enemyId;

  @override
  Widget build(BuildContext context) {
    final controller = CreatureKillCountController.instance;
    final l10n = context.l10n;
    return ValueListenableBuilder<Map<String, int>>(
      valueListenable: controller.counts,
      builder: (context, _, _) {
        final count = controller.getCount(enemyId);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.ads_click_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.playerProfileKills,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        child: Text(
                          '$count',
                          key: ValueKey(count),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n.killCountEdit,
                  onPressed: () => _showKillCountEditor(context, enemyId),
                  icon: const Icon(Icons.edit_outlined),
                ),
                Semantics(
                  button: true,
                  label: l10n.killCountAdd,
                  child: FilledButton(
                    key: const ValueKey('increment-kill-count'),
                    onPressed: () => controller.increment(enemyId),
                    child: const Text('+1'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Future<void> _showKillCountEditor(BuildContext context, String enemyId) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _KillCountEditor(enemyId: enemyId),
  );
}

class _KillCountEditor extends StatefulWidget {
  const _KillCountEditor({required this.enemyId});

  final String enemyId;

  @override
  State<_KillCountEditor> createState() => _KillCountEditorState();
}

class _KillCountEditorState extends State<_KillCountEditor> {
  late final TextEditingController _textController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: CreatureKillCountController.instance
          .getCount(widget.enemyId)
          .toString(),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _set(int value) async {
    await CreatureKillCountController.instance.setCount(widget.enemyId, value);
    if (mounted) {
      setState(() {
        _textController.text = CreatureKillCountController.instance
            .getCount(widget.enemyId)
            .toString();
        _error = null;
      });
    }
  }

  Future<void> _save() async {
    final raw = _textController.text.replaceAll(' ', '');
    final value = int.tryParse(raw);
    if (value == null || value < 0) {
      setState(() => _error = '0-${CreatureKillCountController.maxCount}');
      return;
    }
    await _set(value);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = CreatureKillCountController.instance.getCount(
      widget.enemyId,
    );
    return AlertDialog(
      title: Text(l10n.killCountEdit),
      content: TextField(
        controller: _textController,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: l10n.killCountQuantity,
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(onPressed: () => _set(0), child: Text(l10n.killCountReset)),
        IconButton(
          onPressed: () => _set(current - 1),
          icon: const Icon(Icons.remove),
        ),
        IconButton(
          onPressed: () => _set(current + 1),
          icon: const Icon(Icons.add),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancelAction),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.saveAction)),
      ],
    );
  }
}

class _TextSection extends StatelessWidget {
  final String title;
  final String value;

  const _TextSection({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final visibleValue = value.trim();
    if (visibleValue.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black12),
          ),
          child: Text(visibleValue),
        ),
      ],
    );
  }
}

class _BulletTextSection extends StatelessWidget {
  final String title;
  final String? value;
  final List<String> items;

  const _BulletTextSection({
    required this.title,
    this.value,
    this.items = const [],
  });

  @override
  Widget build(BuildContext context) {
    final visibleValue = value?.trim();
    final hasValue = visibleValue != null && visibleValue.isNotEmpty;
    final visibleItems = items
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);

    if (!hasValue && visibleItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (hasValue) Text(visibleValue, style: const TextStyle(height: 1.45)),
        if (hasValue && visibleItems.isNotEmpty) const SizedBox(height: 10),
        if (visibleItems.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: visibleItems
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '\u2022 $item',
                      style: const TextStyle(height: 1.4),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _BossPhasesSection extends StatelessWidget {
  final Enemy enemy;
  final AppLocalizations l10n;
  final String languageCode;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _BossPhasesSection({
    required this.enemy,
    required this.l10n,
    required this.languageCode,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final phases = enemy.bossPhases;
    final phase = phases[selectedIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.bossPhasesTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(phases.length, (index) {
              final item = phases[index];
              return Padding(
                padding: EdgeInsets.only(
                  right: index == phases.length - 1 ? 0 : 8,
                ),
                child: ChoiceChip(
                  label: Text(item.label.resolve(languageCode)),
                  selected: index == selectedIndex,
                  onSelected: (_) => onChanged(index),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (phase.startsAtHealthPct != null) ...[
                Text(
                  '${l10n.phaseStartsAtLabel}: ${phase.startsAtHealthPct}%',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
              ],
              if (phase.trigger != null) ...[
                Text(
                  l10n.phaseTriggerLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(phase.trigger!.resolve(languageCode)),
                const SizedBox(height: 10),
              ],
              if (phase.summary != null) ...[
                Text(
                  l10n.phaseSummaryLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(phase.summary!.resolve(languageCode)),
                const SizedBox(height: 10),
              ],
              if (phase.aggressionChange != null) ...[
                Text(
                  l10n.phaseAggressionLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(phase.aggressionChange!.resolve(languageCode)),
                const SizedBox(height: 10),
              ],
              if (phase.newPatterns.isNotEmpty) ...[
                Text(
                  l10n.newPatternsTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                ...phase.newPatterns.map(
                  (pattern) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• ${pattern.resolve(languageCode)}'),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (phase.elementalWeaknesses.isNotEmpty) ...[
                Text(
                  l10n.elementalWeakness,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                _BonusWrap(bonuses: phase.elementalWeaknesses),
                const SizedBox(height: 10),
              ],
              if (phase.damageWeaknesses.isNotEmpty) ...[
                Text(
                  l10n.damageWeakness,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                _BonusWrap(bonuses: phase.damageWeaknesses),
                const SizedBox(height: 10),
              ],
              if (phase.resistancesV2.isNotEmpty) ...[
                Text(
                  l10n.resistancesTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                _BonusWrap(bonuses: phase.resistancesV2, dim: true),
                const SizedBox(height: 10),
              ],
              if (phase.inflictsEffects.isNotEmpty ||
                  phase.specialTraits.isNotEmpty) ...[
                _InflictsTraitsSection(
                  inflictsEffects: phase.inflictsEffects,
                  inflicts: const [],
                  traits: phase.specialTraits,
                  l10n: l10n,
                  languageCode: languageCode,
                ),
                const SizedBox(height: 10),
              ],
              if (phase.abilities.isNotEmpty) ...[
                _AbilitiesSection(
                  abilities: phase.abilities,
                  l10n: l10n,
                  languageCode: languageCode,
                  embedded: true,
                ),
              ] else if (phase.attacks.isNotEmpty) ...[
                _AttackListSection(attacks: phase.attacks, embedded: true),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RewardUnlocksSection extends StatelessWidget {
  final List<RewardUnlockInfo> rewards;
  final String title;
  final String languageCode;

  const _RewardUnlocksSection({
    required this.rewards,
    required this.title,
    required this.languageCode,
  });

  @override
  Widget build(BuildContext context) {
    if (rewards.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            children: rewards
                .map(
                  (reward) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconBadge.asset(
                          assetName: UiMapper.rewardIcon(reward.id),
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reward.name.resolve(languageCode),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (reward.detail != null) ...[
                                const SizedBox(height: 2),
                                Text(reward.detail!.resolve(languageCode)),
                              ],
                            ],
                          ),
                        ),
                        if (reward.amount != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              'x${reward.amount}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _EnvironmentRespawnSection extends StatelessWidget {
  final Enemy enemy;
  final AppLocalizations l10n;
  final String languageCode;
  final bool embedded;

  const _EnvironmentRespawnSection({
    required this.enemy,
    required this.l10n,
    required this.languageCode,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final environments = _visibleLocalizedValues(
      enemy.environments,
      languageCode,
    );
    final respawn = _visibleText(enemy.respawnInfo, languageCode);
    if (environments.isEmpty && respawn == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!embedded) ...[
          Text(
            l10n.environmentRespawnTitle,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (environments.isNotEmpty) ...[
                Text(
                  l10n.environmentsTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: environments
                      .map((environment) => Chip(label: Text(environment)))
                      .toList(),
                ),
              ],
              if (respawn != null) ...[
                if (environments.isNotEmpty) const SizedBox(height: 12),
                Text(
                  l10n.respawnTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(respawn),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CombatStatsSection extends StatelessWidget {
  final CombatStats stats;
  final int? fallbackHealth;
  final AppLocalizations l10n;
  final String languageCode;

  const _CombatStatsSection({
    required this.stats,
    required this.fallbackHealth,
    required this.l10n,
    required this.languageCode,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <MapEntry<String, String>>[];
    final healthValue = stats.health ?? fallbackHealth;
    if (healthValue != null) {
      rows.add(MapEntry(l10n.healthTitle, '$healthValue HP'));
    }
    if (stats.stunThreshold != null) {
      rows.add(MapEntry(l10n.stunThresholdLabel, '${stats.stunThreshold}'));
    }
    if (stats.stunCooldownSeconds != null) {
      rows.add(
        MapEntry(
          l10n.stunCooldownLabel,
          '${stats.stunCooldownSeconds} ${l10n.secondsShortLabel}',
        ),
      );
    }
    if (stats.attackDamageSummary != null) {
      final attackDamage = _visibleText(
        stats.attackDamageSummary,
        languageCode,
      );
      if (attackDamage != null) {
        rows.add(MapEntry(l10n.attackDamageLabel, attackDamage));
      }
    }
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.statsTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            children: rows
                .map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 132,
                          child: Text(
                            row.key,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(row.value)),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _LootSection extends StatelessWidget {
  final List<LootEntry> loot;
  final List<AdvancedLootEntry> advancedLoot;
  final List<LootTransformationInfo> transformations;
  final AppLocalizations l10n;
  final String languageCode;
  final bool embedded;

  const _LootSection({
    required this.loot,
    this.advancedLoot = const [],
    this.transformations = const [],
    required this.l10n,
    required this.languageCode,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<LootEntry>>{};
    for (final entry in loot) {
      grouped.putIfAbsent(entry.section, () => <LootEntry>[]).add(entry);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!embedded) ...[
          Text(
            l10n.lootTitle,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...grouped.entries.map(
                (section) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.lootSectionLabel(section.key),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      ...section.value.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(entry.item.resolve(languageCode)),
                              ),
                              const SizedBox(width: 12),
                              Text('${entry.minCount}-${entry.maxCount}'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (advancedLoot.isNotEmpty) ...[
                if (grouped.isNotEmpty) const SizedBox(height: 4),
                Text(
                  l10n.advancedLootTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ...advancedLoot.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(entry.item.resolve(languageCode)),
                            ),
                            const SizedBox(width: 8),
                            Text(entry.countLabel),
                            const SizedBox(width: 12),
                            Text('${entry.chancePct}%'),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: entry.chancePct.clamp(0, 100) / 100,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        if (entry.notes != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            entry.notes!.resolve(languageCode),
                            style: TextStyle(
                              color: Theme.of(context).hintColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              if (transformations.isNotEmpty) ...[
                if (grouped.isNotEmpty || advancedLoot.isNotEmpty)
                  const SizedBox(height: 8),
                Text(
                  l10n.lootTransformationsTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ...transformations.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (entry.effects.isNotEmpty) ...[
                          Wrap(
                            spacing: 4,
                            children: entry.effects
                                .map(
                                  (effectId) => IconBadge.asset(
                                    assetName: UiMapper.effectIcon(effectId),
                                    size: 22,
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Text(entry.description.resolve(languageCode)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InflictsTraitsSection extends StatelessWidget {
  final List<String> inflictsEffects;
  final List<LocalizedText> inflicts;
  final List<LocalizedText> traits;
  final AppLocalizations l10n;
  final String languageCode;

  const _InflictsTraitsSection({
    required this.inflictsEffects,
    required this.inflicts,
    required this.traits,
    required this.l10n,
    required this.languageCode,
  });

  @override
  Widget build(BuildContext context) {
    final values = [
      ...inflicts.map((item) => item.resolve(languageCode)),
      ...traits.map((item) => item.resolve(languageCode)),
    ].map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
    if (inflictsEffects.isEmpty && values.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.inflictsTraitsTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (inflictsEffects.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: inflictsEffects
                .map(
                  (effectId) => InkWell(
                    key: ValueKey('inflicts-effect-$effectId'),
                    borderRadius: BorderRadius.circular(999),
                    onTap: () =>
                        showEffectInfoSheet(context, effectId: effectId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconBadge.asset(
                            assetName: UiMapper.effectIcon(effectId),
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            effectCatalogEntryById(
                                  effectId,
                                )?.name.resolve(languageCode) ??
                                canonicalEffectId(effectId),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          if (values.isNotEmpty) const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values
              .map(
                (value) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Text(value),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _AbilitiesSection extends StatelessWidget {
  final List<AbilityInfo> abilities;
  final AppLocalizations l10n;
  final String languageCode;
  final bool embedded;

  const _AbilitiesSection({
    required this.abilities,
    required this.l10n,
    required this.languageCode,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!embedded) ...[
          Text(
            l10n.abilitiesTitle,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
        ],
        ...abilities.map(
          (ability) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ability.name.resolve(languageCode),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _AbilityFlagChip(
                      label: l10n.blockableLabel,
                      value: ability.blockable,
                      l10n: l10n,
                    ),
                    _AbilityFlagChip(
                      label: l10n.breaksGuardLabel,
                      value: ability.breaksGuard,
                      l10n: l10n,
                    ),
                    _AbilityFlagChip(
                      label: l10n.staggersLabel,
                      value: ability.staggers,
                      l10n: l10n,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(ability.description.resolve(languageCode)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AttackListSection extends StatelessWidget {
  final List<EnemyAttack> attacks;
  final bool embedded;

  const _AttackListSection({required this.attacks, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!embedded) ...[
          Text(
            context.l10n.attacksTitle,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
        ],
        ...attacks.map((attack) => _AttackTile(attack: attack)),
      ],
    );
  }
}

class _CollapsibleCardSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _CollapsibleCardSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: ExpansionTile(
        key: PageStorageKey('expand-$title'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        initiallyExpanded: false,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        children: [child],
      ),
    );
  }
}

class _AbilityFlagChip extends StatelessWidget {
  final String label;
  final bool? value;
  final AppLocalizations l10n;

  const _AbilityFlagChip({
    required this.label,
    required this.value,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black12),
      ),
      child: Text('$label: ${l10n.boolLabel(value)}'),
    );
  }
}

class _HealthBar extends StatelessWidget {
  final HealthInfo? health;
  final HealthDisplayMode displayMode;

  const _HealthBar({required this.health, required this.displayMode});

  Color _ratingColor(int rating) {
    switch (rating) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow;
      case 4:
        return Colors.purple;
      case 5:
        return Colors.deepPurple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentHealth = health;
    if (displayMode == HealthDisplayMode.invulnerable &&
        currentHealth == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.healthTitle,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black12),
            ),
            child: Text(
              context.l10n.notApplicableHealthLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );
    }

    if (currentHealth == null) {
      return const SizedBox.shrink();
    }

    final healthInfo = currentHealth;
    final rating = HealthInfo.visualRating(
      fallbackRating: healthInfo.rating,
      value: healthInfo.value,
    );
    final fillColor = _ratingColor(rating);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.healthTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (index) {
            final filled = index < rating;
            return Expanded(
              child: Container(
                height: 10,
                margin: EdgeInsets.only(right: index == 4 ? 0 : 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: filled ? fillColor : Colors.black12,
                ),
              ),
            );
          }),
        ),
        if (healthInfo.value != null) ...[
          const SizedBox(height: 6),
          Text(
            '${healthInfo.value} HP',
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
        ],
      ],
    );
  }
}

String formatBonusLabel(
  AppLocalizations l10n,
  BonusInfo bonus, {
  bool dim = false,
}) {
  if (dim && bonus.bonusPct == 100) {
    return l10n.immuneLabel;
  }

  final sign = dim ? '-' : '+';
  return '$sign${bonus.bonusPct}%';
}

class _BonusWrap extends StatelessWidget {
  final List<BonusInfo> bonuses;
  final bool dim;
  final String? tutorialEffectId;
  final GlobalKey? Function(String effectId)? tutorialEffectKeyBuilder;

  const _BonusWrap({
    required this.bonuses,
    this.dim = false,
    this.tutorialEffectId,
    this.tutorialEffectKeyBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: bonuses.map((bonus) {
        final icon = UiMapper.effectIcon(bonus.type);
        return Opacity(
          opacity: dim ? 0.75 : 1,
          child: Container(
            key: tutorialEffectId == null
                ? null
                : tutorialEffectKeyBuilder?.call(bonus.type),
            child: InkWell(
              key: ValueKey(
                'effect-bonus-${dim ? 'resistance' : 'weakness'}-${bonus.type}',
              ),
              borderRadius: BorderRadius.circular(999),
              onTap: () => _openTutorialAwareEffectDetails(
                context,
                bonus.type,
                tutorialEffectId: tutorialEffectId,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.black12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconBadge.asset(assetName: icon, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      formatBonusLabel(l10n, bonus, dim: dim),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _WeakPointCard extends StatelessWidget {
  final WeakPointInfo info;
  final String? tutorialEffectId;
  final GlobalKey? Function(String effectId)? tutorialEffectKeyBuilder;

  const _WeakPointCard({
    required this.info,
    this.tutorialEffectId,
    this.tutorialEffectKeyBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final partIcon = UiMapper.weakPointIcon(info.part);
    final damageIds = UiMapper.susceptibleDamageEffectIds(
      info.susceptibleDamage,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(partIcon, width: 28, height: 28),
              const SizedBox(width: 10),
              Text(
                l10n.weakPointPartLabel(info.part),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: damageIds
                    .map(
                      (effectId) => Container(
                        key: tutorialEffectId == null
                            ? null
                            : tutorialEffectKeyBuilder?.call(effectId),
                        child: InkWell(
                          key: ValueKey('weakpoint-effect-$effectId'),
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => _openTutorialAwareEffectDetails(
                            context,
                            effectId,
                            tutorialEffectId: tutorialEffectId,
                          ),
                          child: IconBadge.asset(
                            assetName: UiMapper.effectIcon(effectId),
                            size: 22,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.susceptibleDamageLabel(info.susceptibleDamage),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttackTile extends StatelessWidget {
  final EnemyAttack attack;

  const _AttackTile({required this.attack});

  String? _resolve(LocalizedText? text, String languageCode) {
    if (text == null) {
      return null;
    }
    final value = text.resolve(languageCode);
    return value.isEmpty ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final languageCode = l10n.languageCode;
    final tell = _resolve(attack.tell, languageCode);
    final howToAvoid = _resolve(attack.howToAvoid, languageCode);
    final notes = _resolve(attack.notes, languageCode);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: ExpansionTile(
        title: Text(
          attack.name.resolve(languageCode),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: attack.tags.isEmpty
            ? null
            : Text(attack.tags.map(l10n.attackTagLabel).join(' \u2022 ')),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          if (tell != null) _kv(l10n.attackTell, tell),
          if (howToAvoid != null) _kv(l10n.attackAvoid, howToAvoid),
          if (notes != null) _kv(l10n.attackNotes, notes),
        ],
      ),
    );
  }

  Widget _kv(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

String _variantPreferenceKey(String speciesKey) =>
    'species_variant:$speciesKey';
