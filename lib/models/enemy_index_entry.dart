import 'creature_card_support.dart';
import 'enemy.dart';

class EnemyIndexEntry implements CreatureCardCarrier {
  @override
  final String id;
  final String speciesKey;
  final String? collectionGroup;
  final String? groupId;
  final String name;
  final int? order;
  @override
  final String game;
  final String? temperament;
  final int tier;
  final int? cardTier;
  final BossCardStyle? bossCardStyle;
  final String danger;
  final bool isUnderConstruction;
  final bool isBoss;
  final List<String> weaknesses;
  final List<String> resistances;
  @override
  final bool defaultGold;
  final String favoriteKey;
  @override
  final String? goldLinkId;
  final String cardNormal;
  final String cardGold;
  final String listIconAsset;
  final bool? hasCreatureCardFlag;
  final bool? hasGoldCreatureCardFlag;
  final bool? hasSelectableCardVariantsFlag;
  final String? defaultCardVariantRaw;
  final HealthInfo? health;

  const EnemyIndexEntry({
    required this.id,
    required this.speciesKey,
    this.collectionGroup,
    this.groupId,
    required this.name,
    required this.order,
    required this.game,
    this.temperament,
    required this.tier,
    this.cardTier,
    this.bossCardStyle,
    required this.danger,
    this.isUnderConstruction = false,
    required this.isBoss,
    required this.weaknesses,
    required this.resistances,
    required this.defaultGold,
    this.favoriteKey = '',
    this.goldLinkId,
    required this.cardNormal,
    required this.cardGold,
    this.listIconAsset = '',
    this.hasCreatureCardFlag,
    this.hasGoldCreatureCardFlag,
    this.hasSelectableCardVariantsFlag,
    this.defaultCardVariantRaw,
    this.health,
  });

  factory EnemyIndexEntry.fromJson(
    Map<String, dynamic> json,
  ) => EnemyIndexEntry(
    id: json['id'] as String,
    speciesKey: (json['speciesKey'] as String?) ?? (json['id'] as String),
    collectionGroup: json['collectionGroup'] as String?,
    groupId: json['groupId'] as String?,
    name: (json['name'] ?? '').toString(),
    order: json['order'] as int?,
    game: json['game'] as String,
    temperament: json['temperament'] as String?,
    tier: json['tier'] as int,
    cardTier: json['cardTier'] as int?,
    bossCardStyle: BossCardStyle.fromJson(json['bossCardStyle']),
    danger: json['danger'] as String,
    isUnderConstruction: json['underConstruction'] as bool? ?? false,
    isBoss: json['isBoss'] as bool? ?? false,
    weaknesses: List<String>.from(json['weaknesses'] ?? const []),
    resistances: List<String>.from(json['resistances'] ?? const []),
    defaultGold: json['defaultGold'] as bool? ?? false,
    favoriteKey: (json['favoriteKey'] as String?) ?? (json['id'] as String),
    goldLinkId: json['goldLinkId'] as String?,
    cardNormal: (json['cardNormal'] as String? ?? '').trim(),
    cardGold: (json['cardGold'] as String? ?? '').trim(),
    listIconAsset: (json['listIconAsset'] as String? ?? '').trim(),
    hasCreatureCardFlag: json['hasCreatureCard'] as bool?,
    hasGoldCreatureCardFlag: json['hasGoldCreatureCard'] as bool?,
    hasSelectableCardVariantsFlag: json['hasSelectableCardVariants'] as bool?,
    defaultCardVariantRaw: json['defaultCardVariant'] as String?,
    health: (json['health'] is Map)
        ? HealthInfo.fromJson((json['health'] as Map).cast<String, dynamic>())
        : null,
  );

  factory EnemyIndexEntry.fromEnemy(Enemy enemy, String languageCode) =>
      EnemyIndexEntry(
        id: enemy.id,
        speciesKey: enemy.speciesKey,
        collectionGroup: enemy.collectionGroup,
        groupId: enemy.groupId,
        name: enemy.name.resolve(languageCode),
        order: enemy.order,
        game: enemy.game,
        temperament: enemy.temperament,
        tier: enemy.tier,
        cardTier: enemy.cardTier,
        bossCardStyle: enemy.bossCardStyle,
        danger: enemy.danger,
        isUnderConstruction: enemy.isUnderConstruction,
        isBoss: enemy.isBoss,
        weaknesses: enemy.weaknesses,
        resistances: enemy.resistances,
        defaultGold: enemy.defaultGold,
        favoriteKey: enemy.favoriteKey,
        goldLinkId: enemy.goldLinkId,
        cardNormal: enemy.cardNormal,
        cardGold: enemy.cardGold,
        listIconAsset: enemy.listIconAsset,
        hasCreatureCardFlag: enemy.hasCreatureCard,
        hasGoldCreatureCardFlag: enemy.hasGoldCreatureCard,
        hasSelectableCardVariantsFlag: enemy.hasSelectableCardVariants,
        defaultCardVariantRaw: enemy.defaultCardVariant?.storageValue,
        health: enemy.health,
      );

  String get resolvedFavoriteKey => favoriteKey.isEmpty ? id : favoriteKey;

  bool get hasValidCardNormal => cardNormal.trim().isNotEmpty;

  bool get hasValidCardGold => cardGold.trim().isNotEmpty;

  @override
  bool get hasCreatureCard =>
      hasCreatureCardFlag ?? (hasValidCardNormal || hasValidCardGold);

  @override
  bool get hasGoldCreatureCard => hasGoldCreatureCardFlag ?? hasValidCardGold;

  @override
  bool get hasSelectableCardVariants =>
      hasSelectableCardVariantsFlag ?? (hasValidCardNormal && hasValidCardGold);

  @override
  CreatureCardVariant? get defaultCardVariant {
    final materialized = CreatureCardVariantX.fromStorageValue(
      defaultCardVariantRaw,
    );
    if (materialized != null) {
      return materialized;
    }
    if (hasValidCardNormal) {
      return CreatureCardVariant.normal;
    }
    if (hasValidCardGold) {
      return CreatureCardVariant.gold;
    }
    return null;
  }

  String? get defaultCardAsset => switch (defaultCardVariant) {
    CreatureCardVariant.normal => cardNormal,
    CreatureCardVariant.gold => cardGold,
    null => null,
  };

  @override
  String? assetForCardVariant(CreatureCardVariant variant) {
    return switch (variant) {
      CreatureCardVariant.normal => hasValidCardNormal ? cardNormal : null,
      CreatureCardVariant.gold => hasValidCardGold ? cardGold : null,
    };
  }
}
