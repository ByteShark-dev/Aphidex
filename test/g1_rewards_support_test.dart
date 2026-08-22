import 'package:aphidex/data/ui_mapper.dart';
import 'package:aphidex/i18n/app_localizations.dart';
import 'package:aphidex/models/enemy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RewardUnlockInfo parsing', () {
    test('parses reward unlocks from enemy json', () {
      final enemy = Enemy.fromJson({
        'id': 'test_enemy',
        'speciesKey': 'test_enemy',
        'name': {'es': 'Prueba', 'en': 'Test', 'ru': 'Тест'},
        'game': 'g1',
        'tier': 1,
        'danger': 'baja',
        'isBoss': false,
        'defaultGold': false,
        'cardNormal': 'normal.webp',
        'cardGold': 'gold.webp',
        'photo': 'photo.webp',
        'weaknesses': <String>[],
        'resistances': <String>[],
        'rewardUnlocks': [
          {
            'id': 'raw_science',
            'category': 'currency',
            'name': {
              'es': 'Ciencia pura',
              'en': 'Raw Science',
              'ru': 'Raw Science',
            },
            'amount': 1000,
          },
        ],
      });

      expect(enemy.rewardUnlocks, hasLength(1));
      expect(enemy.rewardUnlocks.first.id, 'raw_science');
      expect(enemy.rewardUnlocks.first.category, 'currency');
      expect(enemy.rewardUnlocks.first.amount, 1000);
    });
  });

  group('UiMapper rewardIcon', () {
    test('maps mutations and currencies to dedicated assets', () {
      expect(
        UiMapper.rewardIcon('apex_predator'),
        'assets/global/rewards/Mutation_Apex_Predator.webp',
      );
      expect(
        UiMapper.rewardIcon('raw_science'),
        'assets/global/rewards/Raw_Science.png',
      );
      expect(UiMapper.isRawScienceLabel('Raw Science'), isTrue);
      expect(UiMapper.isRawScienceLabel('Ciencia pura'), isTrue);
      expect(UiMapper.isRawScienceLabel('Ciencia bruta'), isTrue);
      expect(UiMapper.isRawScienceLabel('Ciencia arrugada'), isFalse);
    });
  });

  group('AppLocalizations rewardsUnlocksTitle', () {
    test('resolves localized rewards title', () {
      expect(
        AppLocalizations(const Locale('es')).rewardsUnlocksTitle,
        'Recompensas y desbloqueos',
      );
      expect(
        AppLocalizations(const Locale('en')).rewardsUnlocksTitle,
        'Rewards and unlocks',
      );
      expect(
        AppLocalizations(const Locale('ru')).rewardsUnlocksTitle,
        'Награды и разблокировки',
      );
    });
  });
}
