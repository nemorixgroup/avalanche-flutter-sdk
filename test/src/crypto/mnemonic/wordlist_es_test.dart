import 'package:avalanche_flutter_sdk/src/crypto/mnemonic/wordlist.dart';
import 'package:avalanche_flutter_sdk/src/crypto/mnemonic/wordlist_es.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---- Singleton ----

  group('WordlistEs - singleton', () {
    test('instance is always the same object', () {
      expect(identical(WordlistEs.instance, WordlistEs.instance), isTrue);
    });
  });

  // ---- Language ----

  group('WordlistEs - language', () {
    test('language is "es"', () {
      expect(WordlistEs.instance.language, equals('es'));
    });
  });

  // ---- BIP-39 structure ----

  group('WordlistEs - BIP-39 structure', () {
    test('contains exactly 2048 words', () {
      expect(WordlistEs.instance.length, equals(Wordlist.requiredLength));
    });

    test('passes BIP-39 validation (length check)', () {
      expect(WordlistEs.instance.validate, returnsNormally);
    });

    test('first word is "ábaco" (index 0)', () {
      expect(WordlistEs.instance.wordAt(0), equals('\u00e1baco'));
    });

    test('last word is "zurdo" (index 2047)', () {
      expect(WordlistEs.instance.wordAt(2047), equals('zurdo'));
    });
  });

  // ---- Accent-insensitive lookup (key feature of Spanish wordlist) ----

  group('WordlistEs - accent-insensitive indexOf', () {
    // Per BIP-39 spec: "Special Spanish characters like 'ñ', 'á', etc.
    // are considered equal to 'n', 'a', etc. in terms of identifying a word."

    test('finds "ábaco" with accented form', () {
      expect(WordlistEs.instance.indexOf('\u00e1baco'), equals(0));
    });

    test('finds "ábaco" with unaccented form "abaco"', () {
      expect(WordlistEs.instance.indexOf('abaco'), equals(0));
    });

    test('finds "domingo" (no accent) correctly', () {
      expect(WordlistEs.instance.indexOf('domingo'), equals(559));
    });

    test('finds "esfera" (no accent) correctly', () {
      expect(WordlistEs.instance.indexOf('esfera'), equals(637));
    });

    test('finds word with ñ: "añadir" with accented ñ', () {
      // ñ in NFC form: U+00F1
      expect(WordlistEs.instance.indexOf('\u00e1\u00f1adir'), greaterThan(-1));
    });

    test('finds word with ñ: "caña" with unaccented "cana"', () {
      final indexWithAccent = WordlistEs.instance.indexOf('ca\u00f1a');
      final indexWithoutAccent = WordlistEs.instance.indexOf('cana');
      expect(indexWithAccent, equals(indexWithoutAccent));
      expect(indexWithAccent, greaterThan(-1));
    });
  });

  // ---- Case insensitivity ----

  group('WordlistEs - case insensitive indexOf', () {
    test('finds word in lowercase', () {
      expect(WordlistEs.instance.indexOf('domingo'), greaterThan(-1));
    });

    test('finds word in uppercase', () {
      expect(
        WordlistEs.instance.indexOf('DOMINGO'),
        equals(WordlistEs.instance.indexOf('domingo')),
      );
    });

    test('finds word in mixed case', () {
      expect(
        WordlistEs.instance.indexOf('Domingo'),
        equals(WordlistEs.instance.indexOf('domingo')),
      );
    });
  });

  // ---- Round-trip consistency ----

  group('WordlistEs - round-trip wordAt/indexOf', () {
    test('wordAt and indexOf are consistent at index 0', () {
      final word = WordlistEs.instance.wordAt(0);
      expect(WordlistEs.instance.indexOf(word), equals(0));
    });

    test('wordAt and indexOf are consistent at index 2047', () {
      final word = WordlistEs.instance.wordAt(2047);
      expect(WordlistEs.instance.indexOf(word), equals(2047));
    });

    test('wordAt and indexOf are consistent at index 559 (domingo)', () {
      final word = WordlistEs.instance.wordAt(559);
      expect(WordlistEs.instance.indexOf(word), equals(559));
    });
  });

  // ---- Invalid words ----

  group('WordlistEs - invalid words', () {
    test('returns -1 for word not in list', () {
      expect(WordlistEs.instance.indexOf('flutter'), equals(-1));
    });

    test('returns false for contains with invalid word', () {
      expect(WordlistEs.instance.contains('notaword'), isFalse);
    });

    test('returns -1 for empty string', () {
      expect(WordlistEs.instance.indexOf(''), equals(-1));
    });
  });

  // ---- ñ sorting: Spanish alphabet has ñ after n ----

  group('WordlistEs - Spanish alphabet ordering', () {
    test('"anuncio" and "añadir" are both in the wordlist', () {
      expect(WordlistEs.instance.contains('anuncio'), isTrue);
      // ignore: unnecessary_lambdas
      expect(WordlistEs.instance.indexOf('a\u00f1adir'), greaterThan(-1));
    });

    test('"anuncio" appears before "añadir" in the official order', () {
      final indexAnuncio = WordlistEs.instance.indexOf('anuncio');
      final indexAnadir = WordlistEs.instance.indexOf('a\u00f1adir');
      expect(indexAnuncio, lessThan(indexAnadir));
    });
  });
}
