import 'dart:io';

import 'package:aphidex/controllers/game_selection_controller.dart';
import 'package:aphidex/i18n/app_localizations.dart';
import 'package:aphidex/models/game_pick.dart';
import 'package:aphidex/screens/aphidex_home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('aphidex-nav-test');
    Hive.init(hiveDirectory.path);
    await Hive.openBox('aphidex');
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  Widget app({Locale? locale, ThemeMode themeMode = ThemeMode.system}) =>
      MaterialApp(
        locale: locale,
        themeMode: themeMode,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: AphidexHomeShell(
          pagesOverride: const <Widget>[
            ColoredBox(color: Colors.red),
            ColoredBox(color: Colors.green),
            ColoredBox(color: Colors.blue),
          ],
        ),
      );

  testWidgets('uses NavigationBar on phones', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app());
    await tester.pump();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('uses NavigationRail on tablets', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app());
    await tester.pump();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('Grounded 1 equipment uses an availability screen', (
    tester,
  ) async {
    GameSelectionController.instance.syncFromApp(GamePick.g1);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: GroundedTwoOnlySection(
          equipment: true,
          builder: () => const Text('G2 content loaded'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Equipo no disponible para Grounded 1'), findsOneWidget);
    expect(find.text('G2 content loaded'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final entry in const <(Locale, String)>[
    (Locale('es'), 'Equipo'),
    (Locale('en'), 'Equipment'),
    (Locale('ru'), 'Снаряжение'),
  ]) {
    testWidgets('renders primary navigation in ${entry.$1.languageCode}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(locale: entry.$1, themeMode: ThemeMode.dark));
      await tester.pump();
      expect(find.text(entry.$2), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byType(NavigationBar))).brightness,
        Brightness.dark,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
