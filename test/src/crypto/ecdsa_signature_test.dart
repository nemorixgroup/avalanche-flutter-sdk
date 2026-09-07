import 'dart:typed_data';

import 'package:avalanche_flutter_sdk/src/crypto/private_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrivateKey.signDigest', () {
    test('returns EcdsaSignature with r, s, v', () {
      final privateKey = PrivateKey.fromHex('1'.padLeft(64, '0'));
      final digest = Uint8List(32)..fillRange(0, 32, 0xab);
      final sig = privateKey.signDigest(digest);

      expect(sig.r, isA<BigInt>());
      expect(sig.s, isA<BigInt>());
      expect(sig.v == 0 || sig.v == 1, isTrue);
    });

    test('v is always 0 or 1 (EIP-1559 signatureYParity)', () {
      final privateKey = PrivateKey.generate();
      final digest = Uint8List(32)..fillRange(0, 32, 0x42);
      final sig = privateKey.signDigest(digest);
      expect(sig.v == 0 || sig.v == 1, isTrue);
    });

    test('s is always low-S (s <= n/2)', () {
      // secp256k1 n
      final n = BigInt.parse(
        'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141',
        radix: 16,
      );
      final privateKey = PrivateKey.generate();
      final digest = Uint8List(32)..fillRange(0, 32, 0x01);
      final sig = privateKey.signDigest(digest);
      expect(sig.s <= n >> 1, isTrue);
    });

    test('signing is deterministic (RFC 6979)', () {
      final privateKey = PrivateKey.fromHex('1'.padLeft(64, '0'));
      final digest = Uint8List(32)..fillRange(0, 32, 0xab);
      final sig1 = privateKey.signDigest(digest);
      final sig2 = privateKey.signDigest(digest);
      expect(sig1.r, equals(sig2.r));
      expect(sig1.s, equals(sig2.s));
      expect(sig1.v, equals(sig2.v));
    });

    test('different keys produce different signatures', () {
      final key1 = PrivateKey.fromHex('1'.padLeft(64, '0'));
      final key2 = PrivateKey.fromHex('2'.padLeft(64, '0'));
      final digest = Uint8List(32)..fillRange(0, 32, 0xab);
      final sig1 = key1.signDigest(digest);
      final sig2 = key2.signDigest(digest);
      expect(sig1.r == sig2.r && sig1.s == sig2.s, isFalse);
    });

    test('different digests produce different signatures', () {
      final privateKey = PrivateKey.fromHex('1'.padLeft(64, '0'));
      final digest1 = Uint8List(32)..fillRange(0, 32, 0xab);
      final digest2 = Uint8List(32)..fillRange(0, 32, 0xcd);
      final sig1 = privateKey.signDigest(digest1);
      final sig2 = privateKey.signDigest(digest2);
      expect(sig1.r == sig2.r && sig1.s == sig2.s, isFalse);
    });

    test('throws ArgumentError for digest shorter than 32 bytes', () {
      final privateKey = PrivateKey.generate();
      // ignore: unnecessary_lambdas
      expect(
        () => privateKey.signDigest(Uint8List(31)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for digest longer than 32 bytes', () {
      final privateKey = PrivateKey.generate();
      // ignore: unnecessary_lambdas
      expect(
        () => privateKey.signDigest(Uint8List(33)),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
