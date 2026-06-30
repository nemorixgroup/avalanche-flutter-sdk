import 'package:avalanche_flutter_sdk/src/crypto/private_key.dart';
import 'package:avalanche_flutter_sdk/src/crypto/public_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---- Derivation from PrivateKey ----

  group('PublicKey - derivation from PrivateKey', () {
    test('compressed encoding is exactly 33 bytes', () {
      final key = PrivateKey.generate();
      expect(key.publicKey.toCompressed().length, equals(33));
    });

    test('uncompressed encoding is exactly 65 bytes', () {
      final key = PrivateKey.generate();
      expect(key.publicKey.toUncompressed().length, equals(65));
    });

    test('raw uncompressed (no prefix) is exactly 64 bytes', () {
      final key = PrivateKey.generate();
      expect(key.publicKey.toRawUncompressed().length, equals(64));
    });

    test('compressed prefix byte is 0x02 or 0x03', () {
      final key = PrivateKey.generate();
      final prefix = key.publicKey.toCompressed()[0];
      expect(prefix == 0x02 || prefix == 0x03, isTrue);
    });

    test('uncompressed prefix byte is always 0x04', () {
      final key = PrivateKey.generate();
      expect(key.publicKey.toUncompressed()[0], equals(0x04));
    });

    test('toRawUncompressed strips exactly the 0x04 prefix byte', () {
      final key = PrivateKey.generate();
      final full = key.publicKey.toUncompressed();
      final raw = key.publicKey.toRawUncompressed();
      expect(raw, equals(full.sublist(1)));
    });
  });

  // ---- Import: fromHex (base cases) ----

  group('PublicKey.fromHex - valid input', () {
    test('imports a compressed public key (66 hex chars)', () {
      final original = PrivateKey.generate().publicKey;
      final imported = PublicKey.fromHex(original.toHex());
      expect(imported, equals(original));
    });

    test('imports an uncompressed public key (130 hex chars)', () {
      final original = PrivateKey.generate().publicKey;
      final uncompressedHex = original
          .toUncompressed()
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      final imported = PublicKey.fromHex(uncompressedHex);
      expect(imported, equals(original));
    });

    test('compressed and uncompressed imports of same key are equal', () {
      final original = PrivateKey.generate().publicKey;
      final compressedHex = original.toHex();
      final uncompressedHex = original
          .toUncompressed()
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();

      final fromCompressed = PublicKey.fromHex(compressedHex);
      final fromUncompressed = PublicKey.fromHex(uncompressedHex);

      expect(fromCompressed, equals(fromUncompressed));
    });

    test('imports with 0x prefix', () {
      final original = PrivateKey.generate().publicKey;
      final imported = PublicKey.fromHex('0x${original.toHex()}');
      expect(imported, equals(original));
    });

    test('round-trips toHex/fromHex correctly', () {
      final original = PrivateKey.generate().publicKey;
      final roundTripped = PublicKey.fromHex(original.toHex());
      expect(roundTripped.toHex(), equals(original.toHex()));
    });
  });

  // ---- Import: fromHex (boundary - invalid input) ----

  group('PublicKey.fromHex - invalid input', () {
    test('throws ArgumentError for malformed hex (odd length)', () {
      expect(
        () => PublicKey.fromHex('abc'),
        throwsA(anyOf(isA<ArgumentError>(), isA<FormatException>())),
      );
    });

    test('throws ArgumentError for a point not on the curve', () {
      // 33 bytes, valid-looking prefix, but X coordinate with no
      // corresponding valid Y on the secp256k1 curve.
      const invalidPoint =
          '02ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
      expect(
        () => PublicKey.fromHex(invalidPoint),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws for empty string', () {
      expect(
        () => PublicKey.fromHex(''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws for invalid prefix byte (not 02, 03, or 04)', () {
      final original = PrivateKey.generate().publicKey;
      final hex = original.toHex();
      final corrupted = '05${hex.substring(2)}';
      expect(
        () => PublicKey.fromHex(corrupted),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ---- Equality ----

  group('PublicKey - equality', () {
    test('two derivations from the same private key are equal', () {
      final privateKey = PrivateKey.generate();
      final pub1 = privateKey.publicKey;
      final pub2 = privateKey.publicKey;
      expect(pub1, equals(pub2));
    });

    test('derivations from different private keys are not equal', () {
      final pub1 = PrivateKey.generate().publicKey;
      final pub2 = PrivateKey.generate().publicKey;
      expect(pub1, isNot(equals(pub2)));
    });

    test('hashCode is consistent with equals', () {
      final privateKey = PrivateKey.generate();
      final pub1 = privateKey.publicKey;
      final pub2 = privateKey.publicKey;
      expect(pub1.hashCode, equals(pub2.hashCode));
    });
  });

  // ---- toString ----

  group('PublicKey.toString', () {
    test('includes 0x prefix and compressed hex', () {
      final key = PrivateKey.generate().publicKey;
      expect(key.toString(), equals('PublicKey(0x${key.toHex()})'));
    });

    test('public keys are safe to expose (not redacted)', () {
      final key = PrivateKey.generate().publicKey;
      expect(key.toString().contains(key.toHex()), isTrue);
    });
  });
}
