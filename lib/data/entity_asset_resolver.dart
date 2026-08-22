import '../models/enemy.dart';
import '../models/enemy_index_entry.dart';
import '../models/equipment.dart';

enum EntityAssetUsage {
  cover,
  card,
  thumbnail,
  variant,
  equipmentIcon,
  customEntry,
  mapMarker,
}

class EntityAssetResolution {
  final String asset;
  final String source;
  final bool fallbackUsed;

  const EntityAssetResolution({
    required this.asset,
    required this.source,
    required this.fallbackUsed,
  });
}

/// Resolves presentation assets without crossing the G1/G2 boundary, except
/// for the single approved Orchid Mantis reuse documented by the importer.
///
/// Cover and card usages intentionally have independent candidate lists: a
/// cover is never promoted to a card/thumbnail merely because it exists.
class EntityAssetResolver {
  const EntityAssetResolver._();

  static const approvedCrossGameCreatureId = 'g2_orchid_mantis';

  static const creatureCoverFallback =
      'assets/global/Aphidex_Proximamente.webp';
  static const creatureCardFallback =
      'assets/global/Creaturecard_Proximamente.webp';
  static const equipmentFallback = 'assets/global/Aphidex_Proximamente.webp';
  static const mapMarkerFallback = 'assets/global/Aphidex_Proximamente.webp';

  static EntityAssetResolution resolveEnemy(
    Enemy enemy,
    EntityAssetUsage usage, {
    String? selectedCardAsset,
    String? variantAsset,
  }) => resolveCreature(
    publicId: enemy.id,
    game: enemy.game,
    usage: usage,
    coverAsset: enemy.photo,
    cardAsset: selectedCardAsset ?? enemy.defaultCardAsset,
    thumbnailAsset: enemy.listIconAsset,
    mapMarkerAsset: enemy.mapMarkerAsset,
    customAsset: enemy.customAsset,
    variantAsset: variantAsset,
  );

  static EntityAssetResolution resolveEnemyIndex(
    EnemyIndexEntry enemy,
    EntityAssetUsage usage, {
    String? selectedCardAsset,
  }) => resolveCreature(
    publicId: enemy.id,
    game: enemy.game,
    usage: usage,
    cardAsset: selectedCardAsset ?? enemy.defaultCardAsset,
    thumbnailAsset: enemy.listIconAsset,
    mapMarkerAsset: enemy.mapMarkerAsset,
    customAsset: enemy.customAsset,
  );

  static EntityAssetResolution resolveCreature({
    required String game,
    required EntityAssetUsage usage,
    String? publicId,
    String? coverAsset,
    String? cardAsset,
    String? thumbnailAsset,
    String? variantAsset,
    String? mapMarkerAsset,
    String? customAsset,
  }) {
    final candidates = switch (usage) {
      EntityAssetUsage.cover => [(coverAsset, 'entity_cover')],
      EntityAssetUsage.card => [(cardAsset, 'entity_card')],
      EntityAssetUsage.thumbnail => [(thumbnailAsset, 'entity_thumbnail')],
      EntityAssetUsage.mapMarker => [(mapMarkerAsset, 'entity_map_marker')],
      EntityAssetUsage.variant => [(variantAsset, 'entity_variant')],
      EntityAssetUsage.customEntry => [(customAsset, 'custom_entry')],
      EntityAssetUsage.equipmentIcon => const <(String?, String)>[],
    };
    for (final candidate in candidates) {
      final path = candidate.$1?.trim() ?? '';
      if ((usage == EntityAssetUsage.customEntry && _isUniversalAsset(path)) ||
          _belongsToGame(
            path,
            game,
            approvedCrossGameException:
                publicId == approvedCrossGameCreatureId && game == 'g2',
          )) {
        return EntityAssetResolution(
          asset: path,
          source:
              publicId == approvedCrossGameCreatureId &&
                  path.startsWith('assets/g1/')
              ? 'approved_cross_game_exception'
              : candidate.$2,
          fallbackUsed: false,
        );
      }
    }
    final fallback = switch (usage) {
      EntityAssetUsage.cover ||
      EntityAssetUsage.variant => creatureCoverFallback,
      EntityAssetUsage.card ||
      EntityAssetUsage.thumbnail => creatureCardFallback,
      EntityAssetUsage.mapMarker => mapMarkerFallback,
      EntityAssetUsage.equipmentIcon ||
      EntityAssetUsage.customEntry => equipmentFallback,
    };
    return EntityAssetResolution(
      asset: fallback,
      source: 'technical_fallback',
      fallbackUsed: true,
    );
  }

  static EntityAssetResolution resolveEquipment(EquipmentItem item) {
    final asset = item.icon.trim();
    if (_belongsToGame(asset, 'g2')) {
      return EntityAssetResolution(
        asset: asset,
        source: 'equipment_icon',
        fallbackUsed: false,
      );
    }
    return const EntityAssetResolution(
      asset: equipmentFallback,
      source: 'technical_fallback',
      fallbackUsed: true,
    );
  }

  static EntityAssetResolution resolveArmorSet(ArmorSet set) {
    final asset = set.icon.trim();
    if (_belongsToGame(asset, 'g2')) {
      return EntityAssetResolution(
        asset: asset,
        source: set.iconStrategy,
        fallbackUsed: set.iconStrategy != 'verified_set_asset',
      );
    }
    return const EntityAssetResolution(
      asset: equipmentFallback,
      source: 'technical_fallback',
      fallbackUsed: true,
    );
  }

  static bool _belongsToGame(
    String asset,
    String game, {
    bool approvedCrossGameException = false,
  }) {
    if (asset.isEmpty) return false;
    return switch (game) {
      'g1' => asset.startsWith('assets/g1/'),
      'g2' =>
        asset.startsWith('assets/g2/') ||
            approvedCrossGameException && asset.startsWith('assets/g1/'),
      _ => false,
    };
  }

  static bool _isUniversalAsset(String asset) =>
      asset.startsWith('assets/global/');
}
