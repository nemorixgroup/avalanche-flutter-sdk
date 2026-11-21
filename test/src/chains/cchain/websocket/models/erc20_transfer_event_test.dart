// ignore_for_file: lines_longer_than_80_chars

import 'package:avalanche_flutter_sdk/src/chains/cchain/erc20/erc20_constants.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/websocket/models/erc20_transfer_event.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/websocket/models/evm_log.dart';
import 'package:flutter_test/flutter_test.dart';

/// A 32-byte event data field from a hex amount without prefix.
String amountData(String hex) => '0x${hex.padLeft(64, '0')}';

/// A 32-byte topic holding a 20-byte address (40 hex digits).
String addressTopic(String address40) => '0x${'0' * 24}$address40';

// The live 1 USDC Transfer captured on Fuji (block 0x3a74aba):
// 0xe9d70EE1... -> 0x0fEB4757...
Map<String, dynamic> liveLog() => <String, dynamic>{
      'address': '0x5425890298aed601595a70ab815c96711a31bc65',
      'topics': <String>[
        ERC20Constants.transferEventTopic,
        addressTopic('e9d70ee1dfced40152ea3f030d0a3918f2ee81a8'),
        addressTopic('0feb475783e004621b9463aae30f33665485fafa'),
      ],
      'data': amountData('f4240'),
      'blockNumber': '0x3a74aba',
      'transactionHash':
          '0xb72785e8b1d08e94a5a45c72043f64e6d5e12f7a03ec7335f7832cead080bc2a',
      'transactionIndex': '0x0',
      'blockHash':
          '0xf6e514178ae31683fceda8a065b118f67c1bdfd37fb025a921f9034bcd1310a6',
      'logIndex': '0x0',
      'removed': false,
    };

EvmLog logWith(void Function(Map<String, dynamic> json) change) {
  final json = liveLog();
  change(json);
  return EvmLog.fromJson(json);
}

void main() {
  group('Erc20TransferEvent.fromLog - decoding', () {
    test('decodes the live USDC transfer', () {
      final event = Erc20TransferEvent.fromLog(EvmLog.fromJson(liveLog()));
      expect(event.token, equals('0x5425890298aed601595a70ab815c96711a31bc65'));
      expect(
        event.from,
        equals('0xe9d70ee1dfced40152ea3f030d0a3918f2ee81a8'),
      );
      expect(event.to, equals('0x0feb475783e004621b9463aae30f33665485fafa'));
      expect(event.value, equals(BigInt.from(1000000)));
      expect(
        event.transactionHash,
        equals(
          '0xb72785e8b1d08e94a5a45c72043f64e6d5e12f7a03ec7335f7832cead080bc2a',
        ),
      );
      expect(event.blockNumber, equals(0x3a74aba));
      expect(event.logIndex, equals(0));
      expect(event.removed, isFalse);
    });

    test('returns lowercase addresses for mixed-case input', () {
      final log = logWith((json) {
        json['address'] = '0x5425890298AED601595A70AB815C96711A31BC65';
        json['topics'] = <String>[
          ERC20Constants.transferEventTopic,
          addressTopic('E9D70EE1DFCED40152EA3F030D0A3918F2EE81A8'),
          addressTopic('0FEB475783E004621B9463AAE30F33665485FAFA'),
        ];
      });
      final event = Erc20TransferEvent.fromLog(log);
      expect(event.token, equals('0x5425890298aed601595a70ab815c96711a31bc65'));
      expect(
        event.from,
        equals('0xe9d70ee1dfced40152ea3f030d0a3918f2ee81a8'),
      );
      expect(event.to, equals('0x0feb475783e004621b9463aae30f33665485fafa'));
    });

    test('keeps the exact amount up to the maximum uint256', () {
      final log = logWith((json) => json['data'] = amountData('f' * 64));
      final event = Erc20TransferEvent.fromLog(log);
      expect(event.value, equals((BigInt.one << 256) - BigInt.one));
    });

    test('accepts the event topic in uppercase digits', () {
      final upper =
          '0x${ERC20Constants.transferEventTopic.substring(2).toUpperCase()}';
      final log = logWith((json) {
        final topics =
            (json['topics'] as List<dynamic>).cast<String>().toList();
        topics[0] = upper;
        json['topics'] = topics;
      });
      expect(
        Erc20TransferEvent.fromLog(log).value,
        equals(BigInt.from(1000000)),
      );
    });

    test('keeps removed: true from a reorganized log', () {
      final log = logWith((json) => json['removed'] = true);
      expect(Erc20TransferEvent.fromLog(log).removed, isTrue);
    });

    test('valueInTokens converts 6 decimals (1 USDC)', () {
      final event = Erc20TransferEvent.fromLog(EvmLog.fromJson(liveLog()));
      expect(event.valueInTokens(6), closeTo(1.0, 1e-9));
    });

    test('valueInTokens converts 18 decimals', () {
      final log =
          logWith((json) => json['data'] = amountData('de0b6b3a7640000'));
      final event = Erc20TransferEvent.fromLog(log);
      expect(event.valueInTokens(18), closeTo(1.0, 1e-9));
    });
  });

  group('Erc20TransferEvent.fromLog - rejects other logs', () {
    test('a different event signature', () {
      final log = logWith((json) {
        final topics =
            (json['topics'] as List<dynamic>).cast<String>().toList();
        topics[0] = '0x${'11' * 32}';
        json['topics'] = topics;
      });
      expect(() => Erc20TransferEvent.fromLog(log), throwsFormatException);
    });

    test('an ERC-721 Transfer (four topics)', () {
      final log = logWith((json) {
        final topics = (json['topics'] as List<dynamic>).cast<String>().toList()
          ..add('0x${'0' * 63}1');
        json['topics'] = topics;
        json['data'] = '0x';
      });
      expect(
        () => Erc20TransferEvent.fromLog(log),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('ERC-721'),
          ),
        ),
      );
    });

    test('too few topics', () {
      final log = logWith((json) {
        final topics = (json['topics'] as List<dynamic>).cast<String>().toList()
          ..removeLast();
        json['topics'] = topics;
      });
      expect(() => Erc20TransferEvent.fromLog(log), throwsFormatException);
    });

    test('a log without topics', () {
      final log = logWith((json) => json.remove('topics'));
      expect(() => Erc20TransferEvent.fromLog(log), throwsFormatException);
    });

    test('empty data', () {
      final log = logWith((json) => json['data'] = '0x');
      expect(() => Erc20TransferEvent.fromLog(log), throwsFormatException);
    });

    test('data that is not exactly 32 bytes', () {
      final log = logWith((json) => json['data'] = '0x${'0' * 62}');
      expect(() => Erc20TransferEvent.fromLog(log), throwsFormatException);
    });

    test('a topic that is not a padded address', () {
      final log = logWith((json) {
        final topics =
            (json['topics'] as List<dynamic>).cast<String>().toList();
        topics[2] = '0xff${'00' * 11}0feb475783e004621b9463aae30f33665485fafa';
        json['topics'] = topics;
      });
      expect(() => Erc20TransferEvent.fromLog(log), throwsFormatException);
    });
  });

  group('Erc20TransferEvent - toString', () {
    test('shows the token, the amount and the removed flag', () {
      final text =
          Erc20TransferEvent.fromLog(EvmLog.fromJson(liveLog())).toString();
      expect(text, contains('0x5425890298aed601595a70ab815c96711a31bc65'));
      expect(text, contains('value: 1000000'));
      expect(text, contains('removed: false'));
    });
  });
}
