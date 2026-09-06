import 'dart:typed_data';

import 'package:avalanche_flutter_sdk/src/chains/cchain/utils/rlp_encoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---- Official RLP test vectors ----
  // Source: https://ethereum.org/en/developers/docs/data-structures-and-encoding/rlp/

  group('RlpEncoder - single bytes', () {
    test('encodes single byte 0x00', () {
      final result = RlpEncoder.encode(Uint8List.fromList([0x00]));
      expect(result, equals(Uint8List.fromList([0x00])));
    });

    test('encodes single byte 0x7f (max single-byte value)', () {
      final result = RlpEncoder.encode(Uint8List.fromList([0x7f]));
      expect(result, equals(Uint8List.fromList([0x7f])));
    });

    test('encodes 0x80 as prefixed byte (>= 0x80 needs length prefix)', () {
      final result = RlpEncoder.encode(Uint8List.fromList([0x80]));
      expect(result, equals(Uint8List.fromList([0x81, 0x80])));
    });
  });

  group('RlpEncoder - BigInt values', () {
    test('encodes BigInt.zero as empty bytes 0x80', () {
      final result = RlpEncoder.encode(BigInt.zero);
      expect(result, equals(Uint8List.fromList([0x80])));
    });

    test('encodes BigInt(1) as 0x01', () {
      final result = RlpEncoder.encode(BigInt.one);
      expect(result, equals(Uint8List.fromList([0x01])));
    });

    test('encodes BigInt(0x7f) as 0x7f', () {
      final result = RlpEncoder.encode(BigInt.from(0x7f));
      expect(result, equals(Uint8List.fromList([0x7f])));
    });

    test('encodes BigInt(0x80) as 0x8180', () {
      final result = RlpEncoder.encode(BigInt.from(0x80));
      expect(result, equals(Uint8List.fromList([0x81, 0x80])));
    });

    test('encodes BigInt(1024) as 0x820400', () {
      // 1024 = 0x0400 -> length 2 -> 0x82 prefix
      final result = RlpEncoder.encode(BigInt.from(1024));
      expect(result, equals(Uint8List.fromList([0x82, 0x04, 0x00])));
    });
  });

  group('RlpEncoder - int values', () {
    test('encodes int 0 as 0x80', () {
      final result = RlpEncoder.encode(0);
      expect(result, equals(Uint8List.fromList([0x80])));
    });

    test('encodes int 1 as 0x01', () {
      final result = RlpEncoder.encode(1);
      expect(result, equals(Uint8List.fromList([0x01])));
    });

    test('encodes int 127 as 0x7f', () {
      final result = RlpEncoder.encode(127);
      expect(result, equals(Uint8List.fromList([0x7f])));
    });
  });

  group('RlpEncoder - byte strings', () {
    test('encodes empty bytes as 0x80', () {
      final result = RlpEncoder.encode(Uint8List(0));
      expect(result, equals(Uint8List.fromList([0x80])));
    });

    test('encodes 20-byte address correctly (length prefix 0x94)', () {
      // 0x80 + 20 = 0x94
      final address = Uint8List(20);
      final result = RlpEncoder.encode(address);
      expect(result.length, equals(21)); // 1 prefix + 20 data
      expect(result[0], equals(0x94)); // 0x80 + 20
    });

    test('encodes 32-byte value correctly (length prefix 0xa0)', () {
      // 0x80 + 32 = 0xa0
      final bytes32 = Uint8List(32);
      final result = RlpEncoder.encode(bytes32);
      expect(result.length, equals(33)); // 1 prefix + 32 data
      expect(result[0], equals(0xa0));
    });
  });

  group('RlpEncoder - lists', () {
    test('encodes empty list as 0xc0', () {
      final result = RlpEncoder.encode(<dynamic>[]);
      expect(result, equals(Uint8List.fromList([0xc0])));
    });

    test('encodes list of empty list [[]] as 0xc1c0', () {
      final result = RlpEncoder.encode([<dynamic>[]]);
      expect(result, equals(Uint8List.fromList([0xc1, 0xc0])));
    });

    test('encodes nested empty lists [[], [[]], [[], [[]]]]', () {
      // From Ethereum RLP reference
      final result = RlpEncoder.encode([
        <dynamic>[],
        [<dynamic>[]],
        [
          <dynamic>[],
          [<dynamic>[]],
        ]
      ]);
      expect(
        result,
        equals(
          Uint8List.fromList(
            [0xc7, 0xc0, 0xc1, 0xc0, 0xc3, 0xc0, 0xc1, 0xc0],
          ),
        ),
      );
    });
  });

  group('RlpEncoder - EIP-1559 transaction fields', () {
    test('encodes chainId 43113 (Fuji) correctly', () {
      // 43113 = 0xA869 -> 2 bytes -> 0x82 prefix
      final result = RlpEncoder.encode(BigInt.from(43113));
      expect(result[0], equals(0x82));
      expect(result.length, equals(3));
    });

    test('encodes nonce 0 as 0x80', () {
      final result = RlpEncoder.encode(BigInt.zero);
      expect(result, equals(Uint8List.fromList([0x80])));
    });

    test('encodes gasLimit 21000 correctly', () {
      // 21000 = 0x5208 -> 2 bytes -> 0x82 prefix
      final result = RlpEncoder.encode(BigInt.from(21000));
      expect(result[0], equals(0x82));
      expect(result[1], equals(0x52));
      expect(result[2], equals(0x08));
    });

    test('throws ArgumentError for unsupported type', () {
      expect(
        // ignore: unnecessary_lambdas
        () => RlpEncoder.encode('unsupported_string_type'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for negative BigInt', () {
      expect(
        // ignore: unnecessary_lambdas
        () => RlpEncoder.encode(BigInt.from(-1)),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
