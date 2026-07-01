import 'dart:convert';
import 'dart:typed_data';

import 'package:avalanche_flutter_sdk/src/crypto/cb58.dart';
import 'package:avalanche_flutter_sdk/src/crypto/private_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---- Official Reference Vector ----

  group('CB58.encode - reference test vector', () {
    // Verified against moreati/cb58ref, a CB58 reference implementation
    // for the AVA/Avalanche network:
    // https://github.com/moreati/cb58ref
    //
    // >>> cb58ref.cb58encode(b"Hello world")
    // '32UWxgjUJd9s6Kyvxjj1u'
    test('encodes "Hello world" to the known reference output', () {
      final data = Uint8List.fromList(utf8.encode('Hello world'));
      final encoded = CB58.encode(data);
      expect(encoded, equals('32UWxgjUJd9s6Kyvxjj1u'));
    });

    test('decodes the reference CB58 string back to "Hello world"', () {
      final decoded = CB58.decode('32UWxgjUJd9s6Kyvxjj1u');
      expect(utf8.decode(decoded), equals('Hello world'));
    });
  });

  // ---- Base Cases: Round-trip ----

  group('CB58 - round-trip', () {
    test('round-trips arbitrary byte data', () {
      final data = Uint8List.fromList([1, 2, 3, 4, 5, 255, 254, 0, 128]);
      final encoded = CB58.encode(data);
      final decoded = CB58.decode(encoded);
      expect(decoded, equals(data));
    });

    test('round-trips a 32-byte private key (typical use case)', () {
      final key = PrivateKey.generate();
      final data = key.toBytes();
      final encoded = CB58.encode(data);
      final decoded = CB58.decode(encoded);
      expect(decoded, equals(data));
    });

    test('round-trips a 20-byte value (typical address use case)', () {
      final data = Uint8List.fromList(List.generate(20, (i) => i * 7 % 256));
      final encoded = CB58.encode(data);
      final decoded = CB58.decode(encoded);
      expect(decoded, equals(data));
    });

    test('produces different encodings for different data', () {
      final data1 = Uint8List.fromList([1, 2, 3]);
      final data2 = Uint8List.fromList([1, 2, 4]);
      expect(CB58.encode(data1), isNot(equals(CB58.encode(data2))));
    });

    test('produces the same encoding for the same data (determinism)', () {
      final data = Uint8List.fromList([10, 20, 30]);
      expect(CB58.encode(data), equals(CB58.encode(data)));
    });
  });

  // ---- Boundary: Leading Zero Bytes ----

  group('CB58 - leading zero bytes', () {
    test('encodes a single leading zero byte with a leading "1"', () {
      final data = Uint8List.fromList([0, 1, 2, 3]);
      final encoded = CB58.encode(data);
      expect(encoded.startsWith('1'), isTrue);
    });

    test('round-trips data with multiple leading zero bytes', () {
      final data = Uint8List.fromList([0, 0, 0, 42, 17]);
      final encoded = CB58.encode(data);
      final decoded = CB58.decode(encoded);
      expect(decoded, equals(data));
    });

    test('round-trips all-zero data', () {
      final data = Uint8List(8); // all zeros
      final encoded = CB58.encode(data);
      final decoded = CB58.decode(encoded);
      expect(decoded, equals(data));
    });
  });

  // ---- Boundary: Empty / Minimal Input ----

  group('CB58 - minimal input', () {
    test('encodes a single-byte input', () {
      final data = Uint8List.fromList([42]);
      final encoded = CB58.encode(data);
      final decoded = CB58.decode(encoded);
      expect(decoded, equals(data));
    });

    test('encodes empty data (checksum-only payload)', () {
      final data = Uint8List(0);
      final encoded = CB58.encode(data);
      final decoded = CB58.decode(encoded);
      expect(decoded, equals(data));
    });
  });

  // ---- Invalid Input: Decode ----

  group('CB58.decode - invalid input', () {
    test('throws ArgumentError for an empty string', () {
      expect(
        () => CB58.decode(''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for a character outside the alphabet', () {
      // '0' (zero), 'O', 'I', 'l' are excluded from the CB58 alphabet.
      expect(
        () => CB58.decode('0InvalidChars'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when checksum does not match', () {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final validEncoded = CB58.encode(data);

      // Corrupt the last character to break the checksum.
      final corrupted = '${validEncoded.substring(0, validEncoded.length - 1)}'
          '${validEncoded[validEncoded.length - 1] == 'a' ? 'b' : 'a'}';

      expect(
        () => CB58.decode(corrupted),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
        'throws ArgumentError when payload is shorter than checksum '
        'length', () {
      // A 3-character Base58 string cannot possibly contain a valid
      // 4-byte checksum plus any data.
      expect(
        () => CB58.decode('abc'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ---- Integration: PrivateKey export format ----

  group('CB58 - PrivateKey export format (PrivateKey-<cb58>)', () {
    test(
        'a generated private key can be CB58-encoded and decoded back '
        'to the same bytes', () {
      final key = PrivateKey.generate();
      final cb58 = CB58.encode(key.toBytes());
      final exportString = 'PrivateKey-$cb58';

      // Simulate parsing: strip the "PrivateKey-" prefix, decode CB58.
      final parsedCb58 = exportString.substring('PrivateKey-'.length);
      final decoded = CB58.decode(parsedCb58);

      expect(decoded, equals(key.toBytes()));
    });
  });
}
