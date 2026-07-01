import 'package:avalanche_flutter_sdk/src/crypto/private_key.dart';
//import 'package:avalanche_flutter_sdk/src/crypto/public_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---- Generation ----

  group('PrivateKey.generate', () {
    test('generates a key with valid 64-char hex', () {
      final key = PrivateKey.generate();
      expect(key.toHex().length, equals(64));
    });

    test('generates different keys on each call', () {
      final key1 = PrivateKey.generate();
      final key2 = PrivateKey.generate();
      expect(key1.toHex(), isNot(equals(key2.toHex())));
    });

    test('generated key produces a valid, non-null public key', () {
      final key = PrivateKey.generate();
      expect(key.publicKey, isNotNull);
    });

    test('toBytes returns exactly 32 bytes', () {
      final key = PrivateKey.generate();
      expect(key.toBytes().length, equals(32));
    });
  });

  // ---- Import: fromHex (base cases) ----

  group('PrivateKey.fromHex - valid input', () {
    test('imports a key without 0x prefix', () {
      // 64 zero-padded except trailing 1 - construct properly below
      final validHex = '1'.padLeft(64, '0');
      final key = PrivateKey.fromHex(validHex);
      expect(key.toHex(), equals(validHex));
    });

    test('imports a key with 0x prefix', () {
      final validHex = '1'.padLeft(64, '0');
      final key = PrivateKey.fromHex('0x$validHex');
      expect(key.toHex(), equals(validHex));
    });

    test('round-trips hex export/import correctly', () {
      final original = PrivateKey.generate();
      final reimported = PrivateKey.fromHex(original.toHex());
      expect(reimported.toHex(), equals(original.toHex()));
    });

    test('imported key derives the same public key as the original', () {
      final original = PrivateKey.generate();
      final reimported = PrivateKey.fromHex(original.toHex());
      expect(reimported.publicKey, equals(original.publicKey));
    });

    test('accepts uppercase hex characters', () {
      final validHex = '1'.padLeft(64, '0');
      final key = PrivateKey.fromHex(validHex.toUpperCase());
      expect(key.toHex(), equals(validHex));
    });
  });

  // ---- Import: fromHex (boundary - length) ----

  group('PrivateKey.fromHex - invalid length', () {
    test('throws ArgumentError when hex is too short', () {
      expect(
        () => PrivateKey.fromHex('1234'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when hex is too long', () {
      final tooLong = '1'.padLeft(66, '0');
      expect(
        () => PrivateKey.fromHex(tooLong),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for empty string', () {
      expect(
        () => PrivateKey.fromHex(''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for empty string with 0x prefix only', () {
      expect(
        () => PrivateKey.fromHex('0x'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ---- Import: fromHex (boundary - curve order n) ----

  group('PrivateKey.fromHex - value range (secp256k1 order n)', () {
    // secp256k1 curve order n, verified directly from pointycastle's
    // ECDomainParameters('secp256k1').n at runtime:
    // fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141
    const curveOrderN =
        'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141';
    const curveOrderNMinusOne =
        'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364140';

    test('throws ArgumentError when d is zero', () {
      final zeroHex = '0'.padLeft(64, '0');
      expect(
        () => PrivateKey.fromHex(zeroHex),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when d equals curve order n', () {
      expect(
        () => PrivateKey.fromHex(curveOrderN),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when d is greater than curve order n', () {
      // n + 1
      const nPlusOne =
          'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364142';
      expect(
        () => PrivateKey.fromHex(nPlusOne),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('accepts d = 1 (minimum valid value)', () {
      final minHex = '1'.padLeft(64, '0');
      expect(() => PrivateKey.fromHex(minHex), returnsNormally);
    });

    test('accepts d = n - 1 (maximum valid value)', () {
      expect(
        () => PrivateKey.fromHex(curveOrderNMinusOne),
        returnsNormally,
      );
    });
  });

  // ---- toString security ----

  group('PrivateKey.toString', () {
    test('never exposes the private key value', () {
      final key = PrivateKey.fromHex('1'.padLeft(64, '0'));
      expect(key.toString(), equals('PrivateKey[REDACTED]'));
    });

    test('redacted string does not contain any hex of the key', () {
      final key = PrivateKey.generate();
      expect(key.toString().contains(key.toHex()), isFalse);
    });
  });

  // ---- Determinism ----

  group('PrivateKey - determinism', () {
    test('same private key always derives the same public key', () {
      final hex = PrivateKey.generate().toHex();
      final key1 = PrivateKey.fromHex(hex);
      final key2 = PrivateKey.fromHex(hex);
      expect(key1.publicKey, equals(key2.publicKey));
    });

    test('publicKey getter is idempotent (same instance values)', () {
      final key = PrivateKey.generate();
      final pub1 = key.publicKey;
      final pub2 = key.publicKey;
      expect(pub1, equals(pub2));
    });
  });
}
