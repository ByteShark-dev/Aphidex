import 'dart:convert';
import 'dart:typed_data';

import 'package:aphidex/data/enemy_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    EnemyRepository.clearCaches();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  test(
    'loads localized indexes without requesting master JSON files',
    () async {
      final requestedKeys = <String>[];
      _installAssetHandler(requestedKeys);

      final g1 = await EnemyRepository.loadGame('g1', 'en');
      final all = await EnemyRepository.loadAll('en');

      expect(g1, hasLength(1));
      expect(g1.single.name, 'Test Enemy');
      expect(all.map((enemy) => enemy.id), ['g1_test_enemy', 'g2_test_enemy']);
      expect(requestedKeys.where((key) => key.contains('enemies_g')), isEmpty);
      expect(requestedKeys, contains('assets/data/creatures/en/index_g1.json'));
      expect(requestedKeys, contains('assets/data/creatures/en/index_g2.json'));
    },
  );

  test('loads details on demand and caches opened creature details', () async {
    final requestedKeys = <String>[];
    _installAssetHandler(requestedKeys);

    final first = await EnemyRepository.loadDetail('g1', 'g1_test_enemy', 'en');
    final second = await EnemyRepository.loadDetail(
      'g1',
      'g1_test_enemy',
      'en',
    );

    expect(first.id, 'g1_test_enemy');
    expect(identical(first, second), isTrue);
    expect(
      requestedKeys
          .where(
            (key) =>
                key == 'assets/data/creatures/en/details/g1_test_enemy.json',
          )
          .length,
      1,
    );
    expect(requestedKeys.where((key) => key.contains('enemies_g')), isEmpty);
  });
}

void _installAssetHandler(List<String> requestedKeys) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) async {
        final key = utf8.decode(
          message!.buffer.asUint8List(
            message.offsetInBytes,
            message.lengthInBytes,
          ),
        );
        requestedKeys.add(key);

        if (key == 'assets/data/creatures/en/index_g1.json') {
          return _stringData(jsonEncode([_indexEntry('g1_test_enemy', 'g1')]));
        }
        if (key == 'assets/data/creatures/en/index_g2.json') {
          return _stringData(jsonEncode([_indexEntry('g2_test_enemy', 'g2')]));
        }
        if (key == 'assets/data/creatures/en/details/g1_test_enemy.json') {
          return _stringData(jsonEncode(_detailEntry('g1_test_enemy', 'g1')));
        }
        if (key == 'assets/data/creatures/en/details/g2_test_enemy.json') {
          return _stringData(jsonEncode(_detailEntry('g2_test_enemy', 'g2')));
        }
        if (key.contains('enemies_g')) {
          fail('EnemyRepository requested master JSON at runtime: $key');
        }
        return null;
      });
}

Map<String, dynamic> _indexEntry(String id, String game) {
  return {
    'id': id,
    'speciesKey': 'test_enemy',
    'game': game,
    'name': 'Test Enemy',
    'tier': 1,
    'danger': 'baja',
    'isBoss': false,
    'order': game == 'g1' ? 1 : 2,
    'defaultGold': false,
    'cardNormal': 'assets/global/Creaturecard_Proximamente.webp',
    'cardGold': 'assets/global/Creaturecard_Proximamente.webp',
    'weaknesses': ['spicy'],
    'resistances': ['fresh'],
    'temperament': 'neutral',
    'health': {'rating': 1, 'value': 10},
  };
}

Map<String, dynamic> _detailEntry(String id, String game) {
  return {
    ..._indexEntry(id, game),
    'photo': 'assets/global/Aphidex_Proximamente.webp',
    'description': 'Localized description',
  };
}

ByteData _stringData(String value) {
  final bytes = Uint8List.fromList(utf8.encode(value));
  return ByteData.view(bytes.buffer);
}
