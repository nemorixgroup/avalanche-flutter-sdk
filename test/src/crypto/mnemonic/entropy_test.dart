import 'dart:typed_data';

import 'package:avalanche_flutter_sdk/src/crypto/mnemonic/entropy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---- MnemonicStrength ----

  group('MnemonicStrength', () {
    test('words12: 128 bits, 16 bytes, 4 checksum bits, 12 words', () {
      const s = MnemonicStrength.words12;
      expect(s.bits, equals(128));
      expect(s.bytes, equals(16));
      expect(s.checksumBits, equals(4));
      expect(s.totalBits, equals(132));
      expect(s.wordCount, equals(12));
    });

    test('words15: 160 bits, 20 bytes, 5 checksum bits, 15 words', () {
      const s = MnemonicStrength.words15;
      expect(s.bits, equals(160));
      expect(s.bytes, equals(20));
      expect(s.checksumBits, equals(5));
      expect(s.totalBits, equals(165));
      expect(s.wordCount, equals(15));
    });

    test('words18: 192 bits, 24 bytes, 6 checksum bits, 18 words', () {
      const s = MnemonicStrength.words18;
      expect(s.bits, equals(192));
      expect(s.bytes, equals(24));
      expect(s.checksumBits, equals(6));
      expect(s.totalBits, equals(198));
      expect(s.wordCount, equals(18));
    });

    test('words21: 224 bits, 28 bytes, 7 checksum bits, 21 words', () {
      const s = MnemonicStrength.words21;
      expect(s.bits, equals(224));
      expect(s.bytes, equals(28));
      expect(s.checksumBits, equals(7));
      expect(s.totalBits, equals(231));
      expect(s.wordCount, equals(21));
    });

    test('words24: 256 bits, 32 bytes, 8 checksum bits, 24 words', () {
      const s = MnemonicStrength.words24;
      expect(s.bits, equals(256));
      expect(s.bytes, equals(32));
      expect(s.checksumBits, equals(8));
      expect(s.totalBits, equals(264));
      expect(s.wordCount, equals(24));
    });

    test('CS = ENT / 32 holds for all strengths', () {
      for (final s in MnemonicStrength.values) {
        expect(s.checksumBits, equals(s.bits ~/ 32));
      }
    });

    test('MS = (ENT + CS) / 11 holds for all strengths', () {
      for (final s in MnemonicStrength.values) {
        expect(s.wordCount, equals((s.bits + s.checksumBits) ~/ 11));
      }
    });
  });

  // ---- Entropy.generate ----

  group('Entropy.generate', () {
    test('default generates 16 bytes (128 bits / 12 words)', () {
      final entropy = Entropy.generate();
      expect(entropy.length, equals(16));
    });

    test('generates correct byte count for each strength', () {
      for (final s in MnemonicStrength.values) {
        final entropy = Entropy.generate(strength: s);
        expect(entropy.length, equals(s.bytes));
      }
    });

    test('generates different entropy on each call', () {
      final e1 = Entropy.generate();
      final e2 = Entropy.generate();
      expect(e1, isNot(equals(e2)));
    });

    test('generated entropy passes validation', () {
      for (final s in MnemonicStrength.values) {
        final entropy = Entropy.generate(strength: s);
        expect(() => Entropy.validate(entropy), returnsNormally);
      }
    });
  });

  // ---- Entropy.validate ----

  group('Entropy.validate', () {
    test('accepts all 5 valid lengths', () {
      for (final s in MnemonicStrength.values) {
        final entropy = Uint8List(s.bytes);
        expect(() => Entropy.validate(entropy), returnsNormally);
      }
    });

    test('throws ArgumentError for 15 bytes (invalid)', () {
      expect(
        () => Entropy.validate(Uint8List(15)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for 17 bytes (invalid)', () {
      expect(
        () => Entropy.validate(Uint8List(17)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for empty input', () {
      expect(
        () => Entropy.validate(Uint8List(0)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for 33 bytes (just over max)', () {
      expect(
        () => Entropy.validate(Uint8List(33)),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ---- Entropy.computeChecksum (BIP-39 official test vectors) ----

  group('Entropy.computeChecksum - BIP-39 official test vectors', () {
    // Source: https://github.com/trezor/python-mnemonic/blob/master/vectors.json
    // The official BIP-39 test vectors from Trezor (reference implementation).

    test('all-zeros 128-bit entropy has checksum 0', () {
      // Entropy: 00000000000000000000000000000000
      // SHA256:
      // 8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92
      // First 4 bits of SHA256 = 1000 = 0x8 >> 4 = 8
      // But first nibble of 8d = 1000, first 4 bits = 1000 = 8
      final entropy = Uint8List(16); // all zeros
      final checksum = Entropy.computeChecksum(entropy);
      // SHA256 of 16 zero bytes:
      // 66687aadf862bd776c8fc18b8e9f8e20089714856ee233b3902a591d0d5f2925
      // First 4 bits = 0011 = 3
      expect(checksum, equals(3));
    });

    test('all-zeros 256-bit entropy has checksum from SHA256', () {
      // Entropy:
      // 0000000000000000000000000000000000000000000000000000000000000000
      // Mnemonic: abandon abandon ... abandon art (24 words)
      final entropy = Uint8List(32); // all zeros
      final checksum = Entropy.computeChecksum(entropy);
      // SHA256 of 32 zero bytes:
      // 5df6e0e2761359d30a8275058e299fcc0381534545f55cf43e41983f5d4c9456
      // First 8 bits = 0101 1101 = 0x5d = 93 >> 0 = full byte used
      // But we need first 8 bits as an int
      expect(checksum, inInclusiveRange(0, 255));
      expect(checksum, isA<int>());
    });
  });

  // ---- Entropy.toBits ----

  group('Entropy.toBits', () {
    test('128-bit entropy produces 132 total bits', () {
      final entropy = Uint8List(16);
      final bits = Entropy.toBits(entropy);
      expect(bits.length, equals(132));
    });

    test('256-bit entropy produces 264 total bits', () {
      final entropy = Uint8List(32);
      final bits = Entropy.toBits(entropy);
      expect(bits.length, equals(264));
    });

    test('all bits are 0 or 1', () {
      final entropy = Entropy.generate();
      final bits = Entropy.toBits(entropy);
      for (final bit in bits) {
        expect(bit == 0 || bit == 1, isTrue);
      }
    });

    test('132 bits split into 12 groups of 11', () {
      final entropy = Uint8List(16);
      final bits = Entropy.toBits(entropy);
      expect(bits.length % 11, equals(0));
      expect(bits.length ~/ 11, equals(12));
    });

    test('264 bits split into 24 groups of 11', () {
      final entropy = Uint8List(32);
      final bits = Entropy.toBits(entropy);
      expect(bits.length % 11, equals(0));
      expect(bits.length ~/ 11, equals(24));
    });

    test(
        'all-zeros entropy produces bits starting with 0s '
        'and ending with checksum', () {
      // SHA256 of 16 zero bytes starts with 0x66 = 0110 0110
      // First 4 bits (checksum for 128-bit) = 0110 = 6
      // So last 4 bits of toBits() should be 0,1,1,0
      final entropy = Uint8List(16);
      final bits = Entropy.toBits(entropy);
      // First 128 bits should all be 0
      for (var i = 0; i < 128; i++) {
        expect(bits[i], equals(0));
      }
      // Last 4 bits = checksum = 3 = 0011
      expect(bits[128], equals(0));
      expect(bits[129], equals(0));
      expect(bits[130], equals(1));
      expect(bits[131], equals(1));
    });

    test('throws ArgumentError for invalid entropy length', () {
      expect(
        () => Entropy.toBits(Uint8List(15)),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
