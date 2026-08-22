import 'location.dart';

class EquipmentLabel {
  final String en;
  final String es;
  final String ru;

  const EquipmentLabel({required this.en, required this.es, required this.ru});

  factory EquipmentLabel.fromJson(Object? raw) {
    final json = raw is Map
        ? raw.cast<String, dynamic>()
        : const <String, dynamic>{};
    return EquipmentLabel(
      en: json['en']?.toString() ?? '',
      es: json['es']?.toString() ?? json['en']?.toString() ?? '',
      ru: json['ru']?.toString() ?? json['en']?.toString() ?? '',
    );
  }

  String resolve(String languageCode) => switch (languageCode) {
    'es' => es.isNotEmpty ? es : en,
    'ru' => ru.isNotEmpty ? ru : en,
    _ => en,
  };
}

enum EquipmentDomain { weapon, shield, armor, trinket }

class EquipmentAttack {
  final double? damage;
  final double? chargedDamage;
  final double? stun;
  final double? stamina;
  final double? range;
  final String? physical;
  final String? element;
  final List<EquipmentStatusEffect> statusEffects;

  const EquipmentAttack({
    this.damage,
    this.chargedDamage,
    this.stun,
    this.stamina,
    this.range,
    this.physical,
    this.element,
    this.statusEffects = const [],
  });

  factory EquipmentAttack.fromJson(Map<String, dynamic> json) =>
      EquipmentAttack(
        damage: (json['damage'] as num?)?.toDouble(),
        chargedDamage: (json['chargedDamage'] as num?)?.toDouble(),
        stun: (json['stun'] as num?)?.toDouble(),
        stamina: (json['stamina'] as num?)?.toDouble(),
        range: (json['range'] as num?)?.toDouble(),
        physical: json['physical']?.toString(),
        element: json['element']?.toString(),
        statusEffects: (json['statusEffects'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) =>
                  EquipmentStatusEffect.fromJson(item.cast<String, dynamic>()),
            )
            .toList(growable: false),
      );
}

class EquipmentStatusEffect {
  final String id;
  final String? row;
  final Map<String, dynamic> source;

  const EquipmentStatusEffect({
    required this.id,
    this.row,
    this.source = const {},
  });

  factory EquipmentStatusEffect.fromJson(Map<String, dynamic> json) =>
      EquipmentStatusEffect(
        id: json['id']?.toString() ?? '',
        row: json['row']?.toString(),
        source: (json['source'] as Map? ?? const {}).cast<String, dynamic>(),
      );
}

class EquipmentIngredient {
  final String itemId;
  final int count;

  const EquipmentIngredient({required this.itemId, required this.count});

  factory EquipmentIngredient.fromJson(Map<String, dynamic> json) =>
      EquipmentIngredient(
        itemId: json['itemId']?.toString() ?? '',
        count: (json['count'] as num?)?.round() ?? 0,
      );
}

class EquipmentRecipe {
  final String id;
  final String? station;
  final List<EquipmentIngredient> requirements;
  final List<Object?> unlockSources;

  const EquipmentRecipe({
    required this.id,
    this.station,
    this.requirements = const [],
    this.unlockSources = const [],
  });

  factory EquipmentRecipe.fromJson(Map<String, dynamic> json) =>
      EquipmentRecipe(
        id: json['id']?.toString() ?? '',
        station: json['station']?.toString(),
        requirements: (json['requirements'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) =>
                  EquipmentIngredient.fromJson(item.cast<String, dynamic>()),
            )
            .toList(growable: false),
        unlockSources: List<Object?>.from(
          json['unlockSources'] as List? ?? const [],
        ),
      );
}

class EquipmentAcquisition {
  final String status;
  final List<String> methods;
  final List<EquipmentRecipe> recipes;

  const EquipmentAcquisition({
    required this.status,
    this.methods = const [],
    this.recipes = const [],
  });

  bool get unresolved => status == 'unresolved_acquisition';

  factory EquipmentAcquisition.fromJson(Map<String, dynamic> json) =>
      EquipmentAcquisition(
        status: json['status']?.toString() ?? 'unresolved_acquisition',
        methods: List<String>.from(json['methods'] ?? const []),
        recipes: (json['recipes'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) => EquipmentRecipe.fromJson(item.cast<String, dynamic>()),
            )
            .toList(growable: false),
      );
}

class EquipmentItem {
  final String id;
  final EquipmentDomain domain;
  final EquipmentLabel name;
  final int? tier;
  final String? slot;
  final bool? twoHanded;
  final bool? canBlock;
  final double? durability;
  final String icon;
  final String normalizedType;
  final String normalizedSubtype;
  final String classificationSource;
  final bool classificationFallbackUsed;
  final List<String> effects;
  final List<EquipmentAttack> attacks;
  final List<String> upgradeRoutes;
  final List<EquipmentIngredient> repair;
  final EquipmentAcquisition acquisition;
  final List<LocationRecord> locations;
  final Map<String, dynamic> raw;

  const EquipmentItem({
    required this.id,
    required this.domain,
    required this.name,
    this.tier,
    this.slot,
    this.twoHanded,
    this.canBlock,
    this.durability,
    required this.icon,
    required this.normalizedType,
    required this.normalizedSubtype,
    required this.classificationSource,
    required this.classificationFallbackUsed,
    this.effects = const [],
    this.attacks = const [],
    this.upgradeRoutes = const [],
    this.repair = const [],
    required this.acquisition,
    this.locations = const [],
    required this.raw,
  });

  factory EquipmentItem.fromJson(Map<String, dynamic> json) => EquipmentItem(
    id: json['id']?.toString() ?? '',
    domain: switch (json['domain']) {
      'shield' => EquipmentDomain.shield,
      'armor' => EquipmentDomain.armor,
      'trinket' => EquipmentDomain.trinket,
      _ => EquipmentDomain.weapon,
    },
    name: EquipmentLabel.fromJson(json['name']),
    tier: json['tier'] as int?,
    slot: json['slot']?.toString(),
    twoHanded: json['twoHanded'] as bool?,
    canBlock: json['canBlock'] as bool?,
    durability: (json['durability'] as num?)?.toDouble(),
    icon: json['icon']?.toString() ?? '',
    normalizedType:
        json['normalizedType']?.toString() ??
        json['domain']?.toString() ??
        'special',
    normalizedSubtype: json['normalizedSubtype']?.toString() ?? 'special',
    classificationSource:
        json['classificationSource']?.toString() ?? 'legacy_fallback',
    classificationFallbackUsed:
        json['classificationFallbackUsed'] as bool? ?? true,
    effects: List<String>.from(json['effects'] ?? const []),
    attacks: (json['attacks'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => EquipmentAttack.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false),
    upgradeRoutes: List<String>.from(json['upgradeRoutes'] ?? const []),
    repair: (json['repair'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => EquipmentIngredient.fromJson(item.cast<String, dynamic>()),
        )
        .toList(growable: false),
    acquisition: EquipmentAcquisition.fromJson(
      (json['acquisition'] as Map? ?? const {}).cast<String, dynamic>(),
    ),
    locations: (json['locations'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => LocationRecord.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false),
    raw: json,
  );
}

class ArmorSet {
  final String id;
  final EquipmentLabel name;
  final List<String> pieces;
  final List<int> tiers;
  final String icon;
  final String iconStrategy;
  final List<String> effects;
  final Map<String, dynamic> protection;

  const ArmorSet({
    required this.id,
    required this.name,
    required this.pieces,
    required this.tiers,
    required this.icon,
    required this.iconStrategy,
    required this.effects,
    required this.protection,
  });

  factory ArmorSet.fromJson(Map<String, dynamic> json) => ArmorSet(
    id: json['id']?.toString() ?? '',
    name: EquipmentLabel.fromJson(json['name']),
    pieces: List<String>.from(json['pieces'] ?? const []),
    tiers: List<int>.from(json['tiers'] ?? const []),
    icon: json['icon']?.toString() ?? '',
    iconStrategy: json['iconStrategy']?.toString() ?? 'primary_piece_fallback',
    effects: List<String>.from(json['effects'] ?? const []),
    protection: (json['protection'] as Map? ?? const {})
        .cast<String, dynamic>(),
  );
}

class EquipmentCatalog {
  final List<EquipmentItem> items;
  final List<ArmorSet> armorSets;

  const EquipmentCatalog({required this.items, required this.armorSets});
}
