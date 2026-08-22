import 'equipment.dart';
import 'location.dart';

class ScheduledCreature {
  final String technicalId;
  final String? publicId;
  final int count;

  const ScheduledCreature({
    required this.technicalId,
    this.publicId,
    required this.count,
  });

  factory ScheduledCreature.fromJson(Map<String, dynamic> json) =>
      ScheduledCreature(
        technicalId: json['technicalId']?.toString() ?? '',
        publicId: json['publicId']?.toString(),
        count: json['count'] as int? ?? 0,
      );
}

class ScheduledGroup {
  final int sourceIndex;
  final int displayOrdinal;
  final double? timeSeconds;
  final int? declaredScheduledCreatures;
  final String compositionStatus;
  final List<ScheduledCreature> creatures;

  const ScheduledGroup({
    required this.sourceIndex,
    required this.displayOrdinal,
    this.timeSeconds,
    this.declaredScheduledCreatures,
    this.compositionStatus = 'complete',
    required this.creatures,
  });

  factory ScheduledGroup.fromJson(Map<String, dynamic> json) => ScheduledGroup(
    sourceIndex: json['index'] as int? ?? 0,
    displayOrdinal: json['displayOrdinal'] as int? ?? 0,
    timeSeconds: (json['timeSeconds'] as num?)?.toDouble(),
    declaredScheduledCreatures: json['declaredScheduledCreatures'] as int?,
    compositionStatus: json['compositionStatus']?.toString() ?? 'complete',
    creatures: (json['creatures'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => ScheduledCreature.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false),
  );
}

class DefenseEvent {
  final String id;
  final String mixrId;
  final EquipmentLabel name;
  final String difficulty;
  final int totalCreatures;
  final LocationRecord location;
  final List<ScheduledGroup> groups;
  final String image;
  final String imageStatus;

  const DefenseEvent({
    required this.id,
    required this.mixrId,
    required this.name,
    required this.difficulty,
    required this.totalCreatures,
    required this.location,
    required this.groups,
    required this.image,
    required this.imageStatus,
  });

  factory DefenseEvent.fromJson(Map<String, dynamic> json) {
    final location = (json['location'] as Map? ?? const {})
        .cast<String, dynamic>();
    return DefenseEvent(
      id: json['id']?.toString() ?? '',
      mixrId: json['mixrId']?.toString() ?? '',
      name: EquipmentLabel.fromJson(json['name']),
      difficulty: json['difficulty']?.toString() ?? 'unknown',
      totalCreatures: json['totalCreatures'] as int? ?? 0,
      location: LocationRecord(
        id: '${json['id']}_location',
        targetType: MapTargetType.defense,
        targetId: json['id']?.toString() ?? '',
        layer: MapLayer.fromJson(location['map']),
        u: (location['u'] as num?)?.toDouble() ?? 0,
        v: (location['v'] as num?)?.toDouble() ?? 0,
        type: 'mixr',
        conditional: false,
      ),
      groups: (json['scheduledGroups'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => ScheduledGroup.fromJson(item.cast<String, dynamic>()))
          .toList(growable: false),
      image: json['image']?.toString() ?? '',
      imageStatus: json['imageStatus']?.toString() ?? 'missing',
    );
  }
}

class DefenseAttacker {
  final String technicalId;
  final String? publicId;
  final int count;

  const DefenseAttacker({
    required this.technicalId,
    this.publicId,
    required this.count,
  });

  factory DefenseAttacker.fromJson(Map<String, dynamic> json) =>
      DefenseAttacker(
        technicalId: json['technicalId']?.toString() ?? '',
        publicId: json['publicId']?.toString(),
        count: json['count'] as int? ?? 0,
      );
}

class DefenseRewardItem {
  final String id;
  final int? quantity;

  const DefenseRewardItem({required this.id, this.quantity});

  factory DefenseRewardItem.fromJson(Map<String, dynamic> json) =>
      DefenseRewardItem(
        id: json['id']?.toString() ?? '',
        quantity: json['quantity'] as int?,
      );
}

class DefenseMutationProgress {
  final String id;
  final num? amount;

  const DefenseMutationProgress({required this.id, this.amount});

  factory DefenseMutationProgress.fromJson(Map<String, dynamic> json) =>
      DefenseMutationProgress(
        id: json['id']?.toString() ?? '',
        amount: json['amount'] as num?,
      );
}

class DefenseRewards {
  final int? rawScience;
  final List<DefenseRewardItem> equipment;
  final List<DefenseRewardItem> recipes;
  final List<DefenseMutationProgress> mutationProgress;

  const DefenseRewards({
    this.rawScience,
    this.equipment = const [],
    this.recipes = const [],
    this.mutationProgress = const [],
  });

  factory DefenseRewards.fromJson(Map<String, dynamic> json) => DefenseRewards(
    rawScience: json['rawScience'] as int?,
    equipment: (json['equipment'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => DefenseRewardItem.fromJson(row.cast<String, dynamic>()))
        .toList(growable: false),
    recipes: (json['recipes'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => DefenseRewardItem.fromJson(row.cast<String, dynamic>()))
        .toList(growable: false),
    mutationProgress: (json['mutationProgress'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (row) =>
              DefenseMutationProgress.fromJson(row.cast<String, dynamic>()),
        )
        .toList(growable: false),
  );
}

class DefenseVariant {
  final String id;
  final EquipmentLabel name;
  final String? difficulty;
  final int totalCreatures;
  final LocationRecord location;
  final List<ScheduledGroup> groups;
  final List<DefenseAttacker> attackers;
  final DefenseRewards rewards;
  final String image;
  final String markerAsset;
  final String imageStatus;

  const DefenseVariant({
    required this.id,
    required this.name,
    this.difficulty,
    required this.totalCreatures,
    required this.location,
    required this.groups,
    required this.attackers,
    required this.rewards,
    required this.image,
    this.markerAsset = '',
    required this.imageStatus,
  });

  factory DefenseVariant.fromJson(Map<String, dynamic> json) {
    final location = (json['location'] as Map? ?? const {})
        .cast<String, dynamic>();
    return DefenseVariant(
      id: json['id']?.toString() ?? '',
      name: EquipmentLabel.fromJson(json['name']),
      difficulty: json['difficulty']?.toString(),
      totalCreatures: json['totalCreatures'] as int? ?? 0,
      location: LocationRecord(
        id: '${json['id']}_location',
        targetType: MapTargetType.defense,
        targetId: json['id']?.toString() ?? '',
        layer: MapLayer.fromJson(location['map']),
        u: (location['u'] as num?)?.toDouble() ?? 0,
        v: (location['v'] as num?)?.toDouble() ?? 0,
        type: 'defense',
        conditional: false,
      ),
      groups: (json['scheduledGroups'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => ScheduledGroup.fromJson(row.cast<String, dynamic>()))
          .toList(growable: false),
      attackers: (json['attackers'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => DefenseAttacker.fromJson(row.cast<String, dynamic>()))
          .toList(growable: false),
      rewards: DefenseRewards.fromJson(
        (json['rewards'] as Map? ?? const {}).cast<String, dynamic>(),
      ),
      image: json['image']?.toString() ?? '',
      markerAsset: json['markerAsset']?.toString() ?? '',
      imageStatus: json['imageStatus']?.toString() ?? 'missing',
    );
  }
}

class DefenseDetail {
  final String id;
  final String kind;
  final String customAsset;
  final List<DefenseVariant> variants;

  const DefenseDetail({
    required this.id,
    required this.kind,
    required this.customAsset,
    required this.variants,
  });

  factory DefenseDetail.fromJson(Map<String, dynamic> json) => DefenseDetail(
    id: json['id']?.toString() ?? '',
    kind: json['kind']?.toString() ?? 'defense',
    customAsset: json['customAsset']?.toString() ?? '',
    variants: (json['variants'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => DefenseVariant.fromJson(row.cast<String, dynamic>()))
        .toList(growable: false),
  );
}
