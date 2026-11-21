import 'package:avalanche_flutter_sdk/src/utils/hex_quantity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hexToBigInt', () {
    test('parses a 0x-prefixed quantity', () {
      expect(hexToBigInt('0xa'), equals(BigInt.from(10)));
    });

    test('accepts an uppercase 0X prefix', () {
      expect(hexToBigInt('0XFF'), equals(BigInt.from(255)));
    });

    test('accepts a value without prefix', () {
      expect(hexToBigInt('ff'), equals(BigInt.from(255)));
    });

    test('empty string and bare 0x are zero', () {
      expect(hexToBigInt(''), equals(BigInt.zero));
      expect(hexToBigInt('0x'), equals(BigInt.zero));
    });

    test('parses values larger than 64 bits', () {
      final max = BigInt.parse('f' * 64, radix: 16);
      expect(hexToBigInt('0x${'f' * 64}'), equals(max));
    });

    test('throws FormatException for invalid digits', () {
      expect(() => hexToBigInt('0xzz'), throwsFormatException);
    });
  });

  group('hexToInt', () {
    test('parses a live Fuji block number', () {
      expect(hexToInt('0x3a74ab7'), equals(0x3a74ab7));
    });

    test('parses zero', () {
      expect(hexToInt('0x0'), equals(0));
    });
  });
}
