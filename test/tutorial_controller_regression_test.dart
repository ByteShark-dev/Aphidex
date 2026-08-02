import 'package:aphidex/controllers/tutorial_controller.dart';
import 'package:aphidex/i18n/app_localizations.dart';
import 'package:aphidex/widgets/tutorial_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TutorialController.instance.debugResetForTests();
  });

  testWidgets('rapid double next only advances one step', (tester) async {
    final controller = TutorialController.instance;
    controller.debugStartStepForTests(TutorialStep.search);

    controller.next();
    controller.next();

    await tester.pump();
    await tester.pump();

    expect(controller.step, TutorialStep.gamePicker);
  });

  testWidgets('currentTargetRect drops stale anchors after unmount', (
    tester,
  ) async {
    final controller = TutorialController.instance;
    final key = controller.keyFor(tutorialAnchorListSearch);

    controller.debugStartStepForTests(TutorialStep.search);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: TutorialHost(
          child: Scaffold(
            body: Center(child: SizedBox(key: key, width: 24, height: 24)),
          ),
        ),
      ),
    );
    await tester.pump();

    final overlayContext = tester.element(find.byType(TutorialHost));
    expect(controller.currentTargetRect(overlayContext), isNotNull);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const TutorialHost(child: SizedBox.shrink()),
      ),
    );
    await tester.pump();

    final nextOverlayContext = tester.element(find.byType(TutorialHost));
    expect(controller.currentTargetRect(nextOverlayContext), isNull);
    controller.requestTargetRefresh();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
  });

  testWidgets('requestTargetRefresh re-resolves the target after scrolling', (
    tester,
  ) async {
    final controller = TutorialController.instance;
    final key = controller.keyFor(tutorialAnchorListSearch);
    final scrollController = ScrollController();

    controller.debugStartStepForTests(TutorialStep.search);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: TutorialHost(
          child: Scaffold(
            body: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                children: [
                  const SizedBox(height: 640),
                  SizedBox(key: key, width: 24, height: 24),
                  const SizedBox(height: 640),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    scrollController.jumpTo(160);
    controller.requestTargetRefresh();
    await tester.pump();
    await tester.pump();

    final overlayContext = tester.element(find.byType(TutorialHost));
    final before = controller.currentTargetRect(overlayContext);
    expect(before, isNotNull);

    scrollController.jumpTo(320);
    controller.requestTargetRefresh();
    await tester.pump();
    await tester.pump();

    final after = controller.currentTargetRect(overlayContext);
    expect(after, isNotNull);
    expect(after!.top, lessThan(before!.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'missing detail anchors are skipped without reusing stale state',
    (tester) async {
      final controller = TutorialController.instance;
      controller.debugStartStepForTests(TutorialStep.detailEffects);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const TutorialHost(child: SizedBox.shrink()),
        ),
      );
      await tester.pump();

      controller.requestTargetRefresh();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.step, TutorialStep.detailEffect);
      expect(tester.takeException(), isNull);
    },
  );
}
