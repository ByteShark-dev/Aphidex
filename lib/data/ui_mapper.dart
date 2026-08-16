import '../models/enemy.dart';
import 'effect_catalog.dart';

class UiMapper {
  static String canonicalDangerLevel(String level) {
    switch (level.trim().toLowerCase()) {
      case 'media':
        return 'intermedia';
      case 'imposible_alt':
      case 'imposible_alta':
      case 'imposible_superior':
        return 'imposible_superior';
      default:
        return level.trim().toLowerCase();
    }
  }

  static String dangerLevelForScore(int score) {
    if (score < 0 || score > 100) {
      throw RangeError.range(score, 0, 100, 'score');
    }
    if (score <= 19) return 'baja';
    if (score <= 39) return 'intermedia';
    if (score <= 59) return 'alta';
    if (score <= 74) return 'muy_alta';
    if (score <= 84) return 'imposible';
    if (score <= 89) return 'imposible_superior';
    return 'extrema';
  }

  // ================= EFFECT / DAMAGE ICONS =================
  static String effectIcon(String id) {
    const base = 'assets/global/effects_damage';
    final effectId = canonicalEffectId(id);

    switch (effectId) {
      case 'slashing':
        return '$base/Tooltype_Slashing.webp';
      case 'chopping':
        return '$base/Tooltype_Chopping.webp';
      case 'busting':
        return '$base/Tooltype_Busting.webp';
      case 'stabbing':
        return '$base/Tooltype_Stabbing.webp';
      case 'explosive':
        return '$base/Tooltype_Explosive.webp';
      case 'generic':
        return '$base/Generic_Damage.webp';
      case 'fresh':
        return '$base/Damagetype_Fresh.webp';
      case 'water':
        return '$base/Tooltype_Water.png';
      case 'chill':
        return '$base/Chilling_Attack.png';
      case 'spicy':
        return '$base/Damagetype_Spicy.webp';
      case 'salty':
        return '$base/Damagetype_Salty.webp';
      case 'sour':
        return '$base/Damagetype_Sour.webp';
      case 'dust':
        return '$base/Dust.webp';
      case 'poison':
        return '$base/Poison.webp';
      case 'venom':
        return '$base/Venom.webp';
      case 'gas':
        return '$base/Gas_Hazard.webp';
      case 'bleed':
        return '$base/Bleed.webp';
      case 'shock':
        return '$base/Tooltype_Shock.webp';
      case 'burning':
        return '$base/Tooltype_Burning.webp';
      case 'sizzle':
        return '$base/Sizzling_Attack.png';
      case 'tang_buildup':
        return '$base/TangBuildUp.webp';
      case 'infection':
        return '$base/Infection.webp';

      default:
        return '$base/Generic_Damage.webp';
    }
  }

  static String rewardIcon(String id) {
    const base = 'assets/global/rewards';
    switch (id.trim().toLowerCase()) {
      case 'apex_predator':
        return '$base/Mutation_Apex_Predator.webp';
      case 'bardic_inspiration':
        return '$base/Mutation_Bardic_Inspiration.webp';
      case 'corporate_kickback':
        return '$base/Mutation_Corporate_Kickback.webp';
      case 'mantsterious_stranger':
        return '$base/Mutation_Mantsterious_Stranger.webp';
      case 'mithridatism':
        return '$base/Mutation_Mithridatism.webp';
      case 'mom_genes':
        return '$base/Mutation_Mom_Genes.webp';
      case 'shocking_dismissal':
        return '$base/Mutation_Shocking_Dismissal.webp';
      case 'spore_lord':
        return '$base/Mutation_Spore_Lord.webp';
      case 'truffle_tussle':
        return '$base/Mutation_Truffle_Tussle.webp';
      case 'raw_science':
        return '$base/Raw_Science.webp';
      case 'new_game_plus':
        return '$base/New_Game_Plus.webp';
      case 'attack_damage':
        return '$base/Attack_Damage.webp';
      case 'attack_speed':
        return '$base/Attack_Speed.webp';
      case 'damage_resist':
        return '$base/Damage_Resist.webp';
      case 'exhaustion_recovery':
        return '$base/Exhaustion_Recovery.webp';
      case 'increased_healing':
        return '$base/Increased_Healing.webp';
      case 'movement_speed':
        return '$base/Movement_Speed.webp';
      case 'perfect_block':
        return '$base/Perfect_Block.webp';
      case 'microstamina':
        return '$base/Microstamina.webp';
      case 'playground':
        return '$base/Playground.webp';
      case 'broodmother_poison':
        return '$base/Poison_Broodmother.webp';
      default:
        return '$base/Raw_Science.webp';
    }
  }

  // ================= WEAK POINT ICONS =================
  // ids: back, eyes, gut, legs, rump, stinger
  static String weakPointIcon(String id) {
    const base = 'assets/global/weak_points';

    switch (id) {
      case 'back':
        return '$base/T_UI_Weakspot_Back.webp';
      case 'eyes':
        return '$base/T_UI_Weakspot_Eyes.webp';
      case 'gut':
        return '$base/T_UI_Weakspot_Gut.webp';
      case 'legs':
        return '$base/T_UI_Weakspot_Legs.webp';
      case 'rump':
        return '$base/T_UI_Weakspot_Rump.webp';
      case 'stinger':
        return '$base/T_UI_Weakspot_Stinger.webp';
      default:
        return '$base/T_UI_Weakspot_Back.webp';
    }
  }

  // ================= SUSCEPTIBLE DAMAGE ICONS =================
  // devuelve una lista para permitir multiples iconos
  static List<String> susceptibleDamageEffectIds(String dmgId) {
    final id = canonicalEffectId(dmgId);
    switch (id) {
      case 'any':
        return [
          'slashing',
          'stabbing',
          'chopping',
          'busting',
          'generic',
          'explosive',
        ];
      case 'chopping and slashing':
        return ['chopping', 'slashing'];
      default:
        return [id];
    }
  }

  static List<String> susceptibleDamageIcons(String dmgId) {
    return susceptibleDamageEffectIds(dmgId).map(effectIcon).toList();
  }

  // ================= DANGER ICONS =================
  static String dangerIcon(String level) {
    const base = 'assets/global';
    final normalized = canonicalDangerLevel(level);

    switch (normalized) {
      case 'baja':
        return '$base/Baja.png';
      case 'media':
        return '$base/Media.png';
      case 'intermedia':
        return '$base/Intermedia.png';
      case 'alta':
        return '$base/Alta.png';
      case 'muy_alta':
        return '$base/Muy_alta.png';
      case 'imposible':
        return '$base/Imposible.png';
      case 'imposible_superior':
        return '$base/Imposible_alt.png';
      case 'extrema':
        return '$base/Extrema.png';
      case 'proximamente':
        return '$base/Proximamente.png';
      default:
        return '$base/Proximamente.png';
    }
  }

  // ================= TIER ICONS =================
  static String tierIcon({
    required int tier,
    required bool isBoss,
    String? enemyId,
    String? game,
    int? cardTier,
    BossCardStyle? bossCardStyle,
  }) {
    const base = 'assets/global';

    if (game == 'g2') {
      const g2Base = 'assets/g2/tier_icons';
      if (isBoss) {
        return bossCardStyle == BossCardStyle.yellow
            ? '$g2Base/G2_tier_boss_V.png'
            : '$g2Base/G2_tier_boss.png';
      }
      return switch (cardTier ?? tier) {
        0 => '$g2Base/G2_tier_0.png',
        1 => '$g2Base/G2_tier_1.png',
        2 => '$g2Base/G2_tier_2.png',
        3 => '$g2Base/G2_tier_3.png',
        4 => '$g2Base/CreatureTier4.png',
        _ => '$base/CreatureTier5.png',
      };
    }

    if (isBoss) return '$base/CreatureTierBoss.webp';

    switch (tier) {
      case 1:
        return '$base/CreatureTier1.webp';
      case 2:
        return '$base/CreatureTier2.webp';
      case 3:
        return '$base/CreatureTier3.webp';
      case 4:
        return '$base/CreatureTier4.webp';
      case 5:
        return '$base/CreatureTier5.png';
      default:
        return '$base/CreatureTier1.webp';
    }
  }
}
