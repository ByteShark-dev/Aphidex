import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/defense_event.dart';
import '../models/equipment.dart';
import '../models/location.dart';

class EquipmentRepository {
  static Future<EquipmentCatalog>? _cache;

  static Future<EquipmentCatalog> load() => _cache ??= _load();

  static Future<EquipmentCatalog> _load() async {
    final raw = await rootBundle.loadString('assets/data/g2/equipment.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return EquipmentCatalog(
      items: (json['items'] as List)
          .whereType<Map>()
          .map((item) => EquipmentItem.fromJson(item.cast<String, dynamic>()))
          .toList(growable: false),
      armorSets: (json['armorSets'] as List)
          .whereType<Map>()
          .map((item) => ArmorSet.fromJson(item.cast<String, dynamic>()))
          .toList(growable: false),
    );
  }

  static void clearCache() => _cache = null;
}

class MapRepository {
  static Future<MapCatalog>? _cache;

  static Future<MapCatalog> load() => _cache ??= _load();

  static Future<MapCatalog> _load() async {
    final raw = await rootBundle.loadString('assets/data/g2/map.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final rawMaps = (json['maps'] as Map).cast<String, dynamic>();
    final maps = {
      for (final entry in rawMaps.entries)
        MapLayer.fromJson(entry.key): MapDefinition.fromJson(
          (entry.value as Map).cast<String, dynamic>(),
        ),
    };
    return MapCatalog(
      maps: maps,
      markers: (json['markers'] as List)
          .whereType<Map>()
          .map((item) {
            final value = item.cast<String, dynamic>();
            final layer = MapLayer.fromJson(value['map']);
            return LocationRecord.fromJson(
              value,
              transform: maps[layer]!.coordinateTransform,
            );
          })
          .toList(growable: false),
    );
  }

  static List<MapCluster> cluster(
    List<LocationRecord> markers, {
    double cellSize = 0.035,
  }) {
    final buckets = <String, List<LocationRecord>>{};
    for (final marker in markers) {
      final x = (marker.u / cellSize).floor();
      final y = (marker.v / cellSize).floor();
      buckets.putIfAbsent('$x:$y', () => []).add(marker);
    }
    return buckets.values
        .map((items) {
          final u =
              items.fold<double>(0, (sum, item) => sum + item.u) / items.length;
          final v =
              items.fold<double>(0, (sum, item) => sum + item.v) / items.length;
          return MapCluster(u: u, v: v, markers: items);
        })
        .toList(growable: false);
  }

  static List<LocationRecord> cull(
    Iterable<LocationRecord> markers,
    Rect visibleBounds,
  ) => markers
      .where((marker) => visibleBounds.contains(Offset(marker.u, marker.v)))
      .toList(growable: false);

  static void clearCache() => _cache = null;
}

class MixrRepository {
  static Future<List<DefenseEvent>>? _cache;

  static Future<List<DefenseEvent>> load() => _cache ??= _load();

  static Future<List<DefenseEvent>> _load() async {
    final raw = await rootBundle.loadString('assets/data/g2/mixr.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return (json['variants'] as List)
        .whereType<Map>()
        .map((item) => DefenseEvent.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  static void clearCache() => _cache = null;
}

class DefenseRepository {
  static Future<List<DefenseDetail>>? _cache;

  static Future<List<DefenseDetail>> load() => _cache ??= _load();

  static Future<List<DefenseDetail>> _load() async {
    final raw = await rootBundle.loadString('assets/data/g2/defenses.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return (json['entries'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => DefenseDetail.fromJson(row.cast<String, dynamic>()))
        .toList(growable: false);
  }

  static Future<DefenseDetail?> find(String id) async {
    final entries = await load();
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  static void clearCache() => _cache = null;
}
