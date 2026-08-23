import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/content_repositories.dart';
import '../data/enemy_repository.dart';
import '../data/entity_asset_resolver.dart';
import '../data/local_storage.dart';
import '../models/defense_event.dart';
import '../models/enemy_index_entry.dart';
import '../models/equipment.dart';
import '../models/location.dart';
import 'enemy_detail_screen.dart';
import 'defense_detail_screen.dart';
import 'equipment_library_screen.dart';

class MapNavigation {
  const MapNavigation._();

  static Future<void> open(BuildContext context, MapOpenRequest request) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => MapScreen(request: request)),
      );
}

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    this.embedded = false,
    this.request,
    this.active = true,
  });

  final bool embedded;
  final MapOpenRequest? request;
  final bool active;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  static const _layerKey = 'map_selected_layer_v1';
  static const _contextKey = 'map_context_target_v1';
  static const _abyssDismissedKey = 'notice_abyss_diving_armor_dismissed_v1';
  static const _mapAvailableDismissedKey = 'notice_map_available_dismissed_v1';
  late MapLayer _layer;
  late final AnimationController _pulse;
  late final Future<MapCatalog> _catalogFuture;
  bool _abyssNoticeOpen = false;
  bool _mapAvailableNoticeOpen = false;
  Future<Map<String, _MarkerPresentation>>? _presentationsFuture;
  String? _presentationLanguage;

  @override
  void initState() {
    super.initState();
    final persisted = LocalStorage.getString(_layerKey);
    _layer =
        widget.request?.focus.preferredLayer ?? MapLayer.fromJson(persisted);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _catalogFuture = MapRepository.load();
    if (widget.request != null) {
      LocalStorage.setString(_contextKey, widget.request!.target.id);
    }
    if (widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showInitialNotice());
    }
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showInitialNotice());
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String get _language => Localizations.localeOf(context).languageCode;
  String _t(String en, String es, String ru) => switch (_language) {
    'es' => es,
    'ru' => ru,
    _ => en,
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = _language;
    if (widget.request != null && _presentationLanguage != language) {
      _presentationLanguage = language;
      _presentationsFuture = _loadPresentations(language);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: Text(
          _t('Grounded 2 Map', 'Mapa de Grounded 2', 'Карта Grounded 2'),
        ),
      ),
      body: FutureBuilder<MapCatalog>(
        future: _catalogFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                '${_t('Could not load map', 'No se pudo cargar el mapa', 'Не удалось загрузить карту')}: ${snapshot.error}',
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final catalog = snapshot.data!;
          final filtered = visibleMapMarkersForRequest(
            catalog.markers,
            widget.request,
          );
          final current = filtered
              .where((marker) => marker.layer == _layer)
              .toList(growable: false);
          final otherLayer = _layer == MapLayer.surface
              ? MapLayer.abyss
              : MapLayer.surface;
          final otherCount = filtered
              .where((marker) => marker.layer == otherLayer)
              .length;
          if (otherCount > 0 &&
              widget.request != null &&
              !_pulse.isAnimating &&
              _pulse.value == 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _pulse.forward();
            });
          }
          return Column(
            children: [
              if (widget.request == null) _buildGeneralMapNotice(),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _layerButton(MapLayer.surface, filtered, catalog),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _layerButton(MapLayer.abyss, filtered, catalog),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<Map<String, _MarkerPresentation>>(
                  future: _presentationsFuture,
                  builder: (context, presentations) => _MapCanvas(
                    definition: catalog.maps[_layer]!,
                    markers: current,
                    presentations:
                        presentations.data ??
                        const <String, _MarkerPresentation>{},
                    focusResults: widget.request != null,
                    onMarkerTap: _showMarker,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _layerButton(
    MapLayer layer,
    List<LocationRecord> filtered,
    MapCatalog catalog,
  ) {
    final exists = catalog.maps.containsKey(layer);
    final count = filtered.where((marker) => marker.layer == layer).length;
    final button = OutlinedButton.icon(
      onPressed: exists && (widget.request == null || count > 0)
          ? () => _selectLayer(layer)
          : null,
      icon: Icon(layer == MapLayer.surface ? Icons.landscape : Icons.water),
      label: Text(
        widget.request == null
            ? (layer == MapLayer.surface ? 'Surface' : 'Abyss')
            : '${layer == MapLayer.surface ? 'Surface' : 'Abyss'} ($count)',
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: _layer == layer
            ? Theme.of(context).colorScheme.secondaryContainer
            : null,
      ),
    );
    if (layer == _layer || count == 0) return button;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Transform.scale(
        scale: 1 + math.sin(_pulse.value * math.pi) * .06,
        child: child,
      ),
      child: button,
    );
  }

  Widget _buildGeneralMapNotice() {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.location_off_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _t(
                  'The general map is marker-free for better performance. Open a creature and use View on map to see only its locations.',
                  'El mapa general no muestra marcadores para mejorar el rendimiento. Abre una criatura y usa Ver en mapa para consultar solo sus ubicaciones.',
                  'На общей карте нет маркеров для лучшей производительности. Откройте существо и нажмите «Показать на карте», чтобы увидеть только его места.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectLayer(MapLayer layer) {
    setState(() => _layer = layer);
    LocalStorage.setString(_layerKey, layer.id);
    if (layer == MapLayer.abyss) _showAbyssNotice();
  }

  Future<void> _showInitialNotice() async {
    if (widget.request == null) {
      await _showMapAvailableNotice();
    }
    if (mounted && _layer == MapLayer.abyss) {
      await _showAbyssNotice();
    }
  }

  Future<void> _showMapAvailableNotice() async {
    if (!mounted ||
        _mapAvailableNoticeOpen ||
        LocalStorage.getBool(_mapAvailableDismissedKey)) {
      return;
    }
    _mapAvailableNoticeOpen = true;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.map_outlined),
        title: Text(
          _t(
            'The map is now available',
            'El mapa ya está disponible',
            'Карта теперь доступна',
          ),
        ),
        content: Text(
          _t(
            'Explore Surface and Abyss here. To keep the app fast, locations appear separately when you open a creature and choose View on map.',
            'Explora Surface y Abyss desde esta ventana. Para mantener la app fluida, las ubicaciones aparecen por separado al abrir una criatura y elegir Ver en mapa.',
            'Здесь можно исследовать Поверхность и Бездну. Для быстрой работы приложения места показываются отдельно: откройте существо и выберите «Показать на карте».',
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () async {
              await LocalStorage.setBool(_mapAvailableDismissedKey, true);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: Text(_t('Got it', 'Entendido', 'Понятно')),
          ),
        ],
      ),
    );
    _mapAvailableNoticeOpen = false;
  }

  Future<void> _showAbyssNotice() async {
    if (!mounted ||
        _abyssNoticeOpen ||
        LocalStorage.getBool(_abyssDismissedKey)) {
      return;
    }
    _abyssNoticeOpen = true;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Expanded(child: Text('Traje de buceo requerido')),
            IconButton(
              tooltip: _t(
                'Do not show again',
                'No volver a mostrar',
                'Больше не показывать',
              ),
              onPressed: () async {
                await LocalStorage.setBool(_abyssDismissedKey, true);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        content: Text(
          _t(
            'The Abyss requires diving equipment.',
            'El Abyss requiere equipo de buceo.',
            'Для Бездны требуется водолазное снаряжение.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const EquipmentLibraryScreen(
                    initialEquipmentId: 'DivingArmor',
                  ),
                ),
              );
            },
            child: Text(
              _t(
                'View diving suit',
                'Ver traje de buceo',
                'Показать водолазный костюм',
              ),
            ),
          ),
        ],
      ),
    );
    _abyssNoticeOpen = false;
  }

  Future<void> _showMarker(LocationRecord marker) async {
    final language = _language;
    String title;
    String image = '';
    String actionLabel;
    VoidCallback? action;
    switch (marker.targetType) {
      case MapTargetType.creature:
        final entries = await EnemyRepository.loadGame('g2', language);
        final entry = entries.cast<EnemyIndexEntry?>().firstWhere(
          (item) => item?.id == marker.targetId,
          orElse: () => null,
        );
        title = entry?.name ?? _t('Creature', 'Criatura', 'Существо');
        image = entry == null
            ? EntityAssetResolver.creatureCardFallback
            : EntityAssetResolver.resolveEnemyIndex(
                entry,
                EntityAssetUsage.card,
              ).asset;
        actionLabel = _t('View creature', 'Ver criatura', 'Открыть существо');
        if (entry != null) {
          action = () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => EnemyDetailScreen(summary: entry),
            ),
          );
        }
        break;
      case MapTargetType.equipment:
        final catalog = await EquipmentRepository.load();
        final item = catalog.items.cast<EquipmentItem?>().firstWhere(
          (value) => value?.id == marker.targetId,
          orElse: () => null,
        );
        title =
            item?.name.resolve(language) ??
            _t('Equipment', 'Equipo', 'Снаряжение');
        image = item == null
            ? EntityAssetResolver.equipmentFallback
            : EntityAssetResolver.resolveEquipment(item).asset;
        actionLabel = _t('View equipment', 'Ver equipo', 'Открыть снаряжение');
        if (item != null) {
          action = () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  EquipmentLibraryScreen(initialEquipmentId: item.id),
            ),
          );
        }
        break;
      case MapTargetType.defense:
        final defenses = await DefenseRepository.load();
        final defense = defenses.cast<DefenseDetail?>().firstWhere(
          (value) =>
              value?.variants.any((row) => row.id == marker.targetId) == true,
          orElse: () => null,
        );
        final event = defense?.variants.cast<DefenseVariant?>().firstWhere(
          (value) => value?.id == marker.targetId,
          orElse: () => null,
        );
        title =
            event?.name.resolve(language) ??
            _t('Defense', 'Defensa', 'Оборона');
        image = event == null
            ? ''
            : event.markerAsset.isNotEmpty
            ? event.markerAsset
            : event.image;
        actionLabel = _t('View defense', 'Ver defensa', 'Открыть оборону');
        if (defense != null) {
          action = () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => DefenseDetailScreen(defenseId: defense.id),
            ),
          );
        }
        break;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox.square(
                    dimension: 64,
                    child: image.isEmpty
                        ? const Icon(Icons.location_on, size: 40)
                        : Image.asset(
                            image,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.location_on, size: 40),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${_t('Appearance', 'Aparición', 'Появление')}: ${_appearanceLabel(marker.type)}',
              ),
              Text(
                '${_t('Layer', 'Capa', 'Слой')}: ${marker.layer == MapLayer.surface ? 'Surface' : 'Abyss'}',
              ),
              if (marker.conditional)
                Text(
                  _t(
                    'Locked by story progress',
                    'Bloqueado por progreso de historia',
                    'Заблокировано прогрессом сюжета',
                  ),
                ),
              if (action != null) ...[
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    action!();
                  },
                  child: Text(actionLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _appearanceLabel(String type) => switch (type) {
    'story_locked' => _t(
      'Story-related',
      'Relacionado con historia',
      'Сюжетное',
    ),
    'physical_pickup' => _t(
      'Fixed pickup',
      'Recogida fija',
      'Фиксированный предмет',
    ),
    'mixr' || 'defense' => 'MIX.R',
    _ => _t('Natural', 'Natural', 'Естественное'),
  };

  Future<Map<String, _MarkerPresentation>> _loadPresentations(
    String language,
  ) async {
    switch (widget.request?.target.type) {
      case MapTargetType.creature:
        final creatures = await EnemyRepository.loadGame('g2', language);
        return {
          for (final creature in creatures)
            _presentationKey(
              MapTargetType.creature,
              creature.id,
            ): _MarkerPresentation(
              name: creature.name,
              image: mapCreatureCardAsset(creature),
            ),
        };
      case MapTargetType.defense:
        final defenses = await DefenseRepository.load();
        return {
          for (final defense in defenses)
            for (final variant in defense.variants)
              _presentationKey(
                MapTargetType.defense,
                variant.id,
              ): _MarkerPresentation(
                name: variant.name.resolve(language),
                image: variant.markerAsset.isNotEmpty
                    ? variant.markerAsset
                    : variant.image,
              ),
        };
      case MapTargetType.equipment:
        final equipment = await EquipmentRepository.load();
        return {
          for (final item in equipment.items)
            _presentationKey(
              MapTargetType.equipment,
              item.id,
            ): _MarkerPresentation(
              name: item.name.resolve(language),
              image: EntityAssetResolver.resolveEquipment(item).asset,
            ),
        };
      case null:
        return const <String, _MarkerPresentation>{};
    }
  }
}

@visibleForTesting
String mapCreatureCardAsset(EnemyIndexEntry creature) =>
    EntityAssetResolver.resolveEnemyIndex(
      creature,
      EntityAssetUsage.card,
    ).asset;

@visibleForTesting
List<LocationRecord> visibleMapMarkersForRequest(
  List<LocationRecord> markers,
  MapOpenRequest? request,
) {
  if (request == null) {
    return const <LocationRecord>[];
  }
  final targetId = request.target.id;
  final targetType = request.target.type;
  final filter = request.filter;
  return markers
      .where((marker) {
        if (marker.targetType != targetType || marker.targetId != targetId) {
          return false;
        }
        if (filter.type != null && marker.targetType != filter.type) {
          return false;
        }
        if (filter.targetId != null && marker.targetId != filter.targetId) {
          return false;
        }
        return true;
      })
      .toList(growable: false);
}

String _presentationKey(MapTargetType type, String id) => '${type.name}:$id';

@visibleForTesting
Widget buildMapCanvasForTesting({
  required MapDefinition definition,
  required List<LocationRecord> markers,
  required ValueChanged<LocationRecord> onMarkerTap,
  bool focusResults = true,
}) => _MapCanvas(
  definition: definition,
  markers: markers,
  presentations: const <String, _MarkerPresentation>{},
  focusResults: focusResults,
  onMarkerTap: onMarkerTap,
);

class _MarkerPresentation {
  final String name;
  final String image;

  const _MarkerPresentation({required this.name, required this.image});
}

class _MapCanvas extends StatefulWidget {
  const _MapCanvas({
    required this.definition,
    required this.markers,
    required this.presentations,
    required this.focusResults,
    required this.onMarkerTap,
  });
  final MapDefinition definition;
  final List<LocationRecord> markers;
  final Map<String, _MarkerPresentation> presentations;
  final bool focusResults;
  final ValueChanged<LocationRecord> onMarkerTap;

  @override
  State<_MapCanvas> createState() => _MapCanvasState();
}

class _MapCanvasState extends State<_MapCanvas> {
  final TransformationController _controller = TransformationController();
  String? _appliedFocus;
  int _zoomBucket = 0;
  bool _renderScheduled = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTransformChanged);
  }

  void _onTransformChanged() {
    final bucket =
        (math.log(math.max(_controller.value.getMaxScaleOnAxis(), .01)) /
                math.ln2)
            .floor();
    if (bucket != _zoomBucket) _zoomBucket = bucket;
    if (_renderScheduled || !mounted) return;
    _renderScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _renderScheduled = false;
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTransformChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        final texture = widget.definition.textureSize;
        final fitScale = math.min(
          viewport.width / texture.width,
          viewport.height / texture.height,
        );
        final centeredFitMargin = math.max(
          0,
          math.max(
            (viewport.width / fitScale - texture.width) / 2,
            (viewport.height / fitScale - texture.height) / 2,
          ),
        );
        final interactionMargin = math.max(
          math.max(texture.width, texture.height) * .2,
          centeredFitMargin + 48 / fitScale,
        );
        final relativeZoom = math.max(
          1,
          _controller.value.getMaxScaleOnAxis() / fitScale,
        );
        final mode = relativeZoom <= 2.2
            ? _MapRenderMode.clusters
            : relativeZoom <= 5.5
            ? _MapRenderMode.pointers
            : _MapRenderMode.cards;
        final visibleBounds = MapViewportTransform.visibleNormalizedBounds(
          transform: _controller.value,
          viewport: viewport,
          texture: texture,
          overscan: mode == _MapRenderMode.cards ? .035 : .02,
        );
        final visibleMarkers = mode == _MapRenderMode.clusters
            ? widget.markers
            : MapRepository.cull(widget.markers, visibleBounds);
        final clusters =
            MapRepository.cluster(
                  visibleMarkers,
                  cellSize: switch (mode) {
                    _MapRenderMode.clusters => (.12 / relativeZoom).clamp(
                      .045,
                      .12,
                    ),
                    _MapRenderMode.pointers => (.045 / relativeZoom).clamp(
                      .012,
                      .03,
                    ),
                    _MapRenderMode.cards => (.022 / relativeZoom).clamp(
                      .0018,
                      .006,
                    ),
                  },
                )
                .where(
                  (cluster) =>
                      visibleBounds.contains(Offset(cluster.u, cluster.v)),
                )
                .toList(growable: false);
        _scheduleFocus(viewport);
        return ColoredBox(
          color: Colors.black,
          child: InteractiveViewer(
            key: const ValueKey('map-interactive-viewer'),
            constrained: false,
            panEnabled: true,
            scaleEnabled: true,
            clipBehavior: Clip.hardEdge,
            minScale: fitScale,
            maxScale: fitScale * 12,
            boundaryMargin: EdgeInsets.all(interactionMargin),
            transformationController: _controller,
            child: SizedBox(
              width: texture.width,
              height: texture.height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      widget.definition.texture,
                      fit: BoxFit.contain,
                    ),
                  ),
                  for (final cluster in clusters)
                    _positionedMarker(cluster, mode, texture, viewport),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _positionedMarker(
    MapCluster cluster,
    _MapRenderMode mode,
    Size texture,
    Size viewport,
  ) {
    final isCluster =
        mode == _MapRenderMode.clusters || cluster.markers.length > 1;
    final width = mode == _MapRenderMode.cards && !isCluster ? 140.0 : 48.0;
    final height = mode == _MapRenderMode.cards && !isCluster ? 82.0 : 48.0;
    final left = cluster.u * texture.width - width / 2;
    final top =
        cluster.v * texture.height -
        (mode == _MapRenderMode.cards && !isCluster ? 70 : height / 2);
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: isCluster
          ? _MapClusterMarker(
              count: cluster.markers.length,
              onTap: () => _zoomToCluster(cluster, viewport),
            )
          : mode == _MapRenderMode.cards
          ? _MapMiniCardMarker(
              presentation:
                  widget.presentations[_presentationKey(
                    cluster.markers.single.targetType,
                    cluster.markers.single.targetId,
                  )],
              onTap: () => widget.onMarkerTap(cluster.markers.single),
            )
          : _MapPointerMarker(
              onTap: () => widget.onMarkerTap(cluster.markers.single),
            ),
    );
  }

  void _scheduleFocus(Size viewport) {
    final key =
        '${viewport.width}:${viewport.height}:${widget.definition.layer.id}:'
        '${widget.markers.map((item) => item.id).join(',')}';
    if (_appliedFocus == key) return;
    _appliedFocus = key;
    final bounds = widget.focusResults && widget.markers.isNotEmpty
        ? MapViewportTransform.boundsFor(widget.markers)
        : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.value = MapViewportTransform.frame(
        viewport: viewport,
        texture: widget.definition.textureSize,
        normalizedBounds: bounds,
      );
    });
  }

  void _zoomToCluster(MapCluster cluster, Size viewport) {
    _controller.value = MapViewportTransform.frame(
      viewport: viewport,
      texture: widget.definition.textureSize,
      normalizedBounds: MapViewportTransform.boundsFor(cluster.markers),
      padding: 70,
    );
  }
}

enum _MapRenderMode { clusters, pointers, cards }

class _MapClusterMarker extends StatelessWidget {
  const _MapClusterMarker({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$count markers',
    child: GestureDetector(
      key: const ValueKey('map-cluster-marker'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.cyan.shade300,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black, width: 2),
            boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black54)],
          ),
          alignment: Alignment.center,
          child: Text(
            '$count',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
        ),
      ),
    ),
  );
}

class _MapPointerMarker extends StatelessWidget {
  const _MapPointerMarker({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Map marker',
    child: GestureDetector(
      key: const ValueKey('map-pointer-marker'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: const Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.amber,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black54)],
          ),
          child: Padding(
            padding: EdgeInsets.all(6),
            child: Icon(Icons.location_on, size: 24, color: Colors.black),
          ),
        ),
      ),
    ),
  );
}

class _MapMiniCardMarker extends StatelessWidget {
  const _MapMiniCardMarker({required this.presentation, required this.onTap});

  final _MarkerPresentation? presentation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final data = presentation;
    return Semantics(
      button: true,
      label: data?.name ?? 'Map marker',
      child: GestureDetector(
        key: const ValueKey('map-mini-card-marker'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(10),
              color: Theme.of(context).colorScheme.surface,
              child: SizedBox(
                height: 58,
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Row(
                    children: [
                      SizedBox.square(
                        dimension: 46,
                        child: Image.asset(
                          data?.image ??
                              EntityAssetResolver.creatureCardFallback,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.pest_control),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          data?.name ?? 'Marker',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Icon(Icons.location_on, size: 24, color: Colors.amber),
          ],
        ),
      ),
    );
  }
}
