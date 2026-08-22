import 'package:flutter/material.dart';

import '../data/content_repositories.dart';
import '../data/enemy_repository.dart';
import '../data/entity_asset_resolver.dart';
import '../data/local_storage.dart';
import '../data/ui_mapper.dart';
import '../models/defense_event.dart';
import '../models/enemy_index_entry.dart';
import '../models/location.dart';
import '../widgets/fallback_asset_image.dart';
import 'enemy_detail_screen.dart';
import 'map_screen.dart';

class DefenseDetailScreen extends StatefulWidget {
  const DefenseDetailScreen({
    super.key,
    required this.defenseId,
    this.embedded = false,
    this.defenseOverride,
    this.enemiesOverride,
  });

  final String defenseId;
  final bool embedded;
  final DefenseDetail? defenseOverride;
  final List<EnemyIndexEntry>? enemiesOverride;

  @override
  State<DefenseDetailScreen> createState() => _DefenseDetailScreenState();
}

class _DefenseDetailScreenState extends State<DefenseDetailScreen>
    with AutomaticKeepAliveClientMixin {
  late Future<(DefenseDetail?, List<EnemyIndexEntry>)> _future;
  late final ScrollController _scrollController;
  int _variant = 0;
  final Map<int, int> _groupByVariant = {};

  String get _variantKey => 'defense_${widget.defenseId}_selected_variant_v1';
  String _groupKey(int variant) =>
      'defense_${widget.defenseId}_variant_${variant}_group_v1';

  @override
  void initState() {
    super.initState();
    _variant = LocalStorage.getInt(_variantKey);
    _scrollController = ScrollController();
    _future = _load();
  }

  Future<(DefenseDetail?, List<EnemyIndexEntry>)> _load() async {
    if (widget.defenseOverride != null && widget.enemiesOverride != null) {
      return (widget.defenseOverride, widget.enemiesOverride!);
    }
    return (
      await DefenseRepository.find(widget.defenseId),
      await EnemyRepository.loadGame(
        'g2',
        WidgetsBinding.instance.platformDispatcher.locale.languageCode,
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final body = FutureBuilder<(DefenseDetail?, List<EnemyIndexEntry>)>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final (defense, enemies) = snapshot.data!;
        if (defense == null || defense.variants.isEmpty) {
          return const Center(child: Text('Defense data unavailable'));
        }
        final language = Localizations.localeOf(context).languageCode;
        _variant = _variant.clamp(0, defense.variants.length - 1);
        final variant = defense.variants[_variant];
        final selectedGroup =
            (_groupByVariant[_variant] ??
                    LocalStorage.getInt(_groupKey(_variant)))
                .clamp(
                  0,
                  variant.groups.isEmpty ? 0 : variant.groups.length - 1,
                );
        _groupByVariant[_variant] = selectedGroup;
        final byId = {for (final enemy in enemies) enemy.id: enemy};
        return CustomScrollView(
          key: PageStorageKey('defense-detail-${widget.defenseId}'),
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.defenseId == 'g2_mixr_defenses'
                          ? 'MIX.R'
                          : variant.name.resolve(language),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (defense.variants.length > 1) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (
                            var index = 0;
                            index < defense.variants.length;
                            index++
                          )
                            ChoiceChip(
                              label: Text(
                                defense.variants[index].name.resolve(language),
                              ),
                              selected: _variant == index,
                              onSelected: (_) {
                                setState(() => _variant = index);
                                LocalStorage.setInt(_variantKey, index);
                              },
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: FallbackAssetImage.asset(
                        assetName: variant.image,
                        fallbackAssetName:
                            EntityAssetResolver.creatureCoverFallback,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        Chip(
                          label: Text(
                            '${_t(language, 'Attackers', 'Atacantes', 'Атакующие')}: ${variant.totalCreatures}',
                          ),
                        ),
                        if (variant.difficulty != null)
                          Chip(
                            label: Text(
                              _difficulty(variant.difficulty!, language),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => MapNavigation.open(
                        context,
                        MapOpenRequest(
                          target: MapTarget(MapTargetType.defense, variant.id),
                          filter: MapFilter(
                            type: MapTargetType.defense,
                            targetId: variant.id,
                          ),
                          focus: MapFocus(
                            preferredLayer: variant.location.layer,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.map_outlined),
                      label: Text(
                        _t(
                          language,
                          'Open location',
                          'Abrir ubicación',
                          'Открыть место',
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _t(
                        language,
                        'Scheduled groups',
                        'Grupos/oleadas programadas',
                        'Запланированные группы',
                      ),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      _t(
                        language,
                        'Source schedule groups; they are not official phases.',
                        'Grupos del calendario de la fuente; no son fases oficiales.',
                        'Группы расписания источника; это не официальные фазы.',
                      ),
                    ),
                    if (variant.groups.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 42,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: variant.groups.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 6),
                          itemBuilder: (context, index) => ChoiceChip(
                            label: Text('${index + 1}'),
                            selected: selectedGroup == index,
                            onSelected: (_) {
                              setState(() => _groupByVariant[_variant] = index);
                              LocalStorage.setInt(_groupKey(_variant), index);
                            },
                          ),
                        ),
                      ),
                      if (variant.groups[selectedGroup].timeSeconds != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${_t(language, 'Time', 'Tiempo', 'Время')}: ${variant.groups[selectedGroup].timeSeconds}s',
                          ),
                        ),
                      if (variant
                              .groups[selectedGroup]
                              .declaredScheduledCreatures !=
                          null)
                        Text(
                          '${_t(language, 'Scheduled quantity', 'Cantidad programada', 'Запланировано')}: ${variant.groups[selectedGroup].declaredScheduledCreatures}',
                        ),
                      if (variant.groups[selectedGroup].compositionStatus ==
                          'partial_source_anchors')
                        Text(
                          _t(
                            language,
                            'The source proves the total and visible spawn anchors, but not their complete distribution.',
                            'La fuente demuestra el total y los puntos de aparición visibles, pero no su distribución completa.',
                            'Источник подтверждает итог и видимые точки появления, но не полное распределение.',
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      const SizedBox(height: 8),
                      for (final creature
                          in variant.groups[selectedGroup].creatures)
                        _DefenseAttackerCard(
                          creature: creature,
                          enemy: byId[creature.publicId],
                          groups: _groupsFor(variant, creature.publicId),
                        ),
                    ],
                    const SizedBox(height: 20),
                    _RewardsCard(rewards: variant.rewards, language: language),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
    if (widget.embedded) return body;
    return Scaffold(appBar: AppBar(), body: body);
  }

  List<int> _groupsFor(DefenseVariant variant, String? publicId) => [
    for (var index = 0; index < variant.groups.length; index++)
      if (variant.groups[index].creatures.any(
        (row) => row.publicId == publicId,
      ))
        index + 1,
  ];

  String _difficulty(String raw, String language) {
    final hard = raw.toLowerCase().contains('veryhard')
        ? _t(language, 'Very hard', 'Muy difícil', 'Очень сложно')
        : _t(language, 'Hard', 'Difícil', 'Сложно');
    return hard;
  }

  String _t(String language, String en, String es, String ru) =>
      switch (language) {
        'es' => es,
        'ru' => ru,
        _ => en,
      };
}

class _DefenseAttackerCard extends StatelessWidget {
  const _DefenseAttackerCard({
    required this.creature,
    required this.enemy,
    required this.groups,
  });

  final ScheduledCreature creature;
  final EnemyIndexEntry? enemy;
  final List<int> groups;

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    final asset = enemy == null
        ? EntityAssetResolver.creatureCardFallback
        : EntityAssetResolver.resolveEnemyIndex(
            enemy!,
            EntityAssetUsage.card,
          ).asset;
    return Card(
      child: ListTile(
        leading: FallbackAssetImage.asset(
          assetName: asset,
          fallbackAssetName: EntityAssetResolver.creatureCardFallback,
          width: 50,
          height: 64,
          fit: BoxFit.contain,
        ),
        title: Text(enemy?.name ?? _unknown(language)),
        subtitle: Text('${_groupsLabel(language)}: ${groups.join(', ')}'),
        trailing: Text('×${creature.count}'),
        onTap: enemy == null
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => EnemyDetailScreen(summary: enemy!),
                ),
              ),
      ),
    );
  }

  String _unknown(String language) => switch (language) {
    'es' => 'Criatura sin identificar',
    'ru' => 'Неопознанное существо',
    _ => 'Unidentified creature',
  };
  String _groupsLabel(String language) => switch (language) {
    'es' => 'Grupos',
    'ru' => 'Группы',
    _ => 'Groups',
  };
}

class _RewardsCard extends StatelessWidget {
  const _RewardsCard({required this.rewards, required this.language});
  final DefenseRewards rewards;
  final String language;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('Rewards', 'Recompensas', 'Награды'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (rewards.rawScience != null)
            ListTile(
              leading: Image.asset(
                UiMapper.rewardIcon('raw_science'),
                key: const ValueKey('raw-science-reward-icon'),
                width: 34,
                height: 34,
                fit: BoxFit.contain,
              ),
              title: Text(
                '${rewards.rawScience} ${_t('Raw Science', 'Ciencia pura', 'Чистая наука')}',
              ),
            ),
          for (final item in rewards.equipment)
            ListTile(
              leading: const Icon(Icons.gavel_outlined),
              title: Text(_rewardName(item.id)),
            ),
          for (final item in rewards.recipes)
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(
                '${_t('Recipe', 'Receta', 'Рецепт')}: ${_rewardName(item.id)}',
              ),
            ),
          for (final mutation in rewards.mutationProgress)
            ListTile(
              leading: const Icon(Icons.pets_outlined),
              title: Text('Guard Dog'),
              subtitle: mutation.amount == null
                  ? Text(
                      _t(
                        'Progress not quantified by the source',
                        'Progreso no cuantificado por la fuente',
                        'Прогресс не указан источником',
                      ),
                    )
                  : Text('${mutation.amount}'),
            ),
        ],
      ),
    ),
  );

  String _t(String en, String es, String ru) => switch (language) {
    'es' => es,
    'ru' => ru,
    _ => en,
  };

  String _rewardName(String id) => switch (id) {
    'EarwigSicklesUnique' => _t(
      'Ice Sickles',
      'Hoces de hielo',
      'Ледяные серпы',
    ),
    _ => _t('Special reward', 'Recompensa especial', 'Особая награда'),
  };
}
