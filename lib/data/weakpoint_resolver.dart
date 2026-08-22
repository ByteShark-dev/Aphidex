import '../models/enemy.dart';
import 'ui_mapper.dart';

class WeakpointPresentation {
  final String region;
  final String iconAsset;
  final String effectiveDamage;
  final List<String> weaponFamilies;

  const WeakpointPresentation({
    required this.region,
    required this.iconAsset,
    required this.effectiveDamage,
    required this.weaponFamilies,
  });
}

abstract interface class WeakpointResolver {
  WeakpointPresentation resolve(WeakPointInfo weakpoint);
}

class AphidexWeakpointResolver implements WeakpointResolver {
  const AphidexWeakpointResolver();

  static const _knownRegions = {
    'back',
    'eyes',
    'gut',
    'legs',
    'rump',
    'stinger',
  };

  @override
  WeakpointPresentation resolve(WeakPointInfo weakpoint) {
    final normalized = weakpoint.part.trim().toLowerCase();
    final region = _knownRegions.contains(normalized) ? normalized : 'unknown';
    final damage = switch (weakpoint.susceptibleDamage) {
      'stabbing_arrows_only' => 'projectile_piercing',
      final value when value.trim().isNotEmpty => value,
      _ => 'unknown',
    };
    final families = weakpoint.weaponFamilies.isNotEmpty
        ? weakpoint.weaponFamilies
        : damage == 'projectile_piercing'
        ? const ['bow', 'crossbow']
        : const <String>[];
    return WeakpointPresentation(
      region: region,
      iconAsset: UiMapper.weakPointIcon(region),
      effectiveDamage: damage,
      weaponFamilies: families,
    );
  }
}
