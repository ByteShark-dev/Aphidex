import 'package:flutter/material.dart';

import '../controllers/tutorial_controller.dart';
import '../i18n/app_localizations.dart';

class TutorialHost extends StatefulWidget {
  final Widget child;

  const TutorialHost({super.key, required this.child});

  @override
  State<TutorialHost> createState() => _TutorialHostState();
}

class _TutorialHostState extends State<TutorialHost>
    with WidgetsBindingObserver {
  TutorialStep? _lastStep;
  bool _refreshScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _scheduleTargetRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final controller = TutorialController.instance;

    return Stack(
      fit: StackFit.expand,
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (_) {
            if (controller.isActive) {
              _scheduleTargetRefresh();
            }
            return false;
          },
          child: widget.child,
        ),
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final step = controller.step;
            if (step == null) {
              _lastStep = null;
              return const SizedBox.shrink();
            }

            if (_lastStep != step) {
              _lastStep = step;
              _scheduleTargetRefresh();
            }

            final targetRect = controller.currentTargetRect(context);
            final l10n = context.l10n;

            return _TutorialOverlayLifecycle(
              controller: controller,
              child: _TutorialOverlay(
                targetRect: targetRect,
                title: l10n.tutorialStepTitle(_tutorialStepId(step)),
                description: l10n.tutorialStepBody(_tutorialStepId(step)),
                skipLabel: l10n.tutorialSkipAction,
                backLabel: l10n.tutorialBackAction,
                nextLabel: step == TutorialStep.codexEquipment
                    ? l10n.tutorialFinishAction
                    : l10n.tutorialNextAction,
                showBack: step != TutorialStep.search,
                actionsEnabled: !controller.isBusy,
                onSkip: controller.skip,
                onBack: controller.back,
                onNext: controller.next,
              ),
            );
          },
        ),
      ],
    );
  }

  void _scheduleTargetRefresh() {
    if (_refreshScheduled || !mounted) {
      return;
    }

    _refreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      if (!mounted) {
        return;
      }
      TutorialController.instance.requestTargetRefresh();
    });
  }

  String _tutorialStepId(TutorialStep step) {
    switch (step) {
      case TutorialStep.search:
        return 'search';
      case TutorialStep.gamePicker:
        return 'gamePicker';
      case TutorialStep.profile:
        return 'profile';
      case TutorialStep.filters:
        return 'filters';
      case TutorialStep.sort:
        return 'sort';
      case TutorialStep.settings:
        return 'settings';
      case TutorialStep.equipmentLibrary:
        return 'equipmentLibrary';
      case TutorialStep.map:
        return 'map';
      case TutorialStep.codex:
        return 'codex';
      case TutorialStep.detailSummary:
        return 'detailSummary';
      case TutorialStep.detailVariant:
        return 'detailVariant';
      case TutorialStep.detailEffects:
        return 'detailEffects';
      case TutorialStep.detailEffect:
        return 'detailEffect';
      case TutorialStep.codexCard:
        return 'codexCard';
      case TutorialStep.codexEquipment:
        return 'codexEquipment';
    }
  }
}

class _TutorialOverlayLifecycle extends StatefulWidget {
  const _TutorialOverlayLifecycle({
    required this.controller,
    required this.child,
  });

  final TutorialController controller;
  final Widget child;

  @override
  State<_TutorialOverlayLifecycle> createState() =>
      _TutorialOverlayLifecycleState();
}

class _TutorialOverlayLifecycleState extends State<_TutorialOverlayLifecycle> {
  @override
  void initState() {
    super.initState();
    widget.controller.registerTutorialOverlayMounted();
  }

  @override
  void dispose() {
    widget.controller.registerTutorialOverlayUnmounted();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _TutorialOverlay extends StatelessWidget {
  final Rect? targetRect;
  final String title;
  final String description;
  final String skipLabel;
  final String backLabel;
  final String nextLabel;
  final bool showBack;
  final bool actionsEnabled;
  final Future<void> Function() onSkip;
  final Future<void> Function() onBack;
  final Future<void> Function() onNext;

  const _TutorialOverlay({
    required this.targetRect,
    required this.title,
    required this.description,
    required this.skipLabel,
    required this.backLabel,
    required this.nextLabel,
    required this.showBack,
    required this.actionsEnabled,
    required this.onSkip,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final isShortLayout = size.height < 480;
          final cardRect = _cardRect(size);
          final isTargetAbove =
              targetRect != null && targetRect!.center.dy < size.height * 0.45;

          return Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _TutorialBackdropPainter(targetRect: targetRect),
                  ),
                ),
              ),
              if (targetRect != null)
                Positioned.fromRect(
                  rect: targetRect!.inflate(10),
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x4DFFFFFF),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (targetRect != null && !isShortLayout)
                Positioned(
                  left: (cardRect.left + cardRect.width / 2) - 16,
                  top: isTargetAbove ? cardRect.top - 28 : cardRect.bottom,
                  child: IgnorePointer(
                    child: Icon(
                      isTargetAbove
                          ? Icons.arrow_drop_up_rounded
                          : Icons.arrow_drop_down_rounded,
                      size: 32,
                      color: Theme.of(context).colorScheme.surface,
                    ),
                  ),
                ),
              Positioned(
                left: isShortLayout ? 16 : cardRect.left,
                right: isShortLayout ? 16 : null,
                top: isShortLayout ? null : cardRect.top,
                bottom: isShortLayout ? 16 : null,
                width: isShortLayout ? null : cardRect.width,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isShortLayout ? 420 : cardRect.width,
                    maxHeight: isShortLayout
                        ? size.height * 0.62
                        : cardRect.height,
                  ),
                  child: SizedBox(
                    height: isShortLayout
                        ? size.height * 0.62
                        : cardRect.height,
                    width: isShortLayout ? null : cardRect.width,
                    child: Card(
                      elevation: 10,
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(description),
                                ],
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: OverflowBar(
                              alignment: MainAxisAlignment.end,
                              spacing: 10,
                              overflowSpacing: 10,
                              children: [
                                TextButton(
                                  key: const ValueKey('tutorial-skip'),
                                  onPressed: actionsEnabled
                                      ? () => onSkip()
                                      : null,
                                  child: Text(skipLabel),
                                ),
                                if (showBack)
                                  OutlinedButton(
                                    key: const ValueKey('tutorial-back'),
                                    onPressed: actionsEnabled
                                        ? () => onBack()
                                        : null,
                                    child: Text(backLabel),
                                  ),
                                FilledButton(
                                  key: const ValueKey('tutorial-next'),
                                  onPressed: actionsEnabled
                                      ? () => onNext()
                                      : null,
                                  child: Text(nextLabel),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Rect _cardRect(Size size) {
    const horizontalMargin = 16.0;
    const cardWidthLimit = 360.0;
    const preferredCardHeight = 300.0;
    const minimumCardHeight = 176.0;
    const gap = 20.0;
    const defaultTop = 96.0;

    final width = size.width > cardWidthLimit + (horizontalMargin * 2)
        ? cardWidthLimit
        : size.width - (horizontalMargin * 2);
    final availableHeight = (size.height - defaultTop - 16)
        .clamp(minimumCardHeight, preferredCardHeight)
        .toDouble();

    if (targetRect == null) {
      final fallbackTop = (size.height - availableHeight - 16)
          .clamp(defaultTop, size.height - availableHeight - 16)
          .toDouble();
      return Rect.fromLTWH(
        horizontalMargin,
        fallbackTop,
        width,
        availableHeight,
      );
    }

    final placeBelow = targetRect!.center.dy < size.height * 0.45;
    final desiredTop = placeBelow
        ? targetRect!.bottom + gap
        : targetRect!.top - availableHeight - gap;
    final clampedTop = desiredTop
        .clamp(defaultTop, size.height - availableHeight - 16)
        .toDouble();
    final left = (targetRect!.center.dx - (width / 2))
        .clamp(horizontalMargin, size.width - width - horizontalMargin)
        .toDouble();

    return Rect.fromLTWH(left, clampedTop, width, availableHeight);
  }
}

class _TutorialBackdropPainter extends CustomPainter {
  final Rect? targetRect;

  const _TutorialBackdropPainter({required this.targetRect});

  @override
  void paint(Canvas canvas, Size size) {
    final layerPaint = Paint();
    canvas.saveLayer(Offset.zero & size, layerPaint);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xD9000000),
    );

    if (targetRect != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          targetRect!.inflate(10),
          const Radius.circular(22),
        ),
        Paint()..blendMode = BlendMode.clear,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TutorialBackdropPainter oldDelegate) =>
      oldDelegate.targetRect != targetRect;
}
