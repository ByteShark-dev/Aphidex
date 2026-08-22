import 'dart:math' as math;

import 'package:flutter/material.dart';

enum MapLayer {
  surface,
  abyss;

  static MapLayer fromJson(Object? value) =>
      value == 'abyss' ? MapLayer.abyss : MapLayer.surface;

  String get id => name;
}

enum MapTargetType { creature, equipment, defense }

class EnvironmentHazard {
  final String type;
  final String? equipmentId;

  const EnvironmentHazard({required this.type, this.equipmentId});

  factory EnvironmentHazard.fromJson(Map<String, dynamic> json) =>
      EnvironmentHazard(
        type: json['type']?.toString() ?? 'unknown',
        equipmentId: json['equipmentId']?.toString(),
      );
}

class LocationRecord {
  final String id;
  final MapTargetType targetType;
  final String targetId;
  final String? technicalId;
  final MapLayer layer;
  final double u;
  final double v;
  final Offset? worldPosition;
  final String type;
  final bool conditional;
  final List<EnvironmentHazard> environmentHazards;

  const LocationRecord({
    required this.id,
    required this.targetType,
    required this.targetId,
    this.technicalId,
    required this.layer,
    required this.u,
    required this.v,
    this.worldPosition,
    required this.type,
    required this.conditional,
    this.environmentHazards = const [],
  });

  factory LocationRecord.fromJson(
    Map<String, dynamic> json, {
    MapCoordinateTransform? transform,
  }) {
    final rawType = json['targetType']?.toString();
    final rawWorld = json['world'] as Map?;
    final world = rawWorld == null
        ? null
        : Offset(
            (rawWorld['x'] as num).toDouble(),
            (rawWorld['y'] as num).toDouble(),
          );
    final normalized = world != null && transform != null
        ? transform.worldToNormalized(world)
        : Offset(
            (json['u'] as num?)?.toDouble() ?? 0,
            (json['v'] as num?)?.toDouble() ?? 0,
          );
    if (!MapCoordinateTransform.isRepresentable(normalized)) {
      throw FormatException(
        'Map marker ${json['id']} is outside represented bounds',
      );
    }
    return LocationRecord(
      id: json['id']?.toString() ?? '',
      targetType: switch (rawType) {
        'equipment' => MapTargetType.equipment,
        'defense' => MapTargetType.defense,
        _ => MapTargetType.creature,
      },
      targetId: json['targetId']?.toString() ?? '',
      technicalId: json['technicalId']?.toString(),
      layer: MapLayer.fromJson(json['map']),
      u: normalized.dx,
      v: normalized.dy,
      worldPosition: world,
      type: json['type']?.toString() ?? 'spawn',
      conditional: json['conditional'] == true,
      environmentHazards: (json['environmentHazards'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => EnvironmentHazard.fromJson(item.cast<String, dynamic>()),
          )
          .toList(growable: false),
    );
  }
}

class MapCoordinateTransform {
  final Rect worldBounds;
  final Size sourceTextureSize;
  final Rect contentPixelBounds;

  const MapCoordinateTransform({
    required this.worldBounds,
    required this.sourceTextureSize,
    required this.contentPixelBounds,
  });

  Offset worldToNormalized(Offset world) {
    final sourceX =
        ((world.dx - worldBounds.left) / worldBounds.width) *
        sourceTextureSize.width;
    final sourceY =
        ((world.dy - worldBounds.top) / worldBounds.height) *
        sourceTextureSize.height;
    return Offset(
      (sourceX - contentPixelBounds.left) / contentPixelBounds.width,
      (sourceY - contentPixelBounds.top) / contentPixelBounds.height,
    );
  }

  static bool isRepresentable(Offset position) =>
      position.dx >= 0 &&
      position.dx <= 1 &&
      position.dy >= 0 &&
      position.dy <= 1;
}

class MapDefinition {
  final MapLayer layer;
  final String texture;
  final List<EnvironmentHazard> hazards;
  final Size textureSize;
  final MapCoordinateTransform coordinateTransform;

  const MapDefinition({
    required this.layer,
    required this.texture,
    required this.textureSize,
    required this.coordinateTransform,
    this.hazards = const [],
  });

  factory MapDefinition.fromJson(Map<String, dynamic> json) {
    final world = (json['worldBounds'] as Map).cast<String, dynamic>();
    final source = (json['sourceTextureSize'] as Map).cast<String, dynamic>();
    final content = (json['contentPixelBounds'] as Map).cast<String, dynamic>();
    final texture = (json['textureSize'] as Map).cast<String, dynamic>();
    return MapDefinition(
      layer: MapLayer.fromJson(json['id']),
      texture: json['texture']?.toString() ?? '',
      textureSize: Size(
        (texture['width'] as num).toDouble(),
        (texture['height'] as num).toDouble(),
      ),
      coordinateTransform: MapCoordinateTransform(
        worldBounds: Rect.fromLTRB(
          (world['minX'] as num).toDouble(),
          (world['minY'] as num).toDouble(),
          (world['maxX'] as num).toDouble(),
          (world['maxY'] as num).toDouble(),
        ),
        sourceTextureSize: Size(
          (source['width'] as num).toDouble(),
          (source['height'] as num).toDouble(),
        ),
        contentPixelBounds: Rect.fromLTWH(
          (content['x'] as num).toDouble(),
          (content['y'] as num).toDouble(),
          (content['width'] as num).toDouble(),
          (content['height'] as num).toDouble(),
        ),
      ),
      hazards: (json['hazards'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => EnvironmentHazard.fromJson(item.cast<String, dynamic>()),
          )
          .toList(growable: false),
    );
  }
}

class MapViewportTransform {
  const MapViewportTransform._();

  static Matrix4 frame({
    required Size viewport,
    required Size texture,
    Rect? normalizedBounds,
    double padding = 48,
  }) {
    final fitScale = math.min(
      viewport.width / texture.width,
      viewport.height / texture.height,
    );
    final bounds = normalizedBounds;
    var scale = fitScale;
    var center = Offset(texture.width / 2, texture.height / 2);
    if (bounds != null) {
      final pixelBounds = Rect.fromLTRB(
        bounds.left * texture.width,
        bounds.top * texture.height,
        bounds.right * texture.width,
        bounds.bottom * texture.height,
      );
      final safeWidth = math.max(pixelBounds.width, texture.width * .035);
      final safeHeight = math.max(pixelBounds.height, texture.height * .035);
      scale = math
          .min(
            (viewport.width - padding * 2) / safeWidth,
            (viewport.height - padding * 2) / safeHeight,
          )
          .clamp(fitScale, fitScale * 10);
      center = pixelBounds.center;
    }
    return Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(2, 2, scale)
      ..setEntry(0, 3, viewport.width / 2 - center.dx * scale)
      ..setEntry(1, 3, viewport.height / 2 - center.dy * scale);
  }

  static Rect boundsFor(Iterable<LocationRecord> markers) {
    final values = markers.toList(growable: false);
    if (values.isEmpty) return Rect.zero;
    return Rect.fromLTRB(
      values.map((item) => item.u).reduce(math.min),
      values.map((item) => item.v).reduce(math.min),
      values.map((item) => item.u).reduce(math.max),
      values.map((item) => item.v).reduce(math.max),
    );
  }

  static Rect visibleNormalizedBounds({
    required Matrix4 transform,
    required Size viewport,
    required Size texture,
    double overscan = .025,
  }) {
    final inverse = Matrix4.copy(transform);
    if (inverse.invert() == 0) return const Rect.fromLTWH(0, 0, 1, 1);
    final topLeft = MatrixUtils.transformPoint(inverse, Offset.zero);
    final bottomRight = MatrixUtils.transformPoint(
      inverse,
      Offset(viewport.width, viewport.height),
    );
    final normalized = Rect.fromLTRB(
      math.min(topLeft.dx, bottomRight.dx) / texture.width,
      math.min(topLeft.dy, bottomRight.dy) / texture.height,
      math.max(topLeft.dx, bottomRight.dx) / texture.width,
      math.max(topLeft.dy, bottomRight.dy) / texture.height,
    ).inflate(overscan);
    return normalized.intersect(const Rect.fromLTWH(0, 0, 1, 1));
  }
}

class MapCatalog {
  final Map<MapLayer, MapDefinition> maps;
  final List<LocationRecord> markers;

  const MapCatalog({required this.maps, required this.markers});
}

class MapTarget {
  final MapTargetType type;
  final String id;

  const MapTarget(this.type, this.id);
}

class MapFilter {
  final MapTargetType? type;
  final String? targetId;

  const MapFilter({this.type, this.targetId});
}

class MapFocus {
  final MapLayer? preferredLayer;
  final bool highlightAll;

  const MapFocus({this.preferredLayer, this.highlightAll = true});
}

class MapOpenRequest {
  final MapTarget target;
  final MapFilter filter;
  final MapFocus focus;

  const MapOpenRequest({
    required this.target,
    required this.filter,
    required this.focus,
  });
}

@immutable
class MapCluster {
  final double u;
  final double v;
  final List<LocationRecord> markers;

  const MapCluster({required this.u, required this.v, required this.markers});
}
