import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/effect_catalog.dart';
import '../data/enemy_repository.dart';
import '../data/local_storage.dart';
import '../data/ui_mapper.dart';
import '../i18n/app_localizations.dart';
import '../layout/app_breakpoints.dart';
import '../models/enemy.dart';
import '../models/enemy_index_entry.dart';
import '../screens/effect_codex_screen.dart';
import '../screens/enemy_detail_screen.dart';
import 'review_prompt_controller.dart';

const String tutorialAnchorListSearch = 'tutorial-list-search';
const String tutorialAnchorListGame = 'tutorial-list-game';
const String tutorialAnchorListFilters = 'tutorial-list-filters';
const String tutorialAnchorListSort = 'tutorial-list-sort';
const String tutorialAnchorListSettings = 'tutorial-list-settings';
const String tutorialAnchorListCodex = 'tutorial-list-codex';
const String tutorialAnchorListProfile = 'tutorial-list-profile';
const String tutorialAnchorDetailSummary = 'tutorial-detail-summary';
const String tutorialAnchorDetailVariant = 'tutorial-detail-variant';
const String tutorialAnchorDetailEffects = 'tutorial-detail-effects';

String tutorialAnchorDetailEffect(String effectId) =>
    'tutorial-detail-effect-$effectId';

String tutorialAnchorEffectCard(String effectId) =>
    'tutorial-effect-card-$effectId';

String tutorialAnchorEffectEquipment(String effectId) =>
    'tutorial-effect-equipment-$effectId';

enum TutorialStep {
  search,
  gamePicker,
  profile,
  filters,
  sort,
  settings,
  codex,
  detailSummary,
  detailVariant,
  detailEffects,
  detailEffect,
  codexCard,
  codexEquipment,
}

enum TutorialTargetScope { list, inlineDetail, fullscreenDetail, codex }

bool _isValidTutorialEnemy(Enemy enemy) {
  if (enemy.photo.trim().isEmpty) {
    return false;
  }

  final hasDetails =
      enemy.health != null ||
      enemy.elementalWeaknesses.isNotEmpty ||
      enemy.damageWeaknesses.isNotEmpty ||
      enemy.resistancesV2.isNotEmpty ||
      enemy.resolvedWeakPoints.isNotEmpty ||
      enemy.weaknesses.isNotEmpty ||
      enemy.resistances.isNotEmpty;

  return hasDetails && tutorialEffectIdsForEnemy(enemy).isNotEmpty;
}

List<String> tutorialEffectIdsForEnemy(Enemy enemy) {
  final ids = <String>[];

  void addId(String rawId) {
    final canonicalId = canonicalEffectId(rawId);
    if (effectCatalogEntryById(canonicalId) == null) {
      return;
    }
    if (!ids.contains(canonicalId)) {
      ids.add(canonicalId);
    }
  }

  for (final item in enemy.weaknesses) {
    addId(item);
  }
  for (final item in enemy.resistances) {
    addId(item);
  }
  for (final bonus in enemy.elementalWeaknesses) {
    addId(bonus.type);
  }
  for (final bonus in enemy.damageWeaknesses) {
    addId(bonus.type);
  }
  for (final bonus in enemy.resistancesV2) {
    addId(bonus.type);
  }
  for (final weakPoint in enemy.resolvedWeakPoints) {
    for (final effectId in UiMapper.susceptibleDamageEffectIds(
      weakPoint.susceptibleDamage,
    )) {
      addId(effectId);
    }
  }

  return ids;
}

List<String> tutorialEffectIdsForEnemySummary(EnemyIndexEntry enemy) {
  final ids = <String>[];

  void addId(String rawId) {
    final canonicalId = canonicalEffectId(rawId);
    if (effectCatalogEntryById(canonicalId) == null) {
      return;
    }
    if (!ids.contains(canonicalId)) {
      ids.add(canonicalId);
    }
  }

  for (final item in enemy.weaknesses) {
    addId(item);
  }
  for (final item in enemy.resistances) {
    addId(item);
  }

  return ids;
}

Enemy? pickTutorialEnemy(List<Enemy> enemies, {Random? random}) {
  final candidates = enemies.where(_isValidTutorialEnemy).toList();

  if (candidates.isEmpty) {
    return null;
  }

  final picker = random ?? Random();
  return candidates[picker.nextInt(candidates.length)];
}

List<Enemy>? pickTutorialEnemyVariants(List<Enemy> enemies, {Random? random}) {
  final grouped = <String, List<Enemy>>{};
  for (final enemy in enemies.where(_isValidTutorialEnemy)) {
    grouped.putIfAbsent(enemy.speciesKey, () => <Enemy>[]).add(enemy);
  }

  final sharedCandidates = grouped.values
      .where(
        (variants) => variants.map((enemy) => enemy.game).toSet().length > 1,
      )
      .map((variants) {
        variants.sort((a, b) {
          if (a.game == b.game) {
            return (a.order ?? 999999).compareTo(b.order ?? 999999);
          }
          if (a.game == 'g1') {
            return -1;
          }
          if (b.game == 'g1') {
            return 1;
          }
          return a.game.compareTo(b.game);
        });
        return variants;
      })
      .toList();

  if (sharedCandidates.isNotEmpty) {
    final picker = random ?? Random();
    return sharedCandidates[picker.nextInt(sharedCandidates.length)];
  }

  final fallback = pickTutorialEnemy(enemies, random: random);
  if (fallback == null) {
    return null;
  }
  return [fallback];
}

bool _isValidTutorialEnemySummary(EnemyIndexEntry enemy) {
  final hasDetails =
      enemy.health != null ||
      enemy.weaknesses.isNotEmpty ||
      enemy.resistances.isNotEmpty;

  return hasDetails && tutorialEffectIdsForEnemySummary(enemy).isNotEmpty;
}

EnemyIndexEntry? pickTutorialEnemySummary(
  List<EnemyIndexEntry> enemies, {
  Random? random,
}) {
  final candidates = enemies.where(_isValidTutorialEnemySummary).toList();

  if (candidates.isEmpty) {
    return null;
  }

  final picker = random ?? Random();
  return candidates[picker.nextInt(candidates.length)];
}

List<EnemyIndexEntry>? pickTutorialEnemySummaryVariants(
  List<EnemyIndexEntry> enemies, {
  Random? random,
}) {
  final grouped = <String, List<EnemyIndexEntry>>{};
  for (final enemy in enemies.where(_isValidTutorialEnemySummary)) {
    grouped.putIfAbsent(enemy.speciesKey, () => <EnemyIndexEntry>[]).add(enemy);
  }

  final sharedCandidates = grouped.values
      .where(
        (variants) => variants.map((enemy) => enemy.game).toSet().length > 1,
      )
      .map((variants) {
        variants.sort((a, b) {
          if (a.game == b.game) {
            return (a.order ?? 999999).compareTo(b.order ?? 999999);
          }
          if (a.game == 'g1') {
            return -1;
          }
          if (b.game == 'g1') {
            return 1;
          }
          return a.game.compareTo(b.game);
        });
        return variants;
      })
      .toList();

  if (sharedCandidates.isNotEmpty) {
    final picker = random ?? Random();
    return sharedCandidates[picker.nextInt(sharedCandidates.length)];
  }

  final fallback = pickTutorialEnemySummary(enemies, random: random);
  if (fallback == null) {
    return null;
  }
  return [fallback];
}

class TutorialController extends ChangeNotifier {
  TutorialController._();

  static final TutorialController instance = TutorialController._();
  static const String completionKey = 'tutorial_completed';
  static const String tutorialDetailRouteName = 'tutorial-detail-fullscreen';

  final Map<TutorialTargetScope, Map<String, GlobalKey>> _anchorKeys = {};

  bool _autoStartChecked = false;
  bool _promptVisible = false;
  TutorialStep? _step;
  EnemyIndexEntry? _demoEnemy;
  List<EnemyIndexEntry> _demoVariants = const [];
  String? _demoEffectId;
  bool _syncingAnchor = false;
  bool _targetRefreshQueued = false;
  bool _isFinishing = false;
  bool _transitionLocked = false;
  Route<void>? _tutorialDetailRoute;
  AppSurfaceSize? _currentListSurface;
  bool _currentListIsTabletLike = false;
  bool _usesInlineDetailTutorial = false;
  TutorialTargetScope _detailTargetScope = TutorialTargetScope.inlineDetail;
  bool _tutorialOverlayMounted = false;

  TutorialStep? get step => _step;
  bool get isActive => _step != null;
  bool get isBusy => _syncingAnchor || _transitionLocked || _isFinishing;
  String? get demoEnemyId => _demoEnemy?.id;
  String? get demoEffectId => _demoEffectId;
  EnemyIndexEntry? get inlineDetailEnemy =>
      _usesInlineDetailTutorial ? _demoEnemy : null;
  List<EnemyIndexEntry> get inlineDetailVariants =>
      _usesInlineDetailTutorial ? _demoVariants : const [];

  GlobalKey keyFor(
    String id, {
    TutorialTargetScope scope = TutorialTargetScope.list,
  }) {
    final keys = _anchorKeys.putIfAbsent(scope, () => {});
    return keys.putIfAbsent(
      id,
      () => GlobalKey(debugLabel: '${scope.name}:$id'),
    );
  }

  String? tutorialEffectIdForEnemy(String enemyId) {
    if (_demoEnemy?.id != enemyId) {
      return null;
    }
    return _demoEffectId;
  }

  Rect? currentTargetRect(BuildContext overlayContext) {
    final resolvedTarget = _resolveCurrentAnchor();
    if (resolvedTarget == null) {
      return null;
    }

    RenderObject? overlayBox;
    try {
      overlayBox = overlayContext.findRenderObject();
    } catch (_) {
      return null;
    }
    if (overlayBox is! RenderBox ||
        !overlayBox.attached ||
        !overlayBox.hasSize ||
        !_hasValidSize(overlayBox.size)) {
      return null;
    }

    try {
      final topLeft = resolvedTarget.renderBox.localToGlobal(
        Offset.zero,
        ancestor: overlayBox,
      );
      if (!topLeft.dx.isFinite || !topLeft.dy.isFinite) {
        return null;
      }
      final viewport = Offset.zero & overlayBox.size;
      final target = topLeft & resolvedTarget.renderBox.size;
      final clipped = target.intersect(viewport);
      return clipped.isEmpty ? null : clipped;
    } catch (_) {
      return null;
    }
  }

  void requestTargetRefresh() {
    if (_step == null ||
        _targetRefreshQueued ||
        _syncingAnchor ||
        _isFinishing) {
      return;
    }

    _targetRefreshQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _targetRefreshQueued = false;
      unawaited(syncCurrentTargetVisibility(waitForNextFrame: false));
    });
  }

  Future<void> syncCurrentTargetVisibility({
    bool waitForNextFrame = true,
  }) async {
    final step = _step;
    if (step == null || _syncingAnchor || _isFinishing) {
      return;
    }

    _syncingAnchor = true;
    notifyListeners();
    try {
      if (waitForNextFrame) {
        await _waitForFrame();
      }
      if (_step != step || _isFinishing) {
        return;
      }

      var resolvedTarget = await _resolveCurrentAnchorAfterFrames();
      if (_step != step || _isFinishing) {
        return;
      }
      if (resolvedTarget == null) {
        await _skipMissingStep(step);
        return;
      }

      final targetContext = resolvedTarget.context;
      if (!targetContext.mounted) {
        await _skipMissingStep(step);
        return;
      }

      final scrollable = Scrollable.maybeOf(targetContext);
      if (scrollable != null) {
        await Scrollable.ensureVisible(
          targetContext,
          alignment: 0.12,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
        await _waitForFrame();
        if (_step != step || _isFinishing) {
          return;
        }
        resolvedTarget = await _resolveCurrentAnchorAfterFrames(attempts: 1);
        if (resolvedTarget == null) {
          await _skipMissingStep(step);
        }
      }
    } catch (_) {
      // Ignore transient route/layout races while the next frame settles.
    } finally {
      _syncingAnchor = false;
      notifyListeners();
    }
  }

  Future<void> maybeStart(
    BuildContext context,
    List<EnemyIndexEntry> enemies,
  ) async {
    if (_autoStartChecked || isActive || _promptVisible) {
      return;
    }
    _autoStartChecked = true;

    if (LocalStorage.getBool(completionKey, fallback: false)) {
      return;
    }

    final shouldStart = await _showIntroPrompt(context);
    if (!shouldStart) {
      await LocalStorage.setBool(completionKey, true);
      return;
    }

    await _start(enemies);
  }

  Future<void> startFromSettings() async {
    final navigator = ReviewPromptController.navigatorKey.currentState;
    if (navigator == null || isActive || _isFinishing) {
      return;
    }

    final languageCode = navigator.context.l10n.languageCode;
    navigator.popUntil((route) => route.isFirst);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final enemies = await EnemyRepository.loadAll(languageCode);
    await _start(enemies, force: true);
  }

  Future<void> next() async {
    await _runLocked(() async {
      switch (_step) {
        case TutorialStep.search:
          await _goToStep(TutorialStep.gamePicker);
          return;
        case TutorialStep.gamePicker:
          await _goToStep(TutorialStep.profile);
          return;
        case TutorialStep.profile:
          await _goToStep(TutorialStep.filters);
          return;
        case TutorialStep.filters:
          await _goToStep(TutorialStep.sort);
          return;
        case TutorialStep.sort:
          await _goToStep(TutorialStep.settings);
          return;
        case TutorialStep.settings:
          await _goToStep(TutorialStep.codex);
          return;
        case TutorialStep.codex:
          await _openDemoEnemy();
          await _goToStep(TutorialStep.detailSummary);
          return;
        case TutorialStep.detailSummary:
          if (_demoVariants.length > 1) {
            await _goToStep(TutorialStep.detailVariant);
            return;
          }
          await _goToStep(TutorialStep.detailEffects);
          return;
        case TutorialStep.detailVariant:
          await _goToStep(TutorialStep.detailEffects);
          return;
        case TutorialStep.detailEffects:
          await _goToStep(TutorialStep.detailEffect);
          return;
        case TutorialStep.detailEffect:
          await _openDemoCodex();
          await _goToStep(TutorialStep.codexCard);
          return;
        case TutorialStep.codexCard:
          await _goToStep(TutorialStep.codexEquipment);
          return;
        case TutorialStep.codexEquipment:
          await finish();
          return;
        case null:
          return;
      }
    });
  }

  Future<void> back() async {
    await _runLocked(() async {
      switch (_step) {
        case TutorialStep.search:
        case null:
          return;
        case TutorialStep.gamePicker:
          await _goToStep(TutorialStep.search);
          return;
        case TutorialStep.filters:
          await _goToStep(TutorialStep.profile);
          return;
        case TutorialStep.profile:
          await _goToStep(TutorialStep.gamePicker);
          return;
        case TutorialStep.sort:
          await _goToStep(TutorialStep.filters);
          return;
        case TutorialStep.settings:
          await _goToStep(TutorialStep.sort);
          return;
        case TutorialStep.codex:
          await _goToStep(TutorialStep.settings);
          return;
        case TutorialStep.detailSummary:
          await _closeDemoEnemyPresentation();
          await _goToStep(TutorialStep.codex);
          return;
        case TutorialStep.detailVariant:
          await _goToStep(TutorialStep.detailSummary);
          return;
        case TutorialStep.detailEffects:
          if (_demoVariants.length > 1) {
            await _goToStep(TutorialStep.detailVariant);
          } else {
            await _goToStep(TutorialStep.detailSummary);
          }
          return;
        case TutorialStep.detailEffect:
          await _goToStep(TutorialStep.detailEffects);
          return;
        case TutorialStep.codexCard:
          await _popRouteIfPossible();
          await _goToStep(TutorialStep.detailEffect);
          return;
        case TutorialStep.codexEquipment:
          await _goToStep(TutorialStep.codexCard);
          return;
      }
    });
  }

  Future<void> skip() => _close(markCompleted: true);

  Future<void> finish() => _close(markCompleted: true);

  void resetRuntimeState() {
    _autoStartChecked = false;
    _step = null;
    _demoEnemy = null;
    _demoVariants = const [];
    _demoEffectId = null;
    _syncingAnchor = false;
    _targetRefreshQueued = false;
    _isFinishing = false;
    _transitionLocked = false;
    _tutorialDetailRoute = null;
    _currentListSurface = null;
    _currentListIsTabletLike = false;
    _usesInlineDetailTutorial = false;
    _detailTargetScope = TutorialTargetScope.inlineDetail;
    _tutorialOverlayMounted = false;
    _anchorKeys.clear();
    _promptVisible = false;
    notifyListeners();
  }

  void debugResetForTests() {
    resetRuntimeState();
  }

  @visibleForTesting
  void debugStartStepForTests(TutorialStep step) {
    _isFinishing = false;
    _autoStartChecked = true;
    _transitionLocked = false;
    _step = step;
    notifyListeners();
  }

  @visibleForTesting
  void debugConfigureDetailTutorialForTests({
    required EnemyIndexEntry enemy,
    required List<EnemyIndexEntry> variants,
    required String effectId,
  }) {
    _demoEnemy = enemy;
    _demoVariants = variants;
    _demoEffectId = effectId;
    _autoStartChecked = true;
  }

  @visibleForTesting
  Future<void> debugOpenDetailTutorialRouteForTests() => _openDemoEnemy();

  void updateListLayout({
    required AppSurfaceSize surface,
    required bool isTabletLike,
  }) {
    _currentListSurface = surface;
    _currentListIsTabletLike = isTabletLike;
  }

  void registerTutorialOverlayMounted() {
    _tutorialOverlayMounted = true;
  }

  void registerTutorialOverlayUnmounted() {
    _tutorialOverlayMounted = false;
  }

  Future<void> _start(
    List<EnemyIndexEntry> enemies, {
    bool force = false,
  }) async {
    if (isActive) {
      return;
    }
    if (!force && LocalStorage.getBool(completionKey, fallback: false)) {
      return;
    }

    final variants = pickTutorialEnemySummaryVariants(enemies);
    if (variants == null || variants.isEmpty) {
      return;
    }

    var enemy = variants.first;
    for (final item in variants) {
      if (item.game == 'g2') {
        enemy = item;
        break;
      }
    }
    final effectIds = tutorialEffectIdsForEnemySummary(enemy);
    if (effectIds.isEmpty) {
      return;
    }

    _demoEnemy = enemy;
    _demoVariants = variants;
    _demoEffectId = effectIds.first;
    await _goToStep(TutorialStep.search);
  }

  Future<bool> _showIntroPrompt(BuildContext context) async {
    _promptVisible = true;
    try {
      final l10n = context.l10n;
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.tutorialPromptTitle),
          content: Text(l10n.tutorialPromptBody),
          actions: [
            TextButton(
              key: const ValueKey('tutorial-prompt-skip'),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.tutorialPromptSkipAction),
            ),
            FilledButton(
              key: const ValueKey('tutorial-prompt-start'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.tutorialPromptStartAction),
            ),
          ],
        ),
      );
      return result ?? false;
    } finally {
      _promptVisible = false;
    }
  }

  void _setStep(TutorialStep value) {
    _step = value;
    notifyListeners();
  }

  Future<void> _runLocked(Future<void> Function() action) async {
    if (_isFinishing || _transitionLocked) {
      return;
    }
    _transitionLocked = true;
    try {
      await action();
    } finally {
      _transitionLocked = false;
      notifyListeners();
    }
  }

  Future<void> _goToStep(TutorialStep value) async {
    if (_isFinishing) {
      return;
    }
    _setStep(value);
    requestTargetRefresh();
    await _waitForFrame();
  }

  Future<void> _waitForFrame() async {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      completer.complete();
    });
    await completer.future;
  }

  Future<void> _waitForSettledUi() async {
    await _waitForFrame();
    await Future<void>.delayed(const Duration(milliseconds: 16));
    await _waitForFrame();
  }

  Future<bool> _waitForTutorialOverlayRemoval() async {
    const maximumFrames = 3;
    for (
      var frame = 0;
      frame < maximumFrames && _tutorialOverlayMounted;
      frame++
    ) {
      await _waitForFrame();
    }
    return !_tutorialOverlayMounted;
  }

  Future<void> _openDemoEnemy() async {
    final enemy = _demoEnemy;
    if (enemy == null || _isFinishing) {
      return;
    }

    if (_shouldUseInlineDetailTutorial()) {
      _usesInlineDetailTutorial = true;
      _detailTargetScope = TutorialTargetScope.inlineDetail;
      notifyListeners();
      return;
    }

    final navigator = ReviewPromptController.navigatorKey.currentState;
    if (navigator == null) {
      return;
    }
    _usesInlineDetailTutorial = false;
    _detailTargetScope = TutorialTargetScope.fullscreenDetail;
    final route = MaterialPageRoute<void>(
      settings: const RouteSettings(name: tutorialDetailRouteName),
      builder: (_) => EnemyDetailScreen(
        summary: enemy,
        variantSummaries: _demoVariants,
        initialGame: enemy.game,
        tutorialTargetScope: TutorialTargetScope.fullscreenDetail,
      ),
    );
    _tutorialDetailRoute = route;

    unawaited(navigator.push(route));
    await _waitForSettledUi();
    await _waitForFrame();
  }

  Future<void> _openDemoCodex() async {
    final context = ReviewPromptController.navigatorKey.currentContext;
    final effectId = _demoEffectId;
    if (context == null || effectId == null || _isFinishing) {
      return;
    }

    unawaited(openEffectCodex(context, initialEffectId: effectId));
    await _waitForSettledUi();
  }

  Future<void> _popRouteIfPossible() async {
    final navigator = ReviewPromptController.navigatorKey.currentState;
    if (navigator == null || !navigator.canPop() || _isFinishing) {
      return;
    }
    final isTutorialDetailRouteCurrent =
        _tutorialDetailRoute != null && _tutorialDetailRoute!.isCurrent;
    navigator.pop();
    await _waitForSettledUi();
    if (isTutorialDetailRouteCurrent) {
      _clearTutorialDetailRoute();
    }
  }

  Future<void> _close({required bool markCompleted}) async {
    if (_isFinishing) {
      return;
    }
    _isFinishing = true;

    _step = null;
    _targetRefreshQueued = false;
    notifyListeners();

    // TutorialHost owns the overlay in the root Stack. Do not touch the
    // detail presentation until that subtree is actually gone.
    if (!await _waitForTutorialOverlayRemoval()) {
      _isFinishing = false;
      notifyListeners();
      return;
    }
    await _closeTutorialDetailRouteIfNeeded();
    _usesInlineDetailTutorial = false;
    _detailTargetScope = TutorialTargetScope.inlineDetail;
    _demoEnemy = null;
    _demoVariants = const [];
    _demoEffectId = null;
    if (markCompleted) {
      await LocalStorage.setBool(completionKey, true);
    }
    _isFinishing = false;
    notifyListeners();
  }

  String? get _currentAnchorId {
    switch (_step) {
      case TutorialStep.search:
        return tutorialAnchorListSearch;
      case TutorialStep.gamePicker:
        return tutorialAnchorListGame;
      case TutorialStep.profile:
        return tutorialAnchorListProfile;
      case TutorialStep.filters:
        return tutorialAnchorListFilters;
      case TutorialStep.sort:
        return tutorialAnchorListSort;
      case TutorialStep.settings:
        return tutorialAnchorListSettings;
      case TutorialStep.codex:
        return tutorialAnchorListCodex;
      case TutorialStep.detailSummary:
        return tutorialAnchorDetailSummary;
      case TutorialStep.detailVariant:
        return _demoVariants.length > 1 ? tutorialAnchorDetailVariant : null;
      case TutorialStep.detailEffects:
        return tutorialAnchorDetailEffects;
      case TutorialStep.detailEffect:
        final effectId = _demoEffectId;
        return effectId == null ? null : tutorialAnchorDetailEffect(effectId);
      case TutorialStep.codexCard:
        final effectId = _demoEffectId;
        return effectId == null ? null : tutorialAnchorEffectCard(effectId);
      case TutorialStep.codexEquipment:
        final effectId = _demoEffectId;
        return effectId == null
            ? null
            : tutorialAnchorEffectEquipment(effectId);
      case null:
        return null;
    }
  }

  Future<void> _skipMissingStep(TutorialStep step) async {
    if (_step != step) {
      return;
    }

    switch (step) {
      case TutorialStep.detailVariant:
        await _goToStep(TutorialStep.detailEffects);
        return;
      case TutorialStep.detailEffects:
        await _goToStep(TutorialStep.detailEffect);
        return;
      case TutorialStep.detailEffect:
        await _openDemoCodex();
        await _goToStep(TutorialStep.codexCard);
        return;
      case TutorialStep.codexCard:
        await _goToStep(TutorialStep.codexEquipment);
        return;
      case TutorialStep.codexEquipment:
        await finish();
        return;
      default:
        return;
    }
  }

  _ResolvedTutorialAnchor? _resolveCurrentAnchor() {
    final anchorId = _currentAnchorId;
    if (anchorId == null) {
      return null;
    }

    return _resolveAnchorContext(
      _anchorKeys[_currentAnchorScope]?[anchorId]?.currentContext,
    );
  }

  TutorialTargetScope get _currentAnchorScope {
    switch (_step) {
      case TutorialStep.detailSummary:
      case TutorialStep.detailVariant:
      case TutorialStep.detailEffects:
      case TutorialStep.detailEffect:
        return _detailTargetScope;
      case TutorialStep.codexCard:
      case TutorialStep.codexEquipment:
        return TutorialTargetScope.codex;
      case TutorialStep.search:
      case TutorialStep.gamePicker:
      case TutorialStep.profile:
      case TutorialStep.filters:
      case TutorialStep.sort:
      case TutorialStep.settings:
      case TutorialStep.codex:
      case null:
        return TutorialTargetScope.list;
    }
  }

  Future<_ResolvedTutorialAnchor?> _resolveCurrentAnchorAfterFrames({
    int attempts = 2,
  }) async {
    for (var index = 0; index < attempts; index++) {
      final resolved = _resolveCurrentAnchor();
      if (resolved != null) {
        return resolved;
      }
      if (index != attempts - 1) {
        await _waitForFrame();
      }
    }
    return null;
  }

  _ResolvedTutorialAnchor? _resolveAnchorContext(BuildContext? targetContext) {
    if (targetContext == null || !targetContext.mounted) {
      return null;
    }

    RenderObject? targetObject;
    try {
      targetObject = targetContext.findRenderObject();
    } catch (_) {
      return null;
    }
    if (targetObject is! RenderBox ||
        !targetObject.attached ||
        !targetObject.hasSize ||
        !_hasValidSize(targetObject.size)) {
      return null;
    }

    return _ResolvedTutorialAnchor(
      context: targetContext,
      renderBox: targetObject,
    );
  }

  bool _hasValidSize(Size size) =>
      size.width.isFinite &&
      size.height.isFinite &&
      size.width > 0 &&
      size.height > 0;

  bool _shouldUseInlineDetailTutorial() {
    final surface = _currentListSurface;
    if (surface == null) {
      return false;
    }
    return _currentListIsTabletLike && (surface.isExpanded || surface.isWide);
  }

  Future<void> _closeDemoEnemyPresentation() async {
    if (_usesInlineDetailTutorial) {
      _usesInlineDetailTutorial = false;
      _detailTargetScope = TutorialTargetScope.inlineDetail;
      notifyListeners();
      return;
    }
    await _closeTutorialDetailRouteIfNeeded();
  }

  Future<void> _closeTutorialDetailRouteIfNeeded() async {
    final route = _tutorialDetailRoute;
    final navigator = ReviewPromptController.navigatorKey.currentState;
    if (route == null || navigator == null || !route.isActive) {
      _clearTutorialDetailRoute();
      return;
    }

    if (route.isCurrent && navigator.canPop()) {
      navigator.pop();
      await _waitForSettledUi();
      _clearTutorialDetailRoute();
      return;
    }

    navigator.removeRoute(route);
    await _waitForSettledUi();
    _clearTutorialDetailRoute();
  }

  void _clearTutorialDetailRoute() {
    _tutorialDetailRoute = null;
  }
}

class _ResolvedTutorialAnchor {
  const _ResolvedTutorialAnchor({
    required this.context,
    required this.renderBox,
  });

  final BuildContext context;
  final RenderBox renderBox;
}
