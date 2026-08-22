import 'package:flutter/material.dart';

import '../controllers/game_selection_controller.dart';
import '../controllers/tutorial_controller.dart';
import '../data/local_storage.dart';
import '../models/game_pick.dart';
import '../startup/startup_bootstrap.dart';
import 'enemy_list_screen.dart';
import 'equipment_library_screen.dart';
import 'map_screen.dart';

class AphidexHomeShell extends StatefulWidget {
  const AphidexHomeShell({super.key, this.startupData, this.pagesOverride})
    : assert(pagesOverride == null || pagesOverride.length == 3);

  final StartupBootstrapData? startupData;
  final List<Widget>? pagesOverride;

  @override
  State<AphidexHomeShell> createState() => _AphidexHomeShellState();
}

class _AphidexHomeShellState extends State<AphidexHomeShell> {
  static const _sectionKey = 'ui_primary_section_v1';
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = LocalStorage.getInt(_sectionKey).clamp(0, 2);
  }

  void _select(int value) {
    setState(() => _index = value);
    LocalStorage.setInt(_sectionKey, value);
  }

  @override
  Widget build(BuildContext context) {
    final labels = _labels(Localizations.localeOf(context).languageCode);
    final destinations = <NavigationDestination>[
      NavigationDestination(
        icon: const Icon(Icons.pest_control),
        label: labels[0],
      ),
      NavigationDestination(
        icon: KeyedSubtree(
          key: TutorialController.instance.keyFor(
            tutorialAnchorPrimaryEquipment,
          ),
          child: const Icon(Icons.shield),
        ),
        label: labels[1],
      ),
      NavigationDestination(
        icon: KeyedSubtree(
          key: TutorialController.instance.keyFor(tutorialAnchorPrimaryMap),
          child: const Icon(Icons.map),
        ),
        label: labels[2],
      ),
    ];
    final pages =
        widget.pagesOverride ??
        <Widget>[
          EnemyListScreen(
            preloadedEntries: widget.startupData?.initialEntries,
            preloadedLanguageCode: widget.startupData?.languageCode,
            preloadedGamePick: widget.startupData?.gamePick,
            restorePhoneDetailOnStartup: false,
            onInitialListInteractive: StartupBootstrap.startDeferredServices,
          ),
          GroundedTwoOnlySection(
            equipment: true,
            builder: () => const EquipmentLibraryScreen(embedded: true),
          ),
          GroundedTwoOnlySection(
            equipment: false,
            builder: () => MapScreen(embedded: true, active: _index == 2),
          ),
        ];
    final body = IndexedStack(index: _index, children: pages);

    if (MediaQuery.sizeOf(context).width >= 840) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final item in destinations)
                  NavigationRailDestination(
                    icon: item.icon,
                    selectedIcon: item.selectedIcon,
                    label: Text(item.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: destinations,
      ),
    );
  }

  List<String> _labels(String language) => switch (language) {
    'es' => const ['Criaturas', 'Equipo', 'Mapa'],
    'ru' => const ['Существа', 'Снаряжение', 'Карта'],
    _ => const ['Creatures', 'Equipment', 'Map'],
  };
}

class GroundedTwoOnlySection extends StatelessWidget {
  const GroundedTwoOnlySection({
    super.key,
    required this.equipment,
    required this.builder,
  });

  final bool equipment;
  final Widget Function() builder;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<GamePick>(
    valueListenable: GameSelectionController.instance.gamePick,
    builder: (context, game, _) {
      if (game != GamePick.g1) return builder();
      final language = Localizations.localeOf(context).languageCode;
      String text(String en, String es, String ru) => switch (language) {
        'es' => es,
        'ru' => ru,
        _ => en,
      };
      return Scaffold(
        appBar: AppBar(
          title: Text(
            equipment
                ? text('Equipment', 'Equipo', 'Снаряжение')
                : text('Map', 'Mapa', 'Карта'),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  equipment ? Icons.shield_outlined : Icons.map_outlined,
                  size: 56,
                ),
                const SizedBox(height: 16),
                Text(
                  equipment
                      ? text(
                          'Equipment is not available for Grounded 1',
                          'Equipo no disponible para Grounded 1',
                          'Снаряжение недоступно для Grounded 1',
                        )
                      : text(
                          'Map is not available for Grounded 1',
                          'Mapa no disponible para Grounded 1',
                          'Карта недоступна для Grounded 1',
                        ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  text(
                    'This feature is currently available for Grounded 2.',
                    'Esta función está disponible actualmente para Grounded 2.',
                    'Эта функция сейчас доступна для Grounded 2.',
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
