import 'package:flutter/material.dart';

import '../data/content_repositories.dart';
import '../data/effect_catalog.dart';
import '../data/entity_asset_resolver.dart';
import '../data/equipment_presentation.dart';
import '../data/ui_mapper.dart';
import '../models/equipment.dart';
import '../models/location.dart';
import '../widgets/icon_badge.dart';
import 'map_screen.dart';

class EquipmentLibraryScreen extends StatefulWidget {
  const EquipmentLibraryScreen({
    super.key,
    this.embedded = false,
    this.initialEquipmentId,
  });

  final bool embedded;
  final String? initialEquipmentId;

  @override
  State<EquipmentLibraryScreen> createState() => _EquipmentLibraryScreenState();
}

class _EquipmentLibraryScreenState extends State<EquipmentLibraryScreen> {
  int _category = 0;
  bool _openedInitial = false;

  String get _language => Localizations.localeOf(context).languageCode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: Text(_t('Equipment', 'Equipo', 'Снаряжение')),
      ),
      body: FutureBuilder<EquipmentCatalog>(
        future: EquipmentRepository.load(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                '${_t('Could not load equipment', 'No se pudo cargar el equipo', 'Не удалось загрузить снаряжение')}: ${snapshot.error}',
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final catalog = snapshot.data!;
          _openInitialOnce(catalog);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: SegmentedButton<int>(
                  segments: [
                    ButtonSegment(
                      value: 0,
                      label: Text(_t('Weapons', 'Armas', 'Оружие')),
                      icon: const Icon(Icons.gavel),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text(_t('Armor', 'Armaduras', 'Броня')),
                      icon: const Icon(Icons.shield),
                    ),
                    ButtonSegment(
                      value: 2,
                      label: Text(_t('Trinkets', 'Amuletos', 'Талисманы')),
                      icon: const Icon(Icons.auto_awesome),
                    ),
                  ],
                  selected: {_category},
                  onSelectionChanged: (value) =>
                      setState(() => _category = value.first),
                ),
              ),
              Expanded(child: _buildCategory(catalog)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategory(EquipmentCatalog catalog) {
    if (_category == 1) {
      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: catalog.armorSets.length,
        itemBuilder: (context, index) {
          final set = catalog.armorSets[index];
          return _EquipmentCard(
            title: set.name.resolve(_language),
            subtitle: '${set.pieces.length} ${_t('pieces', 'piezas', 'части')}',
            icon: EntityAssetResolver.resolveArmorSet(set).asset,
            onTap: () => _showSet(set, catalog),
          );
        },
      );
    }
    final domain = _category == 0 ? null : EquipmentDomain.trinket;
    final items = catalog.items
        .where((item) {
          if (domain == null) {
            return item.domain == EquipmentDomain.weapon ||
                item.domain == EquipmentDomain.shield;
          }
          return item.domain == domain;
        })
        .toList(growable: false);
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _EquipmentCard(
          title: item.name.resolve(_language),
          subtitle: [
            EquipmentPresentation.typeLabel(item.normalizedType, _language),
            if (item.normalizedSubtype != item.normalizedType)
              EquipmentPresentation.subtypeLabel(
                item.normalizedSubtype,
                _language,
              ),
            if (item.tier != null)
              '${_t('Tier', 'Nivel', 'Уровень')} ${item.tier}',
            if (item.acquisition.unresolved)
              _t(
                'Acquisition unresolved',
                'Adquisición no resuelta',
                'Получение не определено',
              ),
          ].join(' · '),
          icon: EntityAssetResolver.resolveEquipment(item).asset,
          onTap: () => _showItem(item),
        );
      },
    );
  }

  void _openInitialOnce(EquipmentCatalog catalog) {
    if (_openedInitial || widget.initialEquipmentId == null) return;
    _openedInitial = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final query = widget.initialEquipmentId!.toLowerCase();
      final item = catalog.items.cast<EquipmentItem?>().firstWhere(
        (value) => value!.id.toLowerCase() == query,
        orElse: () => null,
      );
      if (item != null) {
        setState(() {
          _category = item.domain == EquipmentDomain.armor
              ? 1
              : item.domain == EquipmentDomain.trinket
              ? 2
              : 0;
        });
        _showItem(item);
        return;
      }
      final set = catalog.armorSets.cast<ArmorSet?>().firstWhere(
        (item) =>
            item!.id.toLowerCase().contains(query) ||
            item.name.en.toLowerCase().contains(query) ||
            (query.contains('diving') &&
                item.name.en.toLowerCase().contains('diving')),
        orElse: () => null,
      );
      if (set != null) {
        setState(() => _category = 1);
        _showSet(set, catalog);
      }
    });
  }

  Future<void> _showItem(EquipmentItem item) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _EquipmentDetailSheet(
      item: item,
      language: _language,
      mapAction: item.locations.isEmpty
          ? null
          : () => MapNavigation.open(
              context,
              MapOpenRequest(
                target: MapTarget(MapTargetType.equipment, item.id),
                filter: MapFilter(
                  type: MapTargetType.equipment,
                  targetId: item.id,
                ),
                focus: MapFocus(preferredLayer: item.locations.first.layer),
              ),
            ),
    ),
  );

  Future<void> _showSet(ArmorSet set, EquipmentCatalog catalog) {
    final pieces = catalog.items
        .where((item) => set.pieces.contains(item.id))
        .toList();
    final locations = pieces.expand((item) => item.locations).toList();
    final locatedPiece = pieces.cast<EquipmentItem?>().firstWhere(
      (item) => item!.locations.isNotEmpty,
      orElse: () => null,
    );
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _ArmorSetDetailSheet(
        set: set,
        pieces: pieces,
        language: _language,
        onPieceTap: (piece) {
          Navigator.pop(sheetContext);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showItem(piece);
          });
        },
        mapAction: locations.isEmpty || locatedPiece == null
            ? null
            : () => MapNavigation.open(
                context,
                MapOpenRequest(
                  target: MapTarget(MapTargetType.equipment, locatedPiece.id),
                  filter: MapFilter(
                    type: MapTargetType.equipment,
                    targetId: locatedPiece.id,
                  ),
                  focus: MapFocus(preferredLayer: locations.first.layer),
                ),
              ),
      ),
    );
  }

  String _t(String en, String es, String ru) => switch (_language) {
    'es' => es,
    'ru' => ru,
    _ => en,
  };
}

class _EquipmentCard extends StatelessWidget {
  const _EquipmentCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: SizedBox.square(
        dimension: 48,
        child: icon.isEmpty
            ? const Icon(Icons.inventory_2_outlined)
            : Image.asset(
                icon,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.inventory_2_outlined),
              ),
      ),
      title: Text(title),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

class _EquipmentDetailSheet extends StatelessWidget {
  const _EquipmentDetailSheet({
    required this.item,
    required this.language,
    this.mapAction,
  });

  final EquipmentItem item;
  final String language;
  final VoidCallback? mapAction;

  String _t(String en, String es, String ru) => switch (language) {
    'es' => es,
    'ru' => ru,
    _ => en,
  };

  @override
  Widget build(BuildContext context) {
    final icon = EntityAssetResolver.resolveEquipment(item).asset;
    final slot = EquipmentPresentation.slotLabel(item.slot, language);
    final protection = (item.raw['protection'] as Map? ?? const {})
        .cast<String, dynamic>();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox.square(
                  dimension: 64,
                  child: icon.isEmpty
                      ? const Icon(Icons.inventory_2_outlined, size: 42)
                      : Image.asset(
                          icon,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.inventory_2_outlined, size: 42),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    item.name.resolve(language),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (final row in <String, String>{
              _t('Type', 'Tipo', 'Тип'): EquipmentPresentation.typeLabel(
                item.normalizedType,
                language,
              ),
              _t(
                'Subtype',
                'Subtipo',
                'Подтип',
              ): EquipmentPresentation.subtypeLabel(
                item.normalizedSubtype,
                language,
              ),
              if (item.tier != null)
                _t('Tier', 'Nivel', 'Уровень'): '${item.tier}',
              if (slot.isNotEmpty) _t('Slot', 'Ranura', 'Слот'): slot,
              if (item.twoHanded != null)
                _t('Hands', 'Manos', 'Хват'): item.twoHanded!
                    ? _t('Two handed', 'Dos manos', 'Двуручный')
                    : _t('One handed', 'Una mano', 'Одноручный'),
              if (item.canBlock != null)
                _t('Blocking', 'Bloqueo', 'Блокирование'): item.canBlock!
                    ? _t('Available', 'Disponible', 'Доступно')
                    : _t('Not available', 'No disponible', 'Недоступно'),
              if (item.durability != null)
                _t('Durability', 'Durabilidad', 'Прочность'): _number(
                  item.durability!,
                ),
              if (protection['flatDamageReductionRaw'] is num)
                _t('Defense', 'Defensa', 'Защита'): _number(
                  (protection['flatDamageReductionRaw'] as num).toDouble(),
                ),
            }.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('${row.key}: ${row.value}'),
              ),
            if (item.attacks.isNotEmpty) ...[
              const Divider(),
              Text(
                _t('Attack profiles', 'Perfiles de ataque', 'Профили атаки'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              ...item.attacks.asMap().entries.map(
                (entry) => _EquipmentAttackCard(
                  attack: entry.value,
                  ordinal: entry.key + 1,
                  language: language,
                ),
              ),
            ],
            if (item.effects.isNotEmpty) ...[
              const Divider(),
              Text(
                _t('Effects', 'Efectos', 'Эффекты'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: item.effects.map((effect) {
                  final effectType = normalizedTechnicalEffectId(effect);
                  return Chip(
                    avatar: IconBadge.asset(
                      assetName: UiMapper.effectIcon(effectType),
                      size: 18,
                      padding: EdgeInsets.zero,
                    ),
                    label: Text(
                      EquipmentPresentation.effectLabel(effect, language),
                    ),
                  );
                }).toList(),
              ),
            ],
            const Divider(),
            Text(
              _t('Acquisition', 'Adquisición', 'Получение'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (item.acquisition.unresolved)
              Text(
                _t(
                  'Acquisition details are not yet verified.',
                  'Los datos de adquisición todavía no están verificados.',
                  'Данные о получении ещё не подтверждены.',
                ),
              )
            else ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: item.acquisition.methods
                    .map(
                      (method) => Chip(
                        label: Text(
                          EquipmentPresentation.acquisitionMethod(
                            method,
                            language,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              ...item.acquisition.recipes.map(
                (recipe) => _RecipeCard(recipe: recipe, language: language),
              ),
            ],
            if (item.repair.isNotEmpty) ...[
              const Divider(),
              Text(
                _t('Repair', 'Reparación', 'Ремонт'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              ...item.repair.map(
                (ingredient) => Text(
                  '• ${EquipmentPresentation.cleanIdentifier(ingredient.itemId)} ×${ingredient.count}',
                ),
              ),
            ],
            if (item.upgradeRoutes.isNotEmpty) ...[
              const Divider(),
              Text(
                _t('Upgrade routes', 'Rutas de mejora', 'Пути улучшения'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: item.upgradeRoutes
                    .map(
                      (route) => Chip(
                        label: Text(
                          EquipmentPresentation.upgradeRoute(route, language),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (mapAction != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  mapAction!();
                },
                icon: const Icon(Icons.map),
                label: Text(_t('Open map', 'Abrir mapa', 'Открыть карту')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _number(double value) => value == value.roundToDouble()
      ? '${value.round()}'
      : value.toStringAsFixed(1);
}

class _ArmorSetDetailSheet extends StatelessWidget {
  const _ArmorSetDetailSheet({
    required this.set,
    required this.pieces,
    required this.language,
    required this.onPieceTap,
    this.mapAction,
  });

  final ArmorSet set;
  final List<EquipmentItem> pieces;
  final String language;
  final ValueChanged<EquipmentItem> onPieceTap;
  final VoidCallback? mapAction;

  String _t(String en, String es, String ru) => switch (language) {
    'es' => es,
    'ru' => ru,
    _ => en,
  };

  @override
  Widget build(BuildContext context) {
    final resolution = EntityAssetResolver.resolveArmorSet(set);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox.square(
                  dimension: 72,
                  child: Image.asset(resolution.asset, fit: BoxFit.contain),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        set.name.resolve(language),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        '${pieces.length} ${_t('pieces', 'piezas', 'части')}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (resolution.source == 'primary_piece_fallback') ...[
              const SizedBox(height: 8),
              Text(
                _t(
                  'Representative image: verified primary piece.',
                  'Imagen representativa: pieza principal verificada.',
                  'Представительное изображение: основная проверенная часть.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (set.tiers.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '${_t('Tiers', 'Niveles', 'Уровни')}: ${set.tiers.join(', ')}',
              ),
            ],
            if (set.effects.isNotEmpty) ...[
              const Divider(height: 28),
              Text(
                _t('Set effects', 'Efectos del set', 'Эффекты комплекта'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: set.effects
                    .map(
                      (effect) => Chip(
                        avatar: IconBadge.asset(
                          assetName: UiMapper.effectIcon(
                            normalizedTechnicalEffectId(effect),
                          ),
                          size: 18,
                          padding: EdgeInsets.zero,
                        ),
                        label: Text(
                          EquipmentPresentation.effectLabel(effect, language),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const Divider(height: 28),
            Text(
              _t('Pieces', 'Piezas', 'Части'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...pieces.map(
              (piece) => Card(
                child: ListTile(
                  leading: SizedBox.square(
                    dimension: 44,
                    child: Image.asset(
                      EntityAssetResolver.resolveEquipment(piece).asset,
                      fit: BoxFit.contain,
                    ),
                  ),
                  title: Text(piece.name.resolve(language)),
                  subtitle: Text(
                    EquipmentPresentation.slotLabel(piece.slot, language),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onPieceTap(piece),
                ),
              ),
            ),
            if (mapAction != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  mapAction!();
                },
                icon: const Icon(Icons.map),
                label: Text(_t('Open map', 'Abrir mapa', 'Открыть карту')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EquipmentAttackCard extends StatelessWidget {
  const _EquipmentAttackCard({
    required this.attack,
    required this.ordinal,
    required this.language,
  });

  final EquipmentAttack attack;
  final int ordinal;
  final String language;

  String _t(String en, String es, String ru) => switch (language) {
    'es' => es,
    'ru' => ru,
    _ => en,
  };

  String _number(double value) => value == value.roundToDouble()
      ? '${value.round()}'
      : value.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final values = <String>[
      if (attack.damage != null)
        '${_t('Damage', 'Daño', 'Урон')}: ${_number(attack.damage!)}',
      if (attack.chargedDamage != null)
        '${_t('Charged', 'Cargado', 'Заряженный')}: ${_number(attack.chargedDamage!)}',
      if (attack.stun != null) 'Stun: ${_number(attack.stun!)}',
      if (attack.stamina != null)
        '${_t('Stamina', 'Aguante', 'Выносливость')}: ${_number(attack.stamina!)}',
      if (attack.range != null)
        '${_t('Range', 'Alcance', 'Дальность')}: ${_number(attack.range!)}',
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_t('Profile', 'Perfil', 'Профиль')} $ordinal',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if (values.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: values.map(Text.new).toList(),
              ),
            ],
            if (attack.physical != null || attack.element != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  if (attack.physical != null) _effectChip(attack.physical!),
                  if (attack.element != null) _effectChip(attack.element!),
                ],
              ),
            ],
            if (attack.statusEffects.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: attack.statusEffects
                    .map((effect) => _effectChip(effect.id))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _effectChip(String raw) {
    final effectType = normalizedTechnicalEffectId(raw);
    return Chip(
      avatar: IconBadge.asset(
        assetName: UiMapper.effectIcon(effectType),
        size: 18,
        padding: EdgeInsets.zero,
      ),
      label: Text(EquipmentPresentation.effectLabel(raw, language)),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe, required this.language});

  final EquipmentRecipe recipe;
  final String language;

  String _t(String en, String es, String ru) => switch (language) {
    'es' => es,
    'ru' => ru,
    _ => en,
  };

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 10),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            EquipmentPresentation.stationLabel(recipe.station, language),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (recipe.requirements.isEmpty)
            Text(
              _t(
                'Materials not listed',
                'Materiales no listados',
                'Материалы не указаны',
              ),
            )
          else
            ...recipe.requirements.map(
              (ingredient) => Text(
                '• ${EquipmentPresentation.cleanIdentifier(ingredient.itemId)} ×${ingredient.count}',
              ),
            ),
        ],
      ),
    ),
  );
}
