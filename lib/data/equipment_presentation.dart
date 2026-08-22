import 'effect_catalog.dart';

class EquipmentPresentation {
  const EquipmentPresentation._();

  static String typeLabel(String value, String language) => switch (value) {
    'weapon' => _t(language, 'Weapon', 'Arma', 'Оружие'),
    'shield' => _t(language, 'Shield', 'Escudo', 'Щит'),
    'armor' => _t(language, 'Armor', 'Armadura', 'Броня'),
    'armor_set' => _t(
      language,
      'Armor set',
      'Set de armadura',
      'Комплект брони',
    ),
    'trinket' => _t(language, 'Trinket', 'Amuleto', 'Талисман'),
    _ => _t(language, 'Special item', 'Objeto especial', 'Особый предмет'),
  };

  static String subtypeLabel(String value, String language) => switch (value) {
    'weapon' => _t(language, 'Weapon', 'Arma', 'Оружие'),
    'shield' => _t(language, 'Shield', 'Escudo', 'Щит'),
    'head' => _t(language, 'Head', 'Cabeza', 'Голова'),
    'chest' => _t(language, 'Chest', 'Pechera', 'Нагрудник'),
    'legs' => _t(language, 'Legs', 'Piernas', 'Ноги'),
    'armor_piece' => _t(
      language,
      'Armor piece',
      'Pieza de armadura',
      'Часть брони',
    ),
    'badge' => _t(
      language,
      'Badge / medallion',
      'Insignia / medallón',
      'Знак / медальон',
    ),
    'accessory' => _t(language, 'Accessory', 'Accesorio', 'Аксессуар'),
    'set' => _t(language, 'Set', 'Set', 'Комплект'),
    _ => _t(language, 'Special', 'Especial', 'Особый'),
  };

  static String slotLabel(String? raw, String language) {
    final value = (raw ?? '').replaceFirst('EEquipmentSlot::', '');
    return switch (value.toLowerCase()) {
      'mainhand' => _t(
        language,
        'Main hand',
        'Mano principal',
        'Основная рука',
      ),
      'offhand' => _t(language, 'Off hand', 'Mano secundaria', 'Вторая рука'),
      'head' => _t(language, 'Head', 'Cabeza', 'Голова'),
      'chest' => _t(language, 'Chest', 'Pechera', 'Нагрудник'),
      'legs' => _t(language, 'Legs', 'Piernas', 'Ноги'),
      'glider' => _t(language, 'Accessory', 'Accesorio', 'Аксессуар'),
      _ => '',
    };
  }

  static String acquisitionMethod(String raw, String language) => switch (raw) {
    'crafting' => _t(language, 'Crafting', 'Fabricación', 'Создание'),
    'physical_pickup' => _t(
      language,
      'Fixed pickup',
      'Recogida fija',
      'Фиксированный предмет',
    ),
    'boss_cached_drop' => _t(
      language,
      'Boss drop',
      'Botín de jefe',
      'Добыча с босса',
    ),
    'loot_source' => _t(
      language,
      'Loot source',
      'Fuente de botín',
      'Источник добычи',
    ),
    'quest' => _t(
      language,
      'Quest reward',
      'Recompensa de misión',
      'Награда за задание',
    ),
    _ => cleanIdentifier(raw),
  };

  static String stationLabel(String? raw, String language) {
    final value = raw ?? '';
    if (value.contains('Workbench')) {
      return _t(language, 'Workbench', 'Banco de trabajo', 'Верстак');
    }
    return cleanIdentifier(value.replaceFirst('CraftingBuilding.', ''));
  }

  static String effectLabel(String technical, String language) {
    final normalized = normalizedTechnicalEffectId(technical);
    final catalog = effectCatalogEntryById(normalized);
    if (catalog != null) return catalog.name.resolve(language);
    final lower = technical.toLowerCase();
    final prefix = lower.contains('tarantula')
        ? _t(language, 'Tarantula', 'Tarántula', 'Тарантул')
        : '';
    final effect = switch (true) {
      _ when lower.contains('charge') && lower.contains('attack') => _t(
        language,
        'charged attack boost',
        'ataque cargado mejorado',
        'усиление заряженной атаки',
      ),
      _ when lower.contains('critical') || lower.contains('crit') => _t(
        language,
        'critical hit',
        'golpe crítico',
        'критический удар',
      ),
      _ when lower.contains('lifesteal') || lower.contains('life steal') => _t(
        language,
        'life steal',
        'robo de vida',
        'кража здоровья',
      ),
      _
          when lower.contains('perfectblock') ||
              lower.contains('perfect block') =>
        _t(language, 'perfect block', 'bloqueo perfecto', 'идеальный блок'),
      _ when lower.contains('stamina') => _t(
        language,
        'stamina',
        'aguante',
        'выносливость',
      ),
      _ when lower.contains('damage') && lower.contains('resist') => _t(
        language,
        'damage resistance',
        'resistencia al daño',
        'сопротивление урону',
      ),
      _ when lower.contains('attack') && lower.contains('up') => _t(
        language,
        'attack boost',
        'ataque mejorado',
        'усиление атаки',
      ),
      _ => cleanIdentifier(technical),
    };
    return prefix.isEmpty ? effect : '$prefix: $effect';
  }

  static String upgradeRoute(String raw, String language) {
    final value = raw.replaceFirst('WeaponUpgrade.', '');
    if (value == 'Default' || value == 'ArmorDefault') {
      return _t(language, 'Standard', 'Estándar', 'Стандарт');
    }
    if (value == 'ArmorHiddenStatus') {
      return _t(language, 'Specialized', 'Especializada', 'Специализация');
    }
    return cleanIdentifier(value)
        .replaceAll('Mint', _t(language, 'Fresh', 'Fresco', 'Свежесть'))
        .replaceAll('Salt', _t(language, 'Salty', 'Salado', 'Солёный'))
        .replaceAll('Spicy', _t(language, 'Spicy', 'Picante', 'Острый'))
        .replaceAll('Sour', _t(language, 'Sour', 'Ácido', 'Кислый'));
  }

  static String cleanIdentifier(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[A-Za-z0-9_]+::'), '')
        .replaceAll('_', ' ')
        .replaceAllMapped(RegExp(r'(?<=[a-z0-9])(?=[A-Z])'), (_) => ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return const {'', 'unknown', 'none', 'null'}.contains(cleaned.toLowerCase())
        ? ''
        : cleaned;
  }

  static String _t(String language, String en, String es, String ru) =>
      switch (language) {
        'es' => es,
        'ru' => ru,
        _ => en,
      };
}
