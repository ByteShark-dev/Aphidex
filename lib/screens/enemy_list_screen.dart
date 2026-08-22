import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../controllers/favorites_controller.dart';
import '../controllers/creature_kill_count_controller.dart';
import '../controllers/game_selection_controller.dart';
import '../controllers/gold_controller.dart';
import '../controllers/monetization_controller.dart';
import '../controllers/review_prompt_controller.dart';
import '../controllers/tutorial_controller.dart';
import '../data/aphidex_view_state.dart';
import '../config/feature_flags.dart';
import '../data/creature_card_state.dart';
import '../data/creature_kill_tracking.dart';
import '../data/enemy_repository.dart';
import '../data/entity_asset_resolver.dart';
import '../data/enemy_variants.dart';
import '../data/local_storage.dart';
import '../data/ui_mapper.dart';
import '../i18n/app_localizations.dart';
import '../layout/app_breakpoints.dart';
import '../models/enemy_index_entry.dart';
import '../models/catalog_entry_kind.dart';
import '../models/game_pick.dart';
import '../startup/startup_profiler.dart';
import '../widgets/icon_badge.dart';
import '../widgets/fallback_asset_image.dart';
import '../widgets/game_brand_mark.dart';
import '../widgets/inline_banner_ad_card.dart';
import '../widgets/overflow_marquee_text.dart';
import '../widgets/state_panels.dart';
import '../scanner/creature_scanner_page.dart';
import '../scanner/creature_scanner_service.dart';
import 'enemy_detail_screen.dart';
import 'defense_detail_screen.dart';
import 'effect_codex_screen.dart';
import 'settings_screen.dart';
import 'player_profile_screen.dart';

enum SortMode { defaultOrder, name, danger, tier }

enum SortMenuAction { toggleDirection, defaultOrder, name, danger, tier }

enum EnemyDisplayGroup {
  neutral,
  buggy,
  orc,
  angry,
  harmless,
  ogrr,
  aggressive,
  peaceful,
  anomaly,
  other,
}

const int _flatInlineAdAfterTile = 16;
const int _minTilesForFlatInlineAd = 22;
const int _sectionInlineAdAfterTile = 6;
const int _minTilesForSectionInlineAd = 11;

Color gameColorForPick(GamePick value) {
  switch (value) {
    case GamePick.all:
      return const Color(0xFF3E5558);
    case GamePick.g1:
      return const Color(0xFF3E5A37);
    case GamePick.g2:
      return const Color(0xFF6A3638);
  }
}

Color gameAccentForPick(GamePick value) {
  switch (value) {
    case GamePick.all:
      return const Color(0xFF91A99B);
    case GamePick.g1:
      return const Color(0xFFCDA35A);
    case GamePick.g2:
      return const Color(0xFFD96B64);
  }
}

_GameHeaderGlowPalette _gameHeaderGlowPaletteForPick(GamePick value) {
  switch (value) {
    case GamePick.all:
      return const _GameHeaderGlowPalette(
        backdrop: Color(0xFF26383A),
        core: Color(0xFF9FB3A1),
        halo: Color(0xFF5B7D84),
        outer: Color(0xFF253234),
      );
    case GamePick.g1:
      return const _GameHeaderGlowPalette(
        backdrop: Color(0xFF243F2F),
        core: Color(0xFFD7A755),
        halo: Color(0xFF6B9D58),
        outer: Color(0xFF203526),
      );
    case GamePick.g2:
      return const _GameHeaderGlowPalette(
        backdrop: Color(0xFF3B2024),
        core: Color(0xFFE06A65),
        halo: Color(0xFF8F3C3F),
        outer: Color(0xFF2E1B20),
      );
  }
}

class _GameHeaderGlowPalette {
  final Color backdrop;
  final Color core;
  final Color halo;
  final Color outer;

  const _GameHeaderGlowPalette({
    required this.backdrop,
    required this.core,
    required this.halo,
    required this.outer,
  });
}

class _GameHeaderGlow extends StatelessWidget {
  final GamePick gamePick;

  const _GameHeaderGlow({required this.gamePick});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = _gameHeaderGlowPaletteForPick(gamePick);
    final contrastAlpha = isDark ? 0.54 : 0.68;
    final haloAlpha = isDark ? 0.30 : 0.36;
    final coreAlpha = isDark ? 0.34 : 0.42;

    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  palette.backdrop.withValues(alpha: contrastAlpha),
                  palette.outer.withValues(alpha: isDark ? 0.28 : 0.34),
                  palette.outer.withValues(alpha: 0),
                ],
                stops: const [0, 0.58, 1],
              ),
            ),
          ),
          Positioned(
            top: -150,
            left: -120,
            right: -120,
            height: 280,
            child: Transform.scale(
              scaleX: 1.35,
              scaleY: 0.82,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.12),
                    radius: 0.86,
                    colors: [
                      palette.core.withValues(alpha: coreAlpha),
                      palette.halo.withValues(alpha: haloAlpha),
                      palette.outer.withValues(alpha: 0.10),
                      palette.outer.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.34, 0.68, 1],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: -64,
            left: -56,
            right: -56,
            height: 170,
            child: Transform.scale(
              scaleX: 1.12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 0.92,
                    colors: [
                      palette.halo.withValues(alpha: isDark ? 0.16 : 0.22),
                      palette.core.withValues(alpha: isDark ? 0.12 : 0.16),
                      palette.core.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.5, 1],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EnemyListScreen extends StatefulWidget {
  final Future<List<EnemyIndexEntry>> Function(String languageCode)?
  enemiesLoaderOverride;
  final List<EnemyIndexEntry>? preloadedEntries;
  final String? preloadedLanguageCode;
  final GamePick? preloadedGamePick;
  final bool restorePhoneDetailOnStartup;
  final bool persistViewStateOnDispose;
  final VoidCallback? onInitialListInteractive;

  const EnemyListScreen({
    super.key,
    this.enemiesLoaderOverride,
    this.preloadedEntries,
    this.preloadedLanguageCode,
    this.preloadedGamePick,
    this.restorePhoneDetailOnStartup = true,
    this.persistViewStateOnDispose = true,
    this.onInitialListInteractive,
  });

  @override
  State<EnemyListScreen> createState() => _EnemyListScreenState();
}

class _EnemyListScreenState extends State<EnemyListScreen>
    with WidgetsBindingObserver {
  bool get _shouldPersistViewState =>
      widget.persistViewStateOnDispose && widget.enemiesLoaderOverride == null;

  SortMode sortMode = SortMode.defaultOrder;
  GamePick gamePick = GamePick.g1;
  bool sortDescending = false;
  String query = '';
  bool filterFavorites = false;
  bool filterGold = false;
  bool filterWithKills = false;
  bool filterWithoutKills = false;
  final Set<String> tierFilters = <String>{};
  final Set<String> classFilters = <String>{};
  final Set<String> dangerFilters = <String>{};

  late final TextEditingController _searchController;
  late final ScrollController _listScrollController;

  static const _kLegacyFilter = 'ui_filter';
  static const _kFilterFavorites = 'ui_filter_favorites';
  static const _kFilterGold = 'ui_filter_gold';
  static const _kFilterWithKills = 'ui_filter_with_kills';
  static const _kFilterWithoutKills = 'ui_filter_without_kills';
  static const _kTierFilters = 'ui_filter_tier_filters';
  static const _kClassFilters = 'ui_filter_class_filters';
  static const _kDangerFilters = 'ui_filter_danger_filters';
  static const _kSortMode = 'ui_sort_mode';
  static const _kDescending = 'ui_sort_desc';
  static const _kQuery = 'ui_query';

  late Future<List<EnemyIndexEntry>> enemiesFuture;
  String? _loadedLanguageCode;
  bool _tutorialQueued = false;
  String? _selectedSpeciesKey;
  AphidexViewState? _restoredViewState;
  bool _pendingPhoneDetailRestore = false;
  bool _phoneDetailRestoreConsumed = false;
  Future<void>? _progressHydrationFuture;
  bool _secondLoaderVisible = false;
  bool _listInteractiveLogged = false;
  bool _bootstrapEntriesConsumed = false;
  String? _deferredStartupSpeciesKey;
  String? _deferredStartupEnemyId;
  String? _deferredStartupDetailGame;
  bool _masterDetailRestoreQueued = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StartupProfiler.instance.markOnce('first frame');
    });

    final hasNewFilterState =
        LocalStorage.hasKey(_kFilterFavorites) ||
        LocalStorage.hasKey(_kFilterGold) ||
        LocalStorage.hasKey(_kFilterWithKills) ||
        LocalStorage.hasKey(_kFilterWithoutKills) ||
        LocalStorage.hasKey(_kTierFilters) ||
        LocalStorage.hasKey(_kClassFilters) ||
        LocalStorage.hasKey(_kDangerFilters);
    if (hasNewFilterState) {
      filterFavorites = LocalStorage.getBool(
        _kFilterFavorites,
        fallback: false,
      );
      filterGold = LocalStorage.getBool(_kFilterGold, fallback: false);
      filterWithKills = LocalStorage.getBool(
        _kFilterWithKills,
        fallback: false,
      );
      filterWithoutKills = LocalStorage.getBool(
        _kFilterWithoutKills,
        fallback: false,
      );
      tierFilters.addAll(LocalStorage.getStringSet(_kTierFilters));
      classFilters.addAll(LocalStorage.getStringSet(_kClassFilters));
      dangerFilters.addAll(
        LocalStorage.getStringSet(_kDangerFilters).map(_canonicalDanger),
      );
    } else {
      final legacyFilter = LocalStorage.getInt(_kLegacyFilter, fallback: 0);
      switch (legacyFilter) {
        case 1:
          filterFavorites = true;
          break;
        case 2:
          filterGold = true;
          break;
        case 3:
          tierFilters.add('1');
          break;
        case 4:
          tierFilters.add('2');
          break;
        case 5:
          tierFilters.add('3');
          break;
        case 6:
          tierFilters.add('4');
          break;
        case 7:
          tierFilters.add('boss');
          break;
      }
    }
    sortMode =
        SortMode.values[LocalStorage.getInt(
          _kSortMode,
          fallback: SortMode.defaultOrder.index,
        )];
    sortDescending = LocalStorage.getBool(_kDescending, fallback: false);
    gamePick = GameSelectionController.instance.gamePick.value;
    query = LocalStorage.getString(_kQuery) ?? '';

    final restored = AphidexViewState.fromStorageString(
      LocalStorage.getString(aphidexViewStateStorageKey),
    );
    if (restored != null) {
      _restoredViewState = restored;
      gamePick = GamePick
          .values[restored.gamePickIndex.clamp(0, GamePick.values.length - 1)];
      sortMode = SortMode
          .values[restored.sortModeIndex.clamp(0, SortMode.values.length - 1)];
      sortDescending = restored.sortDescending;
      query = restored.query;
      filterFavorites = restored.filterFavorites;
      filterGold = restored.filterGold;
      filterWithKills = restored.filterWithKills;
      filterWithoutKills = restored.filterWithoutKills;
      tierFilters
        ..clear()
        ..addAll(restored.tierFilters);
      classFilters
        ..clear()
        ..addAll(restored.classFilters);
      dangerFilters
        ..clear()
        ..addAll(restored.dangerFilters.map(_canonicalDanger));
      if (!widget.restorePhoneDetailOnStartup &&
          restored.selectedSpeciesKey != null) {
        _deferredStartupSpeciesKey = restored.selectedSpeciesKey;
        _deferredStartupEnemyId = restored.detailEnemyId;
        _deferredStartupDetailGame = restored.detailGame;
      } else {
        _selectedSpeciesKey = restored.selectedSpeciesKey;
      }
      _pendingPhoneDetailRestore =
          widget.restorePhoneDetailOnStartup &&
          restored.detailOpen &&
          (restored.detailEnemyId?.isNotEmpty ?? false);
    }
    GameSelectionController.instance.syncFromApp(gamePick);
    GameSelectionController.instance.gamePick.addListener(
      _onSharedGamePickChanged,
    );
    CreatureKillCountController.instance.counts.addListener(
      _onKillCountsChanged,
    );
    StartupProfiler.instance.mark(
      'restoring game/filters/search/selected creature ready',
    );

    _searchController = TextEditingController(text: query);
    _listScrollController = ScrollController(
      initialScrollOffset: restored?.listScrollOffset ?? 0,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final languageCode = context.l10n.languageCode;
    if (_loadedLanguageCode == languageCode) {
      return;
    }
    _loadedLanguageCode = languageCode;
    if (!_bootstrapEntriesConsumed &&
        widget.preloadedEntries != null &&
        widget.preloadedLanguageCode == languageCode &&
        widget.preloadedGamePick == gamePick) {
      _bootstrapEntriesConsumed = true;
      enemiesFuture = SynchronousFuture(widget.preloadedEntries!);
      return;
    }
    enemiesFuture =
        widget.enemiesLoaderOverride?.call(languageCode) ??
        _loadEnemiesForCurrentGame(languageCode);
  }

  @override
  void dispose() {
    GameSelectionController.instance.gamePick.removeListener(
      _onSharedGamePickChanged,
    );
    CreatureKillCountController.instance.counts.removeListener(
      _onKillCountsChanged,
    );
    WidgetsBinding.instance.removeObserver(this);
    if (_shouldPersistViewState) {
      unawaited(_persistViewState());
    }
    _listScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSharedGamePickChanged() {
    final next = GameSelectionController.instance.gamePick.value;
    if (!mounted || next == gamePick) {
      return;
    }
    setState(() {
      gamePick = next;
      enemiesFuture = _loadEnemiesForCurrentGame(
        _loadedLanguageCode ?? context.l10n.languageCode,
      );
    });
    _scheduleViewStatePersist();
  }

  void _onKillCountsChanged() {
    if (mounted && (filterWithKills || filterWithoutKills)) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_persistViewState());
    }
  }

  AphidexViewState _currentViewState({
    bool? detailOpen,
    String? detailEnemyId,
    String? detailGame,
    String? selectedSpeciesKey,
  }) {
    final restored = _restoredViewState;
    return AphidexViewState(
      gamePickIndex: gamePick.index,
      sortModeIndex: sortMode.index,
      sortDescending: sortDescending,
      query: query,
      filterFavorites: filterFavorites,
      filterGold: filterGold,
      filterWithKills: filterWithKills,
      filterWithoutKills: filterWithoutKills,
      tierFilters: {...tierFilters},
      classFilters: {...classFilters},
      dangerFilters: {...dangerFilters},
      selectedSpeciesKey: selectedSpeciesKey ?? _selectedSpeciesKey,
      detailEnemyId: detailEnemyId ?? restored?.detailEnemyId,
      detailGame: detailGame ?? restored?.detailGame,
      detailOpen: detailOpen ?? (restored?.detailOpen ?? false),
      listScrollOffset: _listScrollController.hasClients
          ? _listScrollController.offset
          : (restored?.listScrollOffset ?? 0),
    );
  }

  Future<void> _persistViewState({
    bool? detailOpen,
    String? detailEnemyId,
    String? detailGame,
    String? selectedSpeciesKey,
  }) async {
    final nextState = _currentViewState(
      detailOpen: detailOpen,
      detailEnemyId: detailEnemyId,
      detailGame: detailGame,
      selectedSpeciesKey: selectedSpeciesKey,
    );
    _restoredViewState = nextState;
    await LocalStorage.setString(
      aphidexViewStateStorageKey,
      nextState.toStorageString(),
    );
  }

  void _scheduleViewStatePersist({
    bool? detailOpen,
    String? detailEnemyId,
    String? detailGame,
    String? selectedSpeciesKey,
  }) {
    if (!_shouldPersistViewState) return;
    unawaited(
      _persistViewState(
        detailOpen: detailOpen,
        detailEnemyId: detailEnemyId,
        detailGame: detailGame,
        selectedSpeciesKey: selectedSpeciesKey,
      ),
    );
  }

  bool _ensureProgressHydration(List<EnemyIndexEntry> enemies) {
    final gold = GoldController.instance;
    if (!gold.needsMigration(enemies)) {
      _progressHydrationFuture = null;
      return false;
    }

    if (_progressHydrationFuture == null) {
      final completer = Completer<void>();
      _progressHydrationFuture = completer.future;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await gold.ensureMigrated(enemies);
          completer.complete();
        } catch (error, stackTrace) {
          completer.completeError(error, stackTrace);
        } finally {
          _progressHydrationFuture = null;
          if (mounted) setState(() {});
        }
      });
    }
    return true;
  }

  void _markLoaderHiddenIfNeeded() {
    if (_secondLoaderVisible) {
      _secondLoaderVisible = false;
      StartupProfiler.instance.markOnce('second loader disappears');
    }
  }

  void _markSecondLoaderVisibleIfNeeded() {
    if (_secondLoaderVisible) {
      return;
    }
    _secondLoaderVisible = true;
    StartupProfiler.instance.markOnce('second loader appears');
  }

  void _markListInteractiveIfNeeded() {
    if (_listInteractiveLogged) {
      return;
    }
    _listInteractiveLogged = true;
    StartupProfiler.instance.markOnce('list interactive');
    final callback = widget.onInitialListInteractive;
    if (callback != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        callback();
      });
    }
  }

  void _restoreMasterDetailSelectionIfNeeded(
    List<ResolvedEnemyEntry> filteredEntries,
    bool isMasterDetail,
  ) {
    if (!isMasterDetail ||
        !_listInteractiveLogged ||
        _masterDetailRestoreQueued ||
        _selectedSpeciesKey != null ||
        _deferredStartupSpeciesKey == null) {
      return;
    }

    final restoredKey = _deferredStartupSpeciesKey!;
    final restoredEntry = filteredEntries
        .cast<ResolvedEnemyEntry?>()
        .firstWhere(
          (entry) => entry?.entry.speciesKey == restoredKey,
          orElse: () => null,
        );
    if (restoredEntry == null) {
      return;
    }

    _masterDetailRestoreQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selectedSpeciesKey != null) {
        return;
      }
      setState(() {
        _selectedSpeciesKey = restoredEntry.entry.speciesKey;
      });
      _deferredStartupSpeciesKey = null;
      _scheduleViewStatePersist(
        detailOpen: false,
        detailEnemyId: _deferredStartupEnemyId ?? restoredEntry.activeEnemy.id,
        detailGame:
            _deferredStartupDetailGame ?? restoredEntry.activeEnemy.game,
        selectedSpeciesKey: restoredEntry.entry.speciesKey,
      );
      _deferredStartupEnemyId = null;
      _deferredStartupDetailGame = null;
    });
  }

  bool _isGold(EnemyIndexEntry enemy, CreatureCardProgressMap progressByKey) {
    return resolveCreatureCardProgress(enemy, progressByKey) ==
        CreatureCardProgress.gold;
  }

  int _displayOrder(EnemyIndexEntry enemy) => enemy.order ?? 999999;

  bool _matchesActiveFilters(
    EnemyIndexEntry enemy,
    Set<String> favoriteIds,
    CreatureCardProgressMap progressByKey,
    Set<String> effectiveTierFilters,
    Set<String> effectiveClassFilters,
    Set<String> effectiveDangerFilters,
  ) {
    if (filterFavorites && !favoriteIds.contains(enemy.resolvedFavoriteKey)) {
      return false;
    }
    if (filterGold && !_isGold(enemy, progressByKey)) {
      return false;
    }
    if ((filterWithKills || filterWithoutKills) &&
        !CreatureKillTracking.supportsIndex(enemy)) {
      return false;
    }
    final killCount = CreatureKillCountController.instance.getCount(enemy.id);
    if (filterWithKills && killCount == 0) {
      return false;
    }
    if (filterWithoutKills && killCount > 0) {
      return false;
    }
    if (effectiveTierFilters.isNotEmpty) {
      final tierKey = enemy.isBoss ? 'boss' : enemy.tier.toString();
      if (!effectiveTierFilters.contains(tierKey)) {
        return false;
      }
    }
    if (effectiveClassFilters.isNotEmpty) {
      if (!effectiveClassFilters.contains(_groupForEnemy(enemy).name)) {
        return false;
      }
    }
    if (effectiveDangerFilters.isNotEmpty &&
        !effectiveDangerFilters.contains(_canonicalDanger(enemy.danger))) {
      return false;
    }
    return true;
  }

  String _tierLabel(int tier) {
    switch (tier) {
      case 1:
        return 'I';
      case 2:
        return 'II';
      case 3:
        return 'III';
      case 4:
        return 'IV';
      case 5:
        return 'V';
      default:
        return tier.toString();
    }
  }

  _TierFilterOptions _tierFilterOptions(List<EnemyIndexEntry> enemies) {
    final tiers =
        enemies
            .where((enemy) => !enemy.isBoss)
            .map((enemy) => enemy.tier)
            .toSet()
            .toList()
          ..sort();
    final hasBoss = enemies.any((enemy) => enemy.isBoss);
    return _TierFilterOptions(tiers: tiers, hasBoss: hasBoss);
  }

  List<EnemyIndexEntry> _enemiesForCurrentGame(List<EnemyIndexEntry> enemies) {
    switch (gamePick) {
      case GamePick.g1:
        return enemies.where((enemy) => enemy.game == 'g1').toList();
      case GamePick.g2:
        return enemies.where((enemy) => enemy.game == 'g2').toList();
      case GamePick.all:
        return enemies;
    }
  }

  Future<List<EnemyIndexEntry>> _loadEnemiesForCurrentGame(
    String languageCode,
  ) {
    switch (gamePick) {
      case GamePick.g1:
        return EnemyRepository.loadGame('g1', languageCode);
      case GamePick.g2:
        return EnemyRepository.loadGame('g2', languageCode);
      case GamePick.all:
        return EnemyRepository.loadAll(languageCode);
    }
  }

  List<EnemyDisplayGroup> _availableClassGroups(List<EnemyIndexEntry> enemies) {
    final available = enemies.map(_groupForEnemy).toSet();
    return _groupOrder(
      false,
    ).where((group) => available.contains(group)).toList();
  }

  Set<String> _effectiveTierFilters(_TierFilterOptions options) {
    final available = {
      for (final tier in options.tiers) tier.toString(),
      if (options.hasBoss) 'boss',
    };
    return tierFilters.where(available.contains).toSet();
  }

  Set<String> _effectiveClassFilters(List<EnemyDisplayGroup> groups) {
    final available = groups.map((group) => group.name).toSet();
    return classFilters.where(available.contains).toSet();
  }

  Set<String> _effectiveDangerFilters(List<String> dangers) {
    final available = dangers.map(_canonicalDanger).toSet();
    return dangerFilters.where(available.contains).toSet();
  }

  void _syncScopedFilters({
    required Set<String> effectiveTierFilters,
    required Set<String> effectiveClassFilters,
    required Set<String> effectiveDangerFilters,
  }) {
    final tierChanged =
        tierFilters.length != effectiveTierFilters.length ||
        !tierFilters.containsAll(effectiveTierFilters);
    final classChanged =
        classFilters.length != effectiveClassFilters.length ||
        !classFilters.containsAll(effectiveClassFilters);
    final dangerChanged =
        dangerFilters.length != effectiveDangerFilters.length ||
        !dangerFilters.containsAll(effectiveDangerFilters);

    if (!tierChanged && !classChanged && !dangerChanged) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        tierFilters
          ..clear()
          ..addAll(effectiveTierFilters);
        classFilters
          ..clear()
          ..addAll(effectiveClassFilters);
        dangerFilters
          ..clear()
          ..addAll(effectiveDangerFilters);
      });
      unawaited(LocalStorage.setStringSet(_kTierFilters, tierFilters));
      unawaited(LocalStorage.setStringSet(_kClassFilters, classFilters));
      unawaited(LocalStorage.setStringSet(_kDangerFilters, dangerFilters));
      _scheduleViewStatePersist();
    });
  }

  EnemyDisplayGroup _fallbackGroupFromOrder(String game, int order) {
    if (game == 'g1') {
      if (order >= 101 && order <= 108) return EnemyDisplayGroup.neutral;
      if (order >= 109 && order <= 156) return EnemyDisplayGroup.aggressive;
      if (order >= 157 && order <= 171) return EnemyDisplayGroup.peaceful;
      if (order >= 172 && order <= 175) return EnemyDisplayGroup.anomaly;
    }
    return EnemyDisplayGroup.other;
  }

  EnemyDisplayGroup _groupForEnemy(EnemyIndexEntry enemy) {
    final explicitPeaceful = {
      'g1_red_ant_queen',
      'g1_black_ant_queen',
      'g1_fire_ant_queen',
    };
    final explicitAnomaly = {'g1_infected_ant_queen', 'g1_enemy_infused'};
    final explicitOther = {'g1_enemy_orc'};
    if (explicitPeaceful.contains(enemy.id) ||
        explicitPeaceful.contains(enemy.speciesKey)) {
      return EnemyDisplayGroup.peaceful;
    }
    if (explicitAnomaly.contains(enemy.id) ||
        explicitAnomaly.contains(enemy.speciesKey)) {
      return EnemyDisplayGroup.anomaly;
    }
    if (explicitOther.contains(enemy.id) ||
        explicitOther.contains(enemy.speciesKey)) {
      return EnemyDisplayGroup.other;
    }

    if (enemy.game == 'g2' && enemy.collectionGroup != null) {
      switch (enemy.collectionGroup) {
        case 'neutral':
          return EnemyDisplayGroup.neutral;
        case 'orc':
          return EnemyDisplayGroup.orc;
        case 'angry':
          return EnemyDisplayGroup.aggressive;
        case 'harmless':
          return EnemyDisplayGroup.peaceful;
        case 'ogrr':
          return EnemyDisplayGroup.ogrr;
        case 'buggy':
          return EnemyDisplayGroup.buggy;
        case 'other':
          return EnemyDisplayGroup.other;
      }
    }

    switch (enemy.temperament) {
      case 'neutral':
        return EnemyDisplayGroup.neutral;
      case 'aggressive':
        return EnemyDisplayGroup.aggressive;
      case 'peaceful':
        return EnemyDisplayGroup.peaceful;
      case 'anomaly':
        return EnemyDisplayGroup.anomaly;
      case 'other':
        return EnemyDisplayGroup.other;
      default:
        return _fallbackGroupFromOrder(enemy.game, enemy.order ?? 0);
    }
  }

  List<EnemyDisplayGroup> _groupOrder(bool descending) {
    if (descending) {
      return [
        EnemyDisplayGroup.other,
        EnemyDisplayGroup.anomaly,
        EnemyDisplayGroup.ogrr,
        EnemyDisplayGroup.peaceful,
        EnemyDisplayGroup.aggressive,
        EnemyDisplayGroup.orc,
        EnemyDisplayGroup.buggy,
        EnemyDisplayGroup.neutral,
      ];
    }
    return [
      EnemyDisplayGroup.neutral,
      EnemyDisplayGroup.buggy,
      EnemyDisplayGroup.orc,
      EnemyDisplayGroup.aggressive,
      EnemyDisplayGroup.peaceful,
      EnemyDisplayGroup.ogrr,
      EnemyDisplayGroup.anomaly,
      EnemyDisplayGroup.other,
    ];
  }

  String _groupLabel(EnemyDisplayGroup temperament, AppLocalizations l10n) {
    switch (temperament) {
      case EnemyDisplayGroup.neutral:
        return l10n.groupNeutrals;
      case EnemyDisplayGroup.orc:
        return l10n.groupOrc;
      case EnemyDisplayGroup.buggy:
        return l10n.groupBuggies;
      case EnemyDisplayGroup.angry:
        return l10n.groupAngry;
      case EnemyDisplayGroup.harmless:
        return l10n.groupHarmless;
      case EnemyDisplayGroup.ogrr:
        return l10n.groupOgrr;
      case EnemyDisplayGroup.aggressive:
        return l10n.groupAggressive;
      case EnemyDisplayGroup.peaceful:
        return l10n.groupPeaceful;
      case EnemyDisplayGroup.anomaly:
        return l10n.groupAnomalies;
      case EnemyDisplayGroup.other:
        return l10n.groupOthers;
    }
  }

  int _groupIndex(
    EnemyDisplayGroup temperament,
    List<EnemyDisplayGroup> order,
  ) => order.indexOf(temperament);

  int _dangerRank(String danger) {
    switch (_canonicalDanger(danger)) {
      case 'baja':
        return 1;
      case 'media':
        return 2;
      case 'intermedia':
        return 3;
      case 'alta':
        return 4;
      case 'muy_alta':
        return 5;
      case 'imposible':
        return 6;
      case 'imposible_superior':
        return 7;
      case 'extrema':
        return 8;
      case 'proximamente':
        return 9;
      default:
        return 99;
    }
  }

  List<String> _availableDangers(List<EnemyIndexEntry> enemies) {
    final values = enemies
        .map((enemy) => _canonicalDanger(enemy.danger))
        .toSet()
        .toList();
    values.sort((a, b) => _dangerRank(a).compareTo(_dangerRank(b)));
    return values;
  }

  String _dangerLabel(String danger, AppLocalizations l10n) =>
      l10n.dangerLevelLabel(_canonicalDanger(danger));

  String _canonicalDanger(String danger) =>
      UiMapper.canonicalDangerLevel(danger);

  int _activeFilterCount({
    required Set<String> effectiveTierFilters,
    required Set<String> effectiveClassFilters,
    required Set<String> effectiveDangerFilters,
  }) {
    return effectiveTierFilters.length +
        effectiveClassFilters.length +
        effectiveDangerFilters.length +
        (filterFavorites ? 1 : 0) +
        (filterGold ? 1 : 0) +
        (filterWithKills ? 1 : 0) +
        (filterWithoutKills ? 1 : 0);
  }

  bool _hasActiveFilters({
    required Set<String> effectiveTierFilters,
    required Set<String> effectiveClassFilters,
    required Set<String> effectiveDangerFilters,
  }) {
    return _activeFilterCount(
          effectiveTierFilters: effectiveTierFilters,
          effectiveClassFilters: effectiveClassFilters,
          effectiveDangerFilters: effectiveDangerFilters,
        ) >
        0;
  }

  void _clearAllFilters() {
    setState(() {
      filterFavorites = false;
      filterGold = false;
      filterWithKills = false;
      filterWithoutKills = false;
      tierFilters.clear();
      classFilters.clear();
      dangerFilters.clear();
    });
    unawaited(LocalStorage.setBool(_kFilterFavorites, false));
    unawaited(LocalStorage.setBool(_kFilterGold, false));
    unawaited(LocalStorage.setBool(_kFilterWithKills, false));
    unawaited(LocalStorage.setBool(_kFilterWithoutKills, false));
    unawaited(LocalStorage.setStringSet(_kTierFilters, tierFilters));
    unawaited(LocalStorage.setStringSet(_kClassFilters, classFilters));
    unawaited(LocalStorage.setStringSet(_kDangerFilters, dangerFilters));
    _scheduleViewStatePersist();
  }

  ResolvedEnemyEntry? _effectiveSelectedEntry(
    List<ResolvedEnemyEntry> entries,
  ) {
    if (entries.isEmpty) {
      return null;
    }
    if (_selectedSpeciesKey == null) {
      return entries.first;
    }
    for (final entry in entries) {
      if (entry.entry.speciesKey == _selectedSpeciesKey) {
        return entry;
      }
    }
    return entries.first;
  }

  ResolvedEnemyEntry? _resolvedEntryById(
    List<ResolvedEnemyEntry> entries,
    String enemyId,
  ) {
    for (final entry in entries) {
      for (final variant in entry.entry.variants) {
        if (variant.id == enemyId) {
          final preferred = entry.entry.variants.firstWhere(
            (item) => item.id == enemyId,
            orElse: () => entry.activeEnemy,
          );
          return ResolvedEnemyEntry(entry: entry.entry, activeEnemy: preferred);
        }
      }
    }
    return null;
  }

  void _restorePhoneDetailIfNeeded(
    BuildContext context,
    List<ResolvedEnemyEntry> filteredEntries,
    bool isMasterDetail,
  ) {
    if (isMasterDetail ||
        !_pendingPhoneDetailRestore ||
        _phoneDetailRestoreConsumed) {
      return;
    }

    final restored = _restoredViewState;
    final detailEnemyId = restored?.detailEnemyId;
    if (detailEnemyId == null || detailEnemyId.isEmpty) {
      _pendingPhoneDetailRestore = false;
      return;
    }

    final restoredEntry = _resolvedEntryById(filteredEntries, detailEnemyId);
    if (restoredEntry == null) {
      _pendingPhoneDetailRestore = false;
      _phoneDetailRestoreConsumed = true;
      _scheduleViewStatePersist(detailOpen: false);
      return;
    }

    _pendingPhoneDetailRestore = false;
    _phoneDetailRestoreConsumed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !context.mounted) {
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              restoredEntry.activeEnemy.entryKind == CatalogEntryKind.defense
              ? DefenseDetailScreen(defenseId: restoredEntry.activeEnemy.id)
              : EnemyDetailScreen(
                  summary: restoredEntry.activeEnemy,
                  variantSummaries: restoredEntry.entry.variants,
                  initialGame:
                      restored?.detailGame ?? restoredEntry.activeEnemy.game,
                ),
        ),
      );
      if (!mounted || !context.mounted) {
        return;
      }
      final consumedByAdsPrompt = await MonetizationController.instance
          .registerCreatureInspectionEvent(
            context,
            creatureId: restoredEntry.activeEnemy.id,
            countProgress: false,
          );
      if (context.mounted && !consumedByAdsPrompt) {
        await ReviewPromptController.instance.registerScreenClose(context);
      }
      _scheduleViewStatePersist(
        detailOpen: false,
        detailEnemyId: restoredEntry.activeEnemy.id,
        detailGame: restoredEntry.activeEnemy.game,
        selectedSpeciesKey: restoredEntry.entry.speciesKey,
      );
    });
  }

  Future<void> _openSecondaryFilters(
    BuildContext context, {
    required _TierFilterOptions tierOptions,
    required List<EnemyDisplayGroup> classOptions,
    required List<String> dangerOptions,
  }) async {
    final l10n = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> sync(void Function() updater) async {
              updater();
              setSheetState(() {});
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.filtersTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            _clearAllFilters();
                            setSheetState(() {});
                          },
                          icon: const Icon(Icons.filter_alt_off_rounded),
                          label: Text(l10n.clearFiltersAction),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.filterTiers,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final tier in tierOptions.tiers)
                          FilterChip(
                            label: Text(_tierLabel(tier)),
                            selected: tierFilters.contains(tier.toString()),
                            onSelected: (_) async {
                              await sync(() {
                                setState(() {
                                  if (!tierFilters.add(tier.toString())) {
                                    tierFilters.remove(tier.toString());
                                  }
                                });
                                unawaited(
                                  LocalStorage.setStringSet(
                                    _kTierFilters,
                                    tierFilters,
                                  ),
                                );
                                _scheduleViewStatePersist();
                              });
                            },
                          ),
                        if (tierOptions.hasBoss)
                          FilterChip(
                            label: Text(l10n.filterBoss),
                            selected: tierFilters.contains('boss'),
                            onSelected: (_) async {
                              await sync(() {
                                setState(() {
                                  if (!tierFilters.add('boss')) {
                                    tierFilters.remove('boss');
                                  }
                                });
                                unawaited(
                                  LocalStorage.setStringSet(
                                    _kTierFilters,
                                    tierFilters,
                                  ),
                                );
                                _scheduleViewStatePersist();
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.filterClass,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final group in classOptions)
                          FilterChip(
                            label: Text(_groupLabel(group, l10n)),
                            selected: classFilters.contains(group.name),
                            onSelected: (_) async {
                              await sync(() {
                                setState(() {
                                  if (!classFilters.add(group.name)) {
                                    classFilters.remove(group.name);
                                  }
                                });
                                unawaited(
                                  LocalStorage.setStringSet(
                                    _kClassFilters,
                                    classFilters,
                                  ),
                                );
                                _scheduleViewStatePersist();
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.filterDanger,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final danger in dangerOptions)
                          FilterChip(
                            label: Text(_dangerLabel(danger, l10n)),
                            selected: dangerFilters.contains(danger),
                            onSelected: (_) async {
                              await sync(() {
                                final canonical = _canonicalDanger(danger);
                                setState(() {
                                  if (!dangerFilters.add(canonical)) {
                                    dangerFilters.remove(canonical);
                                  }
                                });
                                unawaited(
                                  LocalStorage.setStringSet(
                                    _kDangerFilters,
                                    dangerFilters,
                                  ),
                                );
                                _scheduleViewStatePersist();
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.playerProfileKills,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: Text(l10n.filterWithKills),
                          selected: filterWithKills,
                          onSelected: (selected) async {
                            await sync(() {
                              setState(() {
                                filterWithKills = selected;
                                if (selected) filterWithoutKills = false;
                              });
                              unawaited(
                                LocalStorage.setBool(
                                  _kFilterWithKills,
                                  filterWithKills,
                                ),
                              );
                              unawaited(
                                LocalStorage.setBool(
                                  _kFilterWithoutKills,
                                  filterWithoutKills,
                                ),
                              );
                              _scheduleViewStatePersist();
                            });
                          },
                        ),
                        FilterChip(
                          label: Text(l10n.filterWithoutKills),
                          selected: filterWithoutKills,
                          onSelected: (selected) async {
                            await sync(() {
                              setState(() {
                                filterWithoutKills = selected;
                                if (selected) filterWithKills = false;
                              });
                              unawaited(
                                LocalStorage.setBool(
                                  _kFilterWithKills,
                                  filterWithKills,
                                ),
                              );
                              unawaited(
                                LocalStorage.setBool(
                                  _kFilterWithoutKills,
                                  filterWithoutKills,
                                ),
                              );
                              _scheduleViewStatePersist();
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String? _storedPreferredGame(String speciesKey) =>
      LocalStorage.getString(_variantPreferenceKey(speciesKey));

  EnemyIndexEntry _selectActiveVariant(
    EnemyIndexListEntry entry,
    List<EnemyIndexEntry> variants, {
    required bool preferG2Default,
  }) {
    final preferredGame = gamePick == GamePick.g1
        ? 'g1'
        : gamePick == GamePick.g2
        ? 'g2'
        : _storedPreferredGame(entry.speciesKey);

    for (final variant in variants) {
      if (variant.game == preferredGame) {
        return variant;
      }
    }

    final preferred = entry.preferredVariant(
      preferredGame: preferredGame,
      preferG2Default: preferG2Default,
    );
    if (variants.contains(preferred)) {
      return preferred;
    }

    if (preferG2Default) {
      for (final variant in variants) {
        if (variant.game == 'g2') {
          return variant;
        }
      }
    }

    return variants.first;
  }

  EnemyIndexEntry _sortSourceEnemy(ResolvedEnemyEntry entry) {
    if (gamePick == GamePick.all) {
      return entry.entry.sortVariant();
    }
    return entry.activeEnemy;
  }

  List<ResolvedEnemyEntry> _applyFilterAndSearch(
    List<EnemyIndexEntry> enemies,
    Set<String> favoriteIds,
    CreatureCardProgressMap progressByKey,
    Set<String> effectiveTierFilters,
    Set<String> effectiveClassFilters,
    Set<String> effectiveDangerFilters,
  ) {
    final mergeSharedSpecies = gamePick == GamePick.all;
    final entries = groupEnemyIndexEntries(
      enemies,
      mergeSharedSpecies: mergeSharedSpecies,
    );
    final normalizedQuery = query.trim().toLowerCase();
    final resolved = <ResolvedEnemyEntry>[];

    for (final entry in entries) {
      final visibleVariants = entry.variants.where((enemy) {
        if (gamePick == GamePick.g1) return enemy.game == 'g1';
        if (gamePick == GamePick.g2) return enemy.game == 'g2';
        return true;
      }).toList();

      if (visibleVariants.isEmpty) {
        continue;
      }

      if (normalizedQuery.isNotEmpty) {
        final matchesQuery = visibleVariants.any(
          (enemy) => enemy.name.toLowerCase().contains(normalizedQuery),
        );
        if (!matchesQuery) {
          continue;
        }
      }

      final matchingVariants = visibleVariants
          .where(
            (enemy) => _matchesActiveFilters(
              enemy,
              favoriteIds,
              progressByKey,
              effectiveTierFilters,
              effectiveClassFilters,
              effectiveDangerFilters,
            ),
          )
          .toList();
      if (matchingVariants.isEmpty) {
        continue;
      }

      final activeEnemy = _selectActiveVariant(
        entry,
        matchingVariants,
        preferG2Default: mergeSharedSpecies,
      );

      resolved.add(ResolvedEnemyEntry(entry: entry, activeEnemy: activeEnemy));
    }

    resolved.sort((a, b) {
      late final int result;

      switch (sortMode) {
        case SortMode.defaultOrder:
          final order = _groupOrder(sortDescending);
          final aSortEnemy = _sortSourceEnemy(a);
          final bSortEnemy = _sortSourceEnemy(b);
          final aGroup = _groupForEnemy(aSortEnemy);
          final bGroup = _groupForEnemy(bSortEnemy);
          final groupCompare = _groupIndex(
            aGroup,
            order,
          ).compareTo(_groupIndex(bGroup, order));
          if (groupCompare != 0) {
            result = groupCompare;
          } else {
            result = _displayOrder(
              aSortEnemy,
            ).compareTo(_displayOrder(bSortEnemy));
          }
          break;
        case SortMode.name:
          result = a.activeEnemy.name.toLowerCase().compareTo(
            b.activeEnemy.name.toLowerCase(),
          );
          break;
        case SortMode.danger:
          result = _dangerRank(
            a.activeEnemy.danger,
          ).compareTo(_dangerRank(b.activeEnemy.danger));
          break;
        case SortMode.tier:
          if (a.activeEnemy.isBoss != b.activeEnemy.isBoss) {
            result = a.activeEnemy.isBoss ? 1 : -1;
          } else {
            result = a.activeEnemy.tier.compareTo(b.activeEnemy.tier);
          }
          break;
      }

      if (sortMode == SortMode.defaultOrder) {
        return result;
      }
      return sortDescending ? -result : result;
    });

    return resolved;
  }

  void _refreshEnemies() {
    setState(() {
      enemiesFuture =
          widget.enemiesLoaderOverride?.call(_loadedLanguageCode ?? 'en') ??
          _loadEnemiesForCurrentGame(_loadedLanguageCode ?? 'en');
    });
  }

  Widget _buildLoadingState(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: AphidexLoadingPanel(
          gamePick: gamePick,
          title: l10n.loadingCreaturesTitle,
          subtitle: l10n.loadingCreaturesSubtitle,
        ),
      ),
    );
  }

  Widget _buildErrorState(AppLocalizations l10n, Object? error) {
    return _buildResponsiveStatePanel(
      gamePick: gamePick,
      icon: Icons.cloud_off_rounded,
      title: l10n.dataUnavailableTitle,
      subtitle: error == null ? l10n.dataUnavailableSubtitle : '$error',
      actions: [
        FilledButton.icon(
          onPressed: _refreshEnemies,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(l10n.retryAction),
        ),
      ],
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required AppLocalizations l10n,
    required bool hasActiveFilters,
  }) {
    final favoritesOnly =
        filterFavorites &&
        !filterGold &&
        tierFilters.isEmpty &&
        classFilters.isEmpty &&
        dangerFilters.isEmpty &&
        query.trim().isEmpty;
    final goldOnly =
        filterGold &&
        !filterFavorites &&
        tierFilters.isEmpty &&
        classFilters.isEmpty &&
        dangerFilters.isEmpty &&
        query.trim().isEmpty;
    late final String title;
    late final String subtitle;
    final actions = <Widget>[];

    if (query.trim().isNotEmpty) {
      title = l10n.emptySearchTitle;
      subtitle = l10n.emptySearchSubtitle;
    } else if (favoritesOnly) {
      title = l10n.emptyFavoritesTitle;
      subtitle = l10n.emptyFavoritesSubtitle;
    } else if (goldOnly) {
      title = l10n.emptyGoldTitle;
      subtitle = l10n.emptyGoldSubtitle;
    } else if (hasActiveFilters) {
      title = l10n.emptyFiltersTitle;
      subtitle = l10n.emptyFiltersSubtitle;
    } else {
      title = l10n.dataUnavailableTitle;
      subtitle = l10n.dataUnavailableSubtitle;
    }

    if (query.trim().isNotEmpty) {
      actions.add(
        OutlinedButton.icon(
          onPressed: () {
            setState(() => query = '');
            _searchController.clear();
            unawaited(LocalStorage.setString(_kQuery, ''));
            _scheduleViewStatePersist();
          },
          icon: const Icon(Icons.search_off_rounded),
          label: Text(l10n.clearSearchAction),
        ),
      );
    }

    if (hasActiveFilters) {
      actions.add(
        FilledButton.icon(
          onPressed: _clearAllFilters,
          icon: const Icon(Icons.filter_alt_off_rounded),
          label: Text(l10n.clearFiltersAction),
        ),
      );
    }

    return _buildResponsiveStatePanel(
      gamePick: gamePick,
      icon: Icons.search_off_rounded,
      title: title,
      subtitle: subtitle,
      actions: actions,
    );
  }

  Widget _buildResponsiveStatePanel({
    required GamePick gamePick,
    required IconData icon,
    required String title,
    required String subtitle,
    List<Widget> actions = const <Widget>[],
    Widget? body,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewInsets = MediaQuery.viewInsetsOf(context);
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + viewInsets.bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 40)
                  .clamp(0.0, double.infinity)
                  .toDouble(),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: AphidexStatePanel(
                  gamePick: gamePick,
                  icon: icon,
                  title: title,
                  subtitle: subtitle,
                  actions: actions,
                  body: body,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final favorites = FavoritesController.instance;
    final gold = GoldController.instance;
    final toolbarInset = AppBreakpoints.isTabletLike(MediaQuery.sizeOf(context))
        ? 20.0
        : 12.0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white, size: 26),
        actionsIconTheme: const IconThemeData(color: Colors.white, size: 26),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: _GameHeaderGlow(gamePick: gamePick),
        titleSpacing: 8,
        title: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(child: GameBrandMark(gamePick: gamePick, height: 32)),
          ),
        ),
        centerTitle: true,
        leadingWidth: 48 + toolbarInset,
        leading: Padding(
          padding: EdgeInsets.only(left: toolbarInset),
          child: Container(
            key: TutorialController.instance.keyFor(tutorialAnchorListProfile),
            child: const PlayerProfileToolbarButton(),
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: toolbarInset),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (scannerEnabled)
                  IconButton(
                    key: const ValueKey('open-creature-scanner'),
                    icon: const Icon(Icons.center_focus_strong),
                    tooltip: l10n.scannerTitle,
                    onPressed: () => _openScanner(context),
                  ),
                Container(
                  key: TutorialController.instance.keyFor(
                    tutorialAnchorListCodex,
                  ),
                  child: IconButton(
                    key: const ValueKey('open-effect-codex'),
                    icon: const Icon(Icons.menu_book),
                    tooltip: l10n.effectCodexTooltip,
                    onPressed: () => openEffectCodex(context),
                  ),
                ),
                Container(
                  key: TutorialController.instance.keyFor(
                    tutorialAnchorListGame,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.videogame_asset),
                    tooltip: l10n.chooseGameTooltip,
                    onPressed: () => _openGamePicker(context),
                  ),
                ),
                Container(
                  key: TutorialController.instance.keyFor(
                    tutorialAnchorListSettings,
                  ),
                  child: IconButton(
                    key: const ValueKey('open-settings'),
                    icon: const Icon(Icons.settings),
                    tooltip: l10n.settingsTooltip,
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                      if (context.mounted) {
                        await ReviewPromptController.instance
                            .registerScreenClose(context);
                      }
                    },
                  ),
                ),
                Container(
                  key: TutorialController.instance.keyFor(
                    tutorialAnchorListSort,
                  ),
                  child: PopupMenuButton<SortMenuAction>(
                    key: const ValueKey('open-sort-menu'),
                    icon: Icon(
                      sortDescending ? Icons.arrow_downward : Icons.sort,
                    ),
                    onSelected: (mode) {
                      switch (mode) {
                        case SortMenuAction.toggleDirection:
                          setState(() => sortDescending = !sortDescending);
                          LocalStorage.setBool(_kDescending, sortDescending);
                          _scheduleViewStatePersist();
                          break;
                        case SortMenuAction.defaultOrder:
                          setState(() => sortMode = SortMode.defaultOrder);
                          LocalStorage.setInt(
                            _kSortMode,
                            SortMode.defaultOrder.index,
                          );
                          _scheduleViewStatePersist();
                          break;
                        case SortMenuAction.name:
                          setState(() => sortMode = SortMode.name);
                          LocalStorage.setInt(_kSortMode, SortMode.name.index);
                          _scheduleViewStatePersist();
                          break;
                        case SortMenuAction.danger:
                          setState(() => sortMode = SortMode.danger);
                          LocalStorage.setInt(
                            _kSortMode,
                            SortMode.danger.index,
                          );
                          _scheduleViewStatePersist();
                          break;
                        case SortMenuAction.tier:
                          setState(() => sortMode = SortMode.tier);
                          LocalStorage.setInt(_kSortMode, SortMode.tier.index);
                          _scheduleViewStatePersist();
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: SortMenuAction.toggleDirection,
                        child: Row(
                          children: [
                            Icon(
                              sortDescending
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              sortDescending
                                  ? l10n.descendingOrder
                                  : l10n.ascendingOrder,
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      CheckedPopupMenuItem(
                        value: SortMenuAction.defaultOrder,
                        checked: sortMode == SortMode.defaultOrder,
                        child: Text(l10n.sortDefaultOrder),
                      ),
                      PopupMenuItem(
                        value: SortMenuAction.name,
                        child: Text(l10n.sortByName),
                      ),
                      PopupMenuItem(
                        value: SortMenuAction.danger,
                        child: Text(l10n.sortByDanger),
                      ),
                      PopupMenuItem(
                        value: SortMenuAction.tier,
                        child: Text(l10n.sortByTier),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: ValueListenableBuilder<CreatureCardProgressMap>(
          valueListenable: gold.progress,
          builder: (context, progressByKey, _) {
            return ValueListenableBuilder<Set<String>>(
              valueListenable: favorites.favorites,
              builder: (context, favoriteIds, _) {
                return FutureBuilder<List<EnemyIndexEntry>>(
                  future: enemiesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      _markSecondLoaderVisibleIfNeeded();
                      return _buildLoadingState(l10n);
                    }
                    if (snapshot.hasError) {
                      _markLoaderHiddenIfNeeded();
                      return _buildErrorState(l10n, snapshot.error);
                    }

                    final enemies = snapshot.data ?? <EnemyIndexEntry>[];
                    if (_ensureProgressHydration(enemies)) {
                      _markSecondLoaderVisibleIfNeeded();
                      return _buildLoadingState(l10n);
                    }
                    _markLoaderHiddenIfNeeded();
                    _markListInteractiveIfNeeded();
                    if (!_tutorialQueued) {
                      _tutorialQueued = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          TutorialController.instance.maybeStart(
                            context,
                            enemies,
                          );
                        }
                      });
                    }
                    final scopedEnemies = _enemiesForCurrentGame(enemies);
                    final tierOptions = _tierFilterOptions(scopedEnemies);
                    final classOptions = _availableClassGroups(scopedEnemies);
                    final dangerOptions = _availableDangers(scopedEnemies);
                    final effectiveTierFilters = _effectiveTierFilters(
                      tierOptions,
                    );
                    final effectiveClassFilters = _effectiveClassFilters(
                      classOptions,
                    );
                    final effectiveDangerFilters = _effectiveDangerFilters(
                      dangerOptions,
                    );

                    _syncScopedFilters(
                      effectiveTierFilters: effectiveTierFilters,
                      effectiveClassFilters: effectiveClassFilters,
                      effectiveDangerFilters: effectiveDangerFilters,
                    );

                    final filtered = _applyFilterAndSearch(
                      enemies,
                      favoriteIds,
                      progressByKey,
                      effectiveTierFilters,
                      effectiveClassFilters,
                      effectiveDangerFilters,
                    );

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final surface = AppBreakpoints.surfaceForWidth(
                          constraints.maxWidth,
                        );
                        final isMasterDetail = AppBreakpoints.isMasterDetail(
                          constraints.maxWidth,
                        );
                        TutorialController.instance.updateListLayout(
                          surface: surface,
                          isTabletLike: AppBreakpoints.isTabletLike(
                            constraints.biggest,
                          ),
                        );
                        final pagePadding = surface.pagePadding;
                        final activeFilterCount = _activeFilterCount(
                          effectiveTierFilters: effectiveTierFilters,
                          effectiveClassFilters: effectiveClassFilters,
                          effectiveDangerFilters: effectiveDangerFilters,
                        );
                        final hasActiveFilters = _hasActiveFilters(
                          effectiveTierFilters: effectiveTierFilters,
                          effectiveClassFilters: effectiveClassFilters,
                          effectiveDangerFilters: effectiveDangerFilters,
                        );
                        final selectedEntry = _effectiveSelectedEntry(filtered);
                        final selectedSpeciesKey = isMasterDetail
                            ? selectedEntry?.entry.speciesKey
                            : null;
                        _restorePhoneDetailIfNeeded(
                          context,
                          filtered,
                          isMasterDetail,
                        );
                        _restoreMasterDetailSelectionIfNeeded(
                          filtered,
                          isMasterDetail,
                        );

                        Future<void> handleEntryTap(
                          ResolvedEnemyEntry entry,
                        ) async {
                          if (isMasterDetail) {
                            final previousSpeciesKey = _selectedSpeciesKey;
                            if (previousSpeciesKey != null &&
                                previousSpeciesKey != entry.entry.speciesKey) {
                              final consumedByAdsPrompt =
                                  await MonetizationController.instance
                                      .registerCreatureInspectionEvent(
                                        context,
                                        creatureId:
                                            selectedEntry?.activeEnemy.id,
                                      );
                              if (context.mounted && !consumedByAdsPrompt) {
                                await ReviewPromptController.instance
                                    .registerScreenClose(context);
                              }
                            }
                            setState(
                              () =>
                                  _selectedSpeciesKey = entry.entry.speciesKey,
                            );
                            _scheduleViewStatePersist(
                              detailOpen: false,
                              detailEnemyId: entry.activeEnemy.id,
                              detailGame: entry.activeEnemy.game,
                              selectedSpeciesKey: entry.entry.speciesKey,
                            );
                            return;
                          }

                          _scheduleViewStatePersist(
                            detailOpen: true,
                            detailEnemyId: entry.activeEnemy.id,
                            detailGame: entry.activeEnemy.game,
                            selectedSpeciesKey: entry.entry.speciesKey,
                          );
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  entry.activeEnemy.entryKind ==
                                      CatalogEntryKind.defense
                                  ? DefenseDetailScreen(
                                      defenseId: entry.activeEnemy.id,
                                    )
                                  : EnemyDetailScreen(
                                      summary: entry.activeEnemy,
                                      variantSummaries: entry.entry.variants,
                                      initialGame: entry.activeEnemy.game,
                                    ),
                            ),
                          );
                          if (!context.mounted) {
                            return;
                          }
                          final consumedByAdsPrompt =
                              await MonetizationController.instance
                                  .registerCreatureInspectionEvent(
                                    context,
                                    creatureId: entry.activeEnemy.id,
                                  );
                          if (context.mounted && !consumedByAdsPrompt) {
                            await ReviewPromptController.instance
                                .registerScreenClose(context);
                          }
                          _scheduleViewStatePersist(
                            detailOpen: false,
                            detailEnemyId: entry.activeEnemy.id,
                            detailGame: entry.activeEnemy.game,
                            selectedSpeciesKey: entry.entry.speciesKey,
                          );
                        }

                        final controls = Padding(
                          padding: EdgeInsets.fromLTRB(
                            pagePadding.left,
                            8,
                            pagePadding.right,
                            0,
                          ),
                          child: Column(
                            children: [
                              Padding(
                                key: TutorialController.instance.keyFor(
                                  tutorialAnchorListSearch,
                                ),
                                padding: const EdgeInsets.only(bottom: 10),
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (value) {
                                    setState(() => query = value);
                                    if (_shouldPersistViewState) {
                                      unawaited(
                                        LocalStorage.setString(_kQuery, value),
                                      );
                                    }
                                    _scheduleViewStatePersist();
                                  },
                                  decoration: InputDecoration(
                                    hintText: l10n.searchEnemyHint,
                                    prefixIcon: const Icon(Icons.search),
                                    suffixIcon: query.isEmpty
                                        ? null
                                        : IconButton(
                                            icon: const Icon(Icons.close),
                                            onPressed: () {
                                              setState(() => query = '');
                                              _searchController.clear();
                                              if (_shouldPersistViewState) {
                                                unawaited(
                                                  LocalStorage.setString(
                                                    _kQuery,
                                                    '',
                                                  ),
                                                );
                                              }
                                              _scheduleViewStatePersist();
                                            },
                                          ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                key: TutorialController.instance.keyFor(
                                  tutorialAnchorListFilters,
                                ),
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _ToolbarToggleButton(
                                        key: const ValueKey(
                                          'favorites-filter-chip',
                                        ),
                                        icon: Icons.star_rounded,
                                        label: l10n.favoritesFilterLabel,
                                        selected: filterFavorites,
                                        onTap: () {
                                          setState(
                                            () => filterFavorites =
                                                !filterFavorites,
                                          );
                                          if (_shouldPersistViewState) {
                                            unawaited(
                                              LocalStorage.setBool(
                                                _kFilterFavorites,
                                                filterFavorites,
                                              ),
                                            );
                                          }
                                          _scheduleViewStatePersist();
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _ToolbarToggleButton(
                                        key: const ValueKey('gold-filter-chip'),
                                        icon: Icons.workspace_premium_rounded,
                                        label: l10n.goldFilterLabel,
                                        selected: filterGold,
                                        onTap: () {
                                          setState(
                                            () => filterGold = !filterGold,
                                          );
                                          if (_shouldPersistViewState) {
                                            unawaited(
                                              LocalStorage.setBool(
                                                _kFilterGold,
                                                filterGold,
                                              ),
                                            );
                                          }
                                          _scheduleViewStatePersist();
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _ToolbarActionButton(
                                        key: const ValueKey(
                                          'open-secondary-filters',
                                        ),
                                        icon: Icons.filter_alt_rounded,
                                        label: l10n.filtersTitle,
                                        badgeCount: activeFilterCount,
                                        active: hasActiveFilters,
                                        onTap: () => _openSecondaryFilters(
                                          context,
                                          tierOptions: tierOptions,
                                          classOptions: classOptions,
                                          dangerOptions: dangerOptions,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );

                        return ListenableBuilder(
                          listenable:
                              MonetizationController.instance.adsRemoved,
                          builder: (context, _) {
                            final showInlineAd =
                                MonetizationController.instance.shouldShowAds;
                            final listView = sortMode == SortMode.defaultOrder
                                ? _SectionedEnemyList(
                                    entries: filtered,
                                    favIds: favoriteIds,
                                    cardProgressByKey: progressByKey,
                                    groupOrder: _groupOrder(sortDescending),
                                    showInlineAd: showInlineAd,
                                    controller: _listScrollController,
                                    selectedSpeciesKey: selectedSpeciesKey,
                                    onSelectEntry: handleEntryTap,
                                    onToggleFavorite: (entry) {
                                      unawaited(
                                        FavoritesController.instance.toggle(
                                          entry.activeEnemy.resolvedFavoriteKey,
                                        ),
                                      );
                                    },
                                    onToggleCardProgress: (entry) {
                                      unawaited(
                                        GoldController.instance.cycle(
                                          entry.activeEnemy,
                                        ),
                                      );
                                    },
                                    groupFromEntry: (entry) {
                                      return _groupForEnemy(
                                        _sortSourceEnemy(entry),
                                      );
                                    },
                                    groupLabel: (temperament) =>
                                        _groupLabel(temperament, l10n),
                                  )
                                : _FlatEnemyList(
                                    entries: filtered,
                                    favIds: favoriteIds,
                                    cardProgressByKey: progressByKey,
                                    showInlineAd: showInlineAd,
                                    controller: _listScrollController,
                                    selectedSpeciesKey: selectedSpeciesKey,
                                    onSelectEntry: handleEntryTap,
                                    onToggleFavorite: (entry) {
                                      unawaited(
                                        FavoritesController.instance.toggle(
                                          entry.activeEnemy.resolvedFavoriteKey,
                                        ),
                                      );
                                    },
                                    onToggleCardProgress: (entry) {
                                      unawaited(
                                        GoldController.instance.cycle(
                                          entry.activeEnemy,
                                        ),
                                      );
                                    },
                                  );

                            final leftPaneBody = filtered.isEmpty
                                ? _buildEmptyState(
                                    context,
                                    l10n: l10n,
                                    hasActiveFilters: hasActiveFilters,
                                  )
                                : listView;

                            if (!isMasterDetail) {
                              return Column(
                                children: [
                                  controls,
                                  const SizedBox(height: 6),
                                  Expanded(child: leftPaneBody),
                                ],
                              );
                            }

                            final detailEntry = selectedEntry;

                            return Row(
                              children: [
                                SizedBox(
                                  width: (constraints.maxWidth * 0.36)
                                      .clamp(360.0, 440.0)
                                      .toDouble(),
                                  child: Column(
                                    children: [
                                      controls,
                                      const SizedBox(height: 6),
                                      Expanded(child: leftPaneBody),
                                    ],
                                  ),
                                ),
                                VerticalDivider(
                                  width: 1,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      12,
                                      12,
                                      pagePadding.right,
                                      12,
                                    ),
                                    child: ListenableBuilder(
                                      listenable: TutorialController.instance,
                                      builder: (context, _) {
                                        final tutorial =
                                            TutorialController.instance;
                                        final tutorialEnemy =
                                            tutorial.inlineDetailEnemy;
                                        final detailSummary =
                                            tutorialEnemy ??
                                            detailEntry?.activeEnemy;
                                        final detailVariants =
                                            tutorialEnemy == null
                                            ? detailEntry?.entry.variants
                                            : tutorial.inlineDetailVariants;
                                        if (detailSummary == null ||
                                            detailVariants == null) {
                                          return AphidexStatePanel(
                                            gamePick: gamePick,
                                            icon: Icons.touch_app_rounded,
                                            title: l10n
                                                .masterDetailPlaceholderTitle,
                                            subtitle: l10n
                                                .masterDetailPlaceholderSubtitle,
                                            compact: surface.isWide,
                                          );
                                        }

                                        return ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            22,
                                          ),
                                          child: Material(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.surface,
                                            child:
                                                detailSummary.entryKind ==
                                                    CatalogEntryKind.defense
                                                ? DefenseDetailScreen(
                                                    key: ValueKey(
                                                      'defense:${detailSummary.id}',
                                                    ),
                                                    defenseId: detailSummary.id,
                                                    embedded: true,
                                                  )
                                                : EnemyDetailScreen(
                                                    key: ValueKey(
                                                      'detail:${detailSummary.id}:${tutorialEnemy != null}',
                                                    ),
                                                    summary: detailSummary,
                                                    variantSummaries:
                                                        detailVariants,
                                                    initialGame:
                                                        detailSummary.game,
                                                    tutorialTargetScope:
                                                        TutorialTargetScope
                                                            .inlineDetail,
                                                  ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _openGamePicker(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      useSafeArea: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _GamePickerSheet(
        selected: gamePick,
        onPick: (pick) {
          unawaited(GameSelectionController.instance.select(pick));
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _openScanner(BuildContext context) async {
    if (!scannerEnabled) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const CreatureScannerComingSoonPage(),
        ),
      );
      return;
    }

    List<EnemyIndexEntry> enemies;
    try {
      enemies = await enemiesFuture;
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.l10n.errorLoadingJson}\n$error')),
      );
      return;
    }

    if (!context.mounted) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatureScannerPage(
          enemies: enemies,
          selectedGameScope: _scannerScopeForGamePick(gamePick),
        ),
      ),
    );
  }
}

String _scannerScopeForGamePick(GamePick pick) {
  return switch (pick) {
    GamePick.g1 => scannerGameScopeG1,
    GamePick.g2 => scannerGameScopeG2,
    GamePick.all => scannerGameScopeAll,
  };
}

class _FlatEnemyList extends StatelessWidget {
  final List<ResolvedEnemyEntry> entries;
  final Set<String> favIds;
  final CreatureCardProgressMap cardProgressByKey;
  final bool showInlineAd;
  final ScrollController controller;
  final String? selectedSpeciesKey;
  final ValueChanged<ResolvedEnemyEntry> onSelectEntry;
  final ValueChanged<ResolvedEnemyEntry> onToggleFavorite;
  final ValueChanged<ResolvedEnemyEntry> onToggleCardProgress;

  const _FlatEnemyList({
    required this.entries,
    required this.favIds,
    required this.cardProgressByKey,
    required this.showInlineAd,
    required this.controller,
    required this.selectedSpeciesKey,
    required this.onSelectEntry,
    required this.onToggleFavorite,
    required this.onToggleCardProgress,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <ResolvedEnemyEntry?>[];
    for (var i = 0; i < entries.length; i++) {
      rows.add(entries[i]);
      if (showInlineAd &&
          entries.length >= _minTilesForFlatInlineAd &&
          i + 1 == _flatInlineAdAfterTile) {
        rows.add(null);
      }
    }

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.only(bottom: 4),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final entry = rows[index];
        if (entry == null) {
          return const InlineBannerAdCard();
        }
        return EnemyTile(
          entry: entry,
          favIds: favIds,
          cardProgressByKey: cardProgressByKey,
          selected: entry.entry.speciesKey == selectedSpeciesKey,
          onTap: () => onSelectEntry(entry),
          onToggleFavorite: () => onToggleFavorite(entry),
          onToggleCardProgress: () => onToggleCardProgress(entry),
        );
      },
    );
  }
}

class _ToolbarToggleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToolbarToggleButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = selected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    return SizedBox(
      height: 42,
      child: Material(
        color: selected
            ? colorScheme.primary.withValues(alpha: 0.12)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? colorScheme.primary : colorScheme.outline,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: foreground,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int badgeCount;
  final bool active;
  final VoidCallback onTap;

  const _ToolbarActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.badgeCount,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 42,
      child: Material(
        color: active
            ? colorScheme.primary.withValues(alpha: 0.12)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active ? colorScheme.primary : colorScheme.outline,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: active
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: active
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (badgeCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$badgeCount',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EnemyTile extends StatelessWidget {
  final ResolvedEnemyEntry entry;
  final Set<String> favIds;
  final CreatureCardProgressMap cardProgressByKey;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onToggleCardProgress;

  const EnemyTile({
    super.key,
    required this.entry,
    required this.favIds,
    required this.cardProgressByKey,
    required this.selected,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onToggleCardProgress,
  });

  @override
  Widget build(BuildContext context) {
    final enemy = entry.activeEnemy;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isPhonePortraitList =
        !AppBreakpoints.isMasterDetail(screenWidth) &&
        MediaQuery.orientationOf(context) == Orientation.portrait;
    final isFavorite = favIds.contains(enemy.resolvedFavoriteKey);
    final cardProgress = resolveCreatureCardProgress(enemy, cardProgressByKey);
    final nextCardProgress = nextCreatureCardProgress(enemy, cardProgress);
    final tracksCardProgress = shouldTrackCreatureCardProgress(enemy);
    final thumbnail = _resolveThumbnailAsset(enemy, cardProgress);
    final thumbnailAsset = thumbnail.asset;
    final usesIconThumbnail = thumbnail.source == 'entity_thumbnail';
    final weaknessChips = enemy.weaknesses
        .map(
          (weakness) => IconBadge.asset(
            assetName: UiMapper.effectIcon(weakness),
            size: 16,
            padding: const EdgeInsets.all(3),
            borderRadius: 10,
          ),
        )
        .toList(growable: false);
    final hasWeaknessChips = weaknessChips.isNotEmpty;

    final cardColor = selected
        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
        : null;
    final borderColor = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.outlineVariant;

    return Card(
      key: ValueKey('enemy-tile-card-${entry.entry.speciesKey}'),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: borderColor),
      ),
      child: InkWell(
        key: ValueKey('enemy-tile-${entry.entry.speciesKey}'),
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          height: 92,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                _EnemyTileThumbnail(
                  assetName: thumbnailAsset,
                  isIconThumbnail: usesIconThumbnail,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: hasWeaknessChips
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRect(
                        child: OverflowMarqueeText(
                          enemy.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isPhonePortraitList ? 18 : null,
                          ),
                        ),
                      ),
                      if (hasWeaknessChips) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: weaknessChips,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _EnemyTileActionColumn(
                  enemyId: enemy.id,
                  isFavorite: isFavorite,
                  progress: cardProgress,
                  nextProgress: nextCardProgress,
                  showProgress: tracksCardProgress,
                  onToggleFavorite: onToggleFavorite,
                  onToggleCardProgress: onToggleCardProgress,
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 34,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (enemy.collectionGroup != 'buggy')
                        IconBadge.asset(
                          assetName: UiMapper.dangerIcon(
                            enemy.isUnderConstruction
                                ? 'proximamente'
                                : enemy.danger,
                          ),
                          size: 22,
                          padding: const EdgeInsets.all(4),
                          borderRadius: 12,
                        ),
                      const SizedBox(height: 6),
                      Image.asset(
                        UiMapper.tierIcon(
                          tier: enemy.tier,
                          isBoss: enemy.isBoss,
                          game: enemy.game,
                          cardTier: enemy.cardTier,
                          bossCardStyle: enemy.bossCardStyle,
                        ),
                        width: 26,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  EntityAssetResolution _resolveThumbnailAsset(
    EnemyIndexEntry enemy,
    CreatureCardProgress progress,
  ) {
    return EntityAssetResolver.resolveEnemyIndex(
      enemy,
      enemy.entryKind != CatalogEntryKind.creature
          ? EntityAssetUsage.customEntry
          : EntityAssetUsage.card,
      selectedCardAsset: resolveCreatureCardAsset(enemy, progress),
    );
  }
}

class _EnemyTileActionColumn extends StatelessWidget {
  final String enemyId;
  final bool isFavorite;
  final CreatureCardProgress progress;
  final CreatureCardProgress nextProgress;
  final bool showProgress;
  final VoidCallback onToggleFavorite;
  final VoidCallback onToggleCardProgress;

  const _EnemyTileActionColumn({
    required this.enemyId,
    required this.isFavorite,
    required this.progress,
    required this.nextProgress,
    required this.showProgress,
    required this.onToggleFavorite,
    required this.onToggleCardProgress,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _EnemyTileFavoriteButton(
            enemyId: enemyId,
            isFavorite: isFavorite,
            onTap: onToggleFavorite,
          ),
          if (showProgress) ...[
            const SizedBox(height: 8),
            _EnemyTileProgressButton(
              enemyId: enemyId,
              progress: progress,
              nextProgress: nextProgress,
              onTap: onToggleCardProgress,
            ),
          ],
        ],
      ),
    );
  }
}

class _EnemyTileFavoriteButton extends StatelessWidget {
  final String enemyId;
  final bool isFavorite;
  final VoidCallback onTap;

  const _EnemyTileFavoriteButton({
    required this.enemyId,
    required this.isFavorite,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      key: ValueKey('favorite-toggle-$enemyId'),
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: SizedBox(
        width: 28,
        height: 28,
        child: Center(
          child: Icon(
            isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 20,
            color: isFavorite ? Colors.amber : colorScheme.outline,
          ),
        ),
      ),
    );
  }
}

class _EnemyTileProgressButton extends StatelessWidget {
  final String enemyId;
  final CreatureCardProgress progress;
  final CreatureCardProgress nextProgress;
  final VoidCallback onTap;

  const _EnemyTileProgressButton({
    required this.enemyId,
    required this.progress,
    required this.nextProgress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final color = switch (progress) {
      CreatureCardProgress.gold => const Color(0xFFFFD54F),
      CreatureCardProgress.obtained => colorScheme.primary,
      CreatureCardProgress.unowned => colorScheme.outline,
    };

    return Semantics(
      button: true,
      label:
          '${l10n.creatureCardProgressTitle}: '
          '${l10n.creatureCardProgressLabel(progress)}. '
          '${l10n.creatureCardProgressLabel(nextProgress)}.',
      child: InkWell(
        key: ValueKey('card-progress-$enemyId'),
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Center(
            child: Icon(
              switch (progress) {
                CreatureCardProgress.unowned =>
                  Icons.radio_button_unchecked_rounded,
                CreatureCardProgress.obtained =>
                  Icons.radio_button_checked_rounded,
                CreatureCardProgress.gold => Icons.workspace_premium_rounded,
              },
              color: color,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _EnemyTileThumbnail extends StatelessWidget {
  final String? assetName;
  final bool isIconThumbnail;

  const _EnemyTileThumbnail({
    required this.assetName,
    required this.isIconThumbnail,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (assetName == null || assetName!.trim().isEmpty) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.layers_outlined, color: colorScheme.primary),
      );
    }

    final child = FallbackAssetImage.asset(
      assetName: assetName!,
      fallbackAssetName: 'assets/global/Creaturecard_Proximamente.webp',
      width: 56,
      height: 56,
      cacheWidth: 128,
      cacheHeight: 128,
      fit: isIconThumbnail ? BoxFit.contain : BoxFit.cover,
    );

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: isIconThumbnail ? const EdgeInsets.all(8) : EdgeInsets.zero,
        child: ClipRRect(borderRadius: BorderRadius.circular(12), child: child),
      ),
    );
  }
}

class _SectionedEnemyList extends StatelessWidget {
  final List<ResolvedEnemyEntry> entries;
  final Set<String> favIds;
  final CreatureCardProgressMap cardProgressByKey;
  final List<EnemyDisplayGroup> groupOrder;
  final bool showInlineAd;
  final ScrollController controller;
  final String? selectedSpeciesKey;
  final ValueChanged<ResolvedEnemyEntry> onSelectEntry;
  final ValueChanged<ResolvedEnemyEntry> onToggleFavorite;
  final ValueChanged<ResolvedEnemyEntry> onToggleCardProgress;
  final EnemyDisplayGroup Function(ResolvedEnemyEntry entry) groupFromEntry;
  final String Function(EnemyDisplayGroup temperament) groupLabel;

  const _SectionedEnemyList({
    required this.entries,
    required this.favIds,
    required this.cardProgressByKey,
    required this.groupOrder,
    required this.showInlineAd,
    required this.controller,
    required this.selectedSpeciesKey,
    required this.onSelectEntry,
    required this.onToggleFavorite,
    required this.onToggleCardProgress,
    required this.groupFromEntry,
    required this.groupLabel,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <_SectionedEnemyRow>[];

    for (final group in groupOrder) {
      final groupItems = entries
          .where((entry) => groupFromEntry(entry) == group)
          .toList();
      if (groupItems.isEmpty) continue;

      rows.add(_SectionedEnemyRow.header(groupLabel(group)));

      var groupTileCount = 0;
      for (final entry in groupItems) {
        rows.add(_SectionedEnemyRow.entry(entry));
        groupTileCount++;
        if (showInlineAd &&
            groupItems.length >= _minTilesForSectionInlineAd &&
            groupTileCount == _sectionInlineAdAfterTile) {
          rows.add(const _SectionedEnemyRow.ad());
        }
      }
    }

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.only(bottom: 4),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row.isAd) {
          return const InlineBannerAdCard();
        }
        final label = row.headerLabel;
        if (label != null) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
          );
        }
        return EnemyTile(
          entry: row.entry!,
          favIds: favIds,
          cardProgressByKey: cardProgressByKey,
          selected: row.entry!.entry.speciesKey == selectedSpeciesKey,
          onTap: () => onSelectEntry(row.entry!),
          onToggleFavorite: () => onToggleFavorite(row.entry!),
          onToggleCardProgress: () => onToggleCardProgress(row.entry!),
        );
      },
    );
  }
}

class _SectionedEnemyRow {
  final String? headerLabel;
  final ResolvedEnemyEntry? entry;
  final bool isAd;

  const _SectionedEnemyRow.header(this.headerLabel)
    : entry = null,
      isAd = false;

  const _SectionedEnemyRow.entry(this.entry) : headerLabel = null, isAd = false;

  const _SectionedEnemyRow.ad() : headerLabel = null, entry = null, isAd = true;
}

class _GamePickerSheet extends StatelessWidget {
  final GamePick selected;
  final ValueChanged<GamePick> onPick;

  const _GamePickerSheet({required this.selected, required this.onPick});

  Color _gameColor(GamePick value) {
    return gameColorForPick(value);
  }

  Widget _button(String text, GamePick value) {
    final isSelected = selected == value;
    final baseColor = _gameColor(value);
    return SizedBox(
      height: 46,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected
              ? baseColor
              : baseColor.withValues(alpha: 0.75),
          foregroundColor: Colors.white,
        ),
        onPressed: () => onPick(value),
        child: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 16),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Text(
              l10n.selectEditionTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: _button(l10n.bothGames, GamePick.all),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _button(l10n.groundedOne, GamePick.g1)),
                const SizedBox(width: 8),
                Expanded(child: _button(l10n.groundedTwo, GamePick.g2)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ResolvedEnemyEntry {
  final EnemyIndexListEntry entry;
  final EnemyIndexEntry activeEnemy;

  const ResolvedEnemyEntry({required this.entry, required this.activeEnemy});
}

class _TierFilterOptions {
  final List<int> tiers;
  final bool hasBoss;

  const _TierFilterOptions({required this.tiers, required this.hasBoss});
}

String _variantPreferenceKey(String speciesKey) =>
    'species_variant:$speciesKey';
