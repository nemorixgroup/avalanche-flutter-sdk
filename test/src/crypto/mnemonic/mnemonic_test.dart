import 'dart:typed_data';

import 'package:avalanche_flutter_sdk/src/crypto/mnemonic/entropy.dart';
import 'package:avalanche_flutter_sdk/src/crypto/mnemonic/mnemonic.dart';
import 'package:avalanche_flutter_sdk/src/crypto/mnemonic/wordlist_es.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---- Official BIP-39 test vectors ----
  // Source: https://github.com/trezor/python-mnemonic/blob/master/vectors.json
  // Reference implementation: trezor/python-mnemonic

  group('Mnemonic - BIP-39 official test vectors (English)', () {
    test('all-zeros 128-bit entropy → 12 known words', () {
      final entropy = Uint8List(16); // all zeros
      final mnemonic = Mnemonic.fromEntropy(entropy);
      expect(
        mnemonic.phrase,
        equals(
          'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon about',
        ),
      );
    });

    test('0x7f...7f 128-bit entropy → 12 known words', () {
      final entropy = Uint8List.fromList(List.filled(16, 0x7f));
      final mnemonic = Mnemonic.fromEntropy(entropy);
      expect(
        mnemonic.phrase,
        equals(
          'legal winner thank year wave sausage '
          'worth useful legal winner thank yellow',
        ),
      );
    });

    test('0x80...80 128-bit entropy → 12 known words', () {
      final entropy = Uint8List.fromList(List.filled(16, 0x80));
      final mnemonic = Mnemonic.fromEntropy(entropy);
      expect(
        mnemonic.phrase,
        equals(
          'letter advice cage absurd amount doctor '
          'acoustic avoid letter advice cage above',
        ),
      );
    });

    test('all-zeros 256-bit entropy → 24 known words', () {
      final entropy = Uint8List(32); // all zeros
      final mnemonic = Mnemonic.fromEntropy(entropy);
      expect(
        mnemonic.phrase,
        equals(
          'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon art',
        ),
      );
    });

    test('all-0xff 256-bit entropy → 24 known words', () {
      final entropy = Uint8List.fromList(List.filled(32, 0xff));
      final mnemonic = Mnemonic.fromEntropy(entropy);
      // Verified from runtime output of our implementation.
      // Note: the official Trezor vector uses 128-bit 0xff (16 bytes)
      // which produces "zoo ... wrong" (12 words). This 256-bit variant
      // is not in the official vectors.json, last word verified at runtime.
      expect(
        mnemonic.phrase,
        equals(
          'zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo '
          'zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo '
          'zoo vote',
        ),
      );
    });

    test('all-0xff 128-bit entropy (official Trezor vector)', () {
      // Source: github.com/trezor/python-mnemonic/blob/master/vectors.json
      // ["ffffffffffffffffffffffffffffffff",
      //  "zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong", ...]
      final entropy = Uint8List.fromList(List.filled(16, 0xff));
      final mnemonic = Mnemonic.fromEntropy(entropy);
      expect(
        mnemonic.phrase,
        equals('zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong'),
      );
    });
  });

  // ---- generate() ----

  group('Mnemonic.generate', () {
    test('default generates 12 words', () {
      final mnemonic = Mnemonic.generate();
      expect(mnemonic.wordCount, equals(12));
    });

    test('generates unique mnemonics on each call', () {
      final m1 = Mnemonic.generate();
      final m2 = Mnemonic.generate();
      expect(m1.phrase, isNot(equals(m2.phrase)));
    });

    test('generates correct word count for each strength', () {
      for (final s in MnemonicStrength.values) {
        final mnemonic = Mnemonic.generate(strength: s);
        expect(mnemonic.wordCount, equals(s.wordCount));
      }
    });

    test('generates with Spanish wordlist', () {
      final mnemonic = Mnemonic.generate(wordlist: WordlistEs.instance);
      expect(mnemonic.wordCount, equals(12));
      for (final word in mnemonic.words) {
        expect(WordlistEs.instance.contains(word), isTrue);
      }
    });

    test('wordlist is preserved', () {
      final mnemonic = Mnemonic.generate(wordlist: WordlistEs.instance);
      expect(mnemonic.wordlist.language, equals('es'));
    });
  });

  // ---- fromEntropy() ----

  group('Mnemonic.fromEntropy', () {
    test('accepts all 5 valid entropy sizes', () {
      for (final s in MnemonicStrength.values) {
        final entropy = Entropy.generate(strength: s);
        expect(
          () => Mnemonic.fromEntropy(entropy),
          returnsNormally,
        );
      }
    });

    test('throws ArgumentError for invalid entropy length', () {
      // ignore: unnecessary_lambdas
      expect(
        () => Mnemonic.fromEntropy(Uint8List(15)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('toEntropy() round-trips correctly', () {
      final original = Entropy.generate();
      final mnemonic = Mnemonic.fromEntropy(original);
      expect(mnemonic.toEntropy(), equals(original));
    });

    test('toEntropy() round-trips for all strengths', () {
      for (final s in MnemonicStrength.values) {
        final original = Entropy.generate(strength: s);
        final mnemonic = Mnemonic.fromEntropy(original);
        expect(mnemonic.toEntropy(), equals(original));
      }
    });
  });

  // ---- fromPhrase() ----

  group('Mnemonic.fromPhrase', () {
    test('imports valid 12-word English phrase', () {
      const phrase = 'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon about';
      final mnemonic = Mnemonic.fromPhrase(phrase);
      expect(mnemonic.wordCount, equals(12));
      expect(mnemonic.phrase, equals(phrase));
    });

    test('imports valid 24-word English phrase', () {
      const phrase = 'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon art';
      final mnemonic = Mnemonic.fromPhrase(phrase);
      expect(mnemonic.wordCount, equals(24));
    });

    test('throws ArgumentError for word not in wordlist', () {
      const badPhrase = 'flutter flutter flutter flutter flutter flutter '
          'flutter flutter flutter flutter flutter flutter';
      // ignore: unnecessary_lambdas
      expect(
        () => Mnemonic.fromPhrase(badPhrase),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for invalid word count', () {
      const badPhrase = 'abandon abandon abandon'; // only 3 words
      // ignore: unnecessary_lambdas
      expect(
        () => Mnemonic.fromPhrase(badPhrase),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for invalid checksum', () {
      // All "abandon" words but last word changed - breaks checksum
      const badPhrase = 'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon abandon';
      // ignore: unnecessary_lambdas
      expect(
        () => Mnemonic.fromPhrase(badPhrase),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('handles extra whitespace between words', () {
      const phrase = '  abandon  abandon  abandon  abandon  abandon  abandon '
          ' abandon  abandon  abandon  abandon  abandon  about  ';
      final mnemonic = Mnemonic.fromPhrase(phrase);
      expect(mnemonic.wordCount, equals(12));
    });

    test('round-trip: fromEntropy → phrase → fromPhrase → toEntropy', () {
      final original = Entropy.generate();
      final m1 = Mnemonic.fromEntropy(original);
      final m2 = Mnemonic.fromPhrase(m1.phrase);
      expect(m2.toEntropy(), equals(original));
    });
  });

  // ---- words / phrase / wordCount ----

  group('Mnemonic - getters', () {
    test('words returns unmodifiable list', () {
      final mnemonic = Mnemonic.generate();
      expect(
        () => mnemonic.words.add('test'),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('phrase is space-joined words', () {
      final mnemonic = Mnemonic.generate();
      expect(mnemonic.phrase, equals(mnemonic.words.join(' ')));
    });

    test('wordCount matches words.length', () {
      final mnemonic = Mnemonic.generate();
      expect(mnemonic.wordCount, equals(mnemonic.words.length));
    });
  });

  // ---- Security: toString redaction ----

  group('Mnemonic - security', () {
    test('toString() returns [REDACTED]', () {
      final mnemonic = Mnemonic.generate();
      expect(mnemonic.toString(), equals('Mnemonic[REDACTED]'));
    });

    test('toString() does not contain any word from the phrase', () {
      final mnemonic = Mnemonic.generate();
      for (final word in mnemonic.words) {
        expect(mnemonic.toString().contains(word), isFalse);
      }
    });

    test('phrase getter exposes the actual phrase intentionally', () {
      const phrase = 'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon about';
      final mnemonic = Mnemonic.fromPhrase(phrase);
      expect(mnemonic.phrase, equals(phrase));
    });
  });
}
