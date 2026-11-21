// ignore_for_file: lines_longer_than_80_chars

import 'package:avalanche_flutter_sdk/src/chains/cchain/websocket/models/new_head.dart';
import 'package:flutter_test/flutter_test.dart';

// Subset of live newHeads results captured on Fuji (blocks 0x3a74ab7 and
// 0x3a74ab8). The typed fields and a few Avalanche-specific fields are
// kept; the other header fields and the logsBloom are omitted.
Map<String, dynamic> headOne() => <String, dynamic>{
      'parentHash':
          '0x2758ee95e64cdc0002b14bc259a82be9a03fa140fb5f806a1746dc5001b4a1ed',
      'miner': '0x0100000000000000000000000000000000000000',
      'number': '0x3a74ab7',
      'gasLimit': '0x1e84800',
      'gasUsed': '0x16e360',
      'timestamp': '0x6afdec24',
      'extDataHash':
          '0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421',
      'baseFeePerGas': '0xa',
      'timestampMilliseconds': '0x1a1efe2703c',
      'settledHeight': '0x3a74ab5',
      'hash':
          '0x810731966bd5b550c8737c0cb1ede617c591ab93e5bac48d84a84d605f5f1232',
    };

Map<String, dynamic> headTwo() => <String, dynamic>{
      'parentHash':
          '0x810731966bd5b550c8737c0cb1ede617c591ab93e5bac48d84a84d605f5f1232',
      'miner': '0x0100000000000000000000000000000000000000',
      'number': '0x3a74ab8',
      'gasLimit': '0x1e84800',
      'gasUsed': '0xd69d',
      'timestamp': '0x6afdec28',
      'baseFeePerGas': '0xa',
      'timestampMilliseconds': '0x1a1efe27df3',
      'settledHeight': '0x3a74ab6',
      'hash':
          '0x2d4db8c6a455ac4b45a207d91affdb99d1188a0801909e3b3444af0be8400fc8',
    };

void main() {
  group('NewHead.fromJson', () {
    test('parses the typed fields of a live header', () {
      final head = NewHead.fromJson(headOne());
      expect(head.number, equals(0x3a74ab7));
      expect(
        head.hash,
        equals(
          '0x810731966bd5b550c8737c0cb1ede617c591ab93e5bac48d84a84d605f5f1232',
        ),
      );
      expect(head.timestamp, equals(0x6afdec24));
      expect(head.gasUsed, equals(BigInt.from(0x16e360)));
      expect(head.gasLimit, equals(BigInt.from(32000000)));
      expect(head.baseFeePerGas, equals(BigInt.from(10)));
      expect(head.miner, equals('0x0100000000000000000000000000000000000000'));
    });

    test('consecutive headers link through parentHash', () {
      final first = NewHead.fromJson(headOne());
      final second = NewHead.fromJson(headTwo());
      expect(second.parentHash, equals(first.hash));
      expect(second.number, equals(first.number + 1));
    });

    test('time uses millisecond precision when available', () {
      final head = NewHead.fromJson(headOne());
      expect(head.timestampMilliseconds, equals(0x1a1efe2703c));
      expect(head.time.millisecondsSinceEpoch, equals(0x1a1efe2703c));
      expect(head.time.isUtc, isTrue);
    });

    test('time falls back to seconds when milliseconds are absent', () {
      final json = headOne()..remove('timestampMilliseconds');
      final head = NewHead.fromJson(json);
      expect(head.timestampMilliseconds, isNull);
      expect(head.time.millisecondsSinceEpoch, equals(0x6afdec24 * 1000));
    });

    test('baseFeePerGas is null when absent', () {
      final json = headOne()..remove('baseFeePerGas');
      expect(NewHead.fromJson(json).baseFeePerGas, isNull);
    });

    test('raw keeps the Avalanche-specific fields', () {
      final head = NewHead.fromJson(headOne());
      expect(head.raw['settledHeight'], equals('0x3a74ab5'));
      expect(head.raw.containsKey('extDataHash'), isTrue);
    });

    test('raw is unmodifiable', () {
      final head = NewHead.fromJson(headOne());
      expect(() => head.raw['x'] = 1, throwsUnsupportedError);
    });

    test('throws a TypeError when a required field is missing', () {
      expect(
        () => NewHead.fromJson(<String, dynamic>{}),
        throwsA(isA<TypeError>()),
      );
    });

    test('toString shows number and hash only', () {
      final head = NewHead.fromJson(headOne());
      expect(head.toString(), startsWith('NewHead(number: 61295287'));
    });
  });
}
