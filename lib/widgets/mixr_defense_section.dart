import 'package:flutter/material.dart';

import '../data/content_repositories.dart';
import '../data/enemy_repository.dart';
import '../data/local_storage.dart';
import '../models/defense_event.dart';
import '../models/enemy_index_entry.dart';
import '../models/location.dart';
import '../screens/map_screen.dart';

class MixrDefenseSection extends StatefulWidget {
  const MixrDefenseSection({
    super.key,
    required this.languageCode,
    required this.onCreatureTap,
  });

  final String languageCode;
  final ValueChanged<EnemyIndexEntry> onCreatureTap;

  @override
  State<MixrDefenseSection> createState() => _MixrDefenseSectionState();
}

class _MixrDefenseSectionState extends State<MixrDefenseSection> {
  static const _variantKey = 'mixr_selected_variant_v1';
  int _variant = 0;
  int _group = 0;
  late Future<(List<DefenseEvent>, List<EnemyIndexEntry>)> _future;

  @override
  void initState() {
    super.initState();
    _variant = LocalStorage.getInt(_variantKey).clamp(0, 2);
    _future = _load();
  }

  Future<(List<DefenseEvent>, List<EnemyIndexEntry>)> _load() async {
    return (
      await MixrRepository.load(),
      await EnemyRepository.loadGame('g2', widget.languageCode),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<(List<DefenseEvent>, List<EnemyIndexEntry>)>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) return Text('MIX.R: ${snapshot.error}');
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final (events, entries) = snapshot.data!;
      final event = events[_variant.clamp(0, events.length - 1)];
      final selectedGroup =
          event.groups[_group.clamp(0, event.groups.length - 1)];
      final byId = {for (final entry in entries) entry.id: entry};
      final language = Localizations.localeOf(context).languageCode;
      return Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('MIX.R', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (var i = 0; i < events.length; i++)
                    ChoiceChip(
                      label: Text(events[i].name.resolve(language)),
                      selected: _variant == i,
                      onSelected: (_) {
                        setState(() {
                          _variant = i;
                          _group = 0;
                        });
                        LocalStorage.setInt(_variantKey, i);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.asset(
                  event.image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: Colors.black12,
                    child: Icon(Icons.image_not_supported, size: 46),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _t(
                  language,
                  'Scheduled groups',
                  'Grupos/oleadas programadas',
                  'Запланированные группы',
                ),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                _t(
                  language,
                  'These are source schedule groups, not official phases.',
                  'Son grupos del calendario de la fuente, no fases oficiales.',
                  'Это группы расписания источника, а не официальные фазы.',
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: event.groups.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, index) => ChoiceChip(
                    label: Text('${index + 1}'),
                    selected: _group == index,
                    onSelected: (_) => setState(() => _group = index),
                  ),
                ),
              ),
              if (selectedGroup.timeSeconds != null)
                Text(
                  '${_t(language, 'Time', 'Tiempo', 'Время')}: ${selectedGroup.timeSeconds}s',
                ),
              const SizedBox(height: 8),
              for (final creature in selectedGroup.creatures)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    byId[creature.publicId]?.name ??
                        _t(
                          language,
                          'Unidentified creature',
                          'Criatura sin identificar',
                          'Неопознанное существо',
                        ),
                  ),
                  trailing: Text('×${creature.count}'),
                  onTap:
                      creature.publicId == null ||
                          byId[creature.publicId] == null
                      ? null
                      : () => widget.onCreatureTap(byId[creature.publicId]!),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => MapNavigation.open(
                  context,
                  MapOpenRequest(
                    target: MapTarget(MapTargetType.defense, event.id),
                    filter: MapFilter(
                      type: MapTargetType.defense,
                      targetId: event.id,
                    ),
                    focus: MapFocus(preferredLayer: event.location.layer),
                  ),
                ),
                icon: const Icon(Icons.map),
                label: Text(
                  _t(
                    language,
                    'Open location',
                    'Abrir ubicación',
                    'Открыть место',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  String _t(String language, String en, String es, String ru) =>
      switch (language) {
        'es' => es,
        'ru' => ru,
        _ => en,
      };
}
