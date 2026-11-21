// ignore_for_file: lines_longer_than_80_chars

import 'package:avalanche_flutter_sdk/src/chains/cchain/erc20/erc20_constants.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/websocket/models/evm_log.dart';
import 'package:flutter_test/flutter_test.dart';

// Live logs notification captured on Fuji: the 1 USDC transfer sent by
// 0xe9d70EE1... to 0x0fEB4757... (block 0x3a74aba).
Map<String, dynamic> usdcTransferLog() => <String, dynamic>{
      'address': '0x5425890298aed601595a70ab815c96711a31bc65',
      'topics': <String>[
        '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef',
        '0x000000000000000000000000e9d70ee1dfced40152ea3f030d0a3918f2ee81a8',
        '0x0000000000000000000000000feb475783e004621b9463aae30f33665485fafa',
      ],
      'data':
          '0x00000000000000000000000000000000000000000000000000000000000f4240',
      'blockNumber': '0x3a74aba',
      'transactionHash':
          '0xb72785e8b1d08e94a5a45c72043f64e6d5e12f7a03ec7335f7832cead080bc2a',
      'transactionIndex': '0x0',
      'blockHash':
          '0xf6e514178ae31683fceda8a065b118f67c1bdfd37fb025a921f9034bcd1310a6',
      'logIndex': '0x0',
      'removed': false,
    };

void main() {
  group('EvmLog.fromJson', () {
    test('parses a live USDC Transfer log', () {
      final log = EvmLog.fromJson(usdcTransferLog());
      expect(log.address, equals('0x5425890298aed601595a70ab815c96711a31bc65'));
      expect(log.topics.length, equals(3));
      expect(log.blockNumber, equals(0x3a74aba));
      expect(log.transactionIndex, equals(0));
      expect(log.logIndex, equals(0));
      expect(log.removed, isFalse);
      expect(
        log.transactionHash,
        equals(
          '0xb72785e8b1d08e94a5a45c72043f64e6d5e12f7a03ec7335f7832cead080bc2a',
        ),
      );
    });

    test('topic0 is the ERC-20 Transfer event topic', () {
      final log = EvmLog.fromJson(usdcTransferLog());
      expect(log.topic0, equals(ERC20Constants.transferEventTopic));
    });

    test('data carries the amount: 0xf4240 is 1 USDC (6 decimals)', () {
      final log = EvmLog.fromJson(usdcTransferLog());
      final amount = BigInt.parse(log.data.substring(2), radix: 16);
      expect(amount, equals(BigInt.from(1000000)));
    });

    test('parses removed: true (reorganized log)', () {
      final json = usdcTransferLog()..['removed'] = true;
      expect(EvmLog.fromJson(json).removed, isTrue);
    });

    test('removed defaults to false when absent', () {
      final json = usdcTransferLog()..remove('removed');
      expect(EvmLog.fromJson(json).removed, isFalse);
    });

    test('topics is unmodifiable', () {
      final log = EvmLog.fromJson(usdcTransferLog());
      expect(() => log.topics.add('0x'), throwsUnsupportedError);
    });

    test('missing topics gives an empty list and a null topic0', () {
      final json = usdcTransferLog()..remove('topics');
      final log = EvmLog.fromJson(json);
      expect(log.topics, isEmpty);
      expect(log.topic0, isNull);
    });

    test('throws a TypeError when a required field is missing', () {
      final json = usdcTransferLog()..remove('transactionHash');
      expect(() => EvmLog.fromJson(json), throwsA(isA<TypeError>()));
    });
  });
}
