import 'package:avalanche_flutter_sdk/src/crypto/mnemonic/wordlist.dart';
import 'package:flutter_test/flutter_test.dart';

// ---- TestWordlist: minimal concrete implementation for testing ----

class _TestWordlist extends Wordlist {
  _TestWordlist(this._words);

  final List<String> _words;

  @override
  String get language => 'test';

  @override
  List<String> get words => _words;
}

/// Generates a sorted list of N unique words for testing.
List<String> _sortedWords(int count) {
  return List.generate(count, (i) => 'word${i.toString().padLeft(4, '0')}')
    ..sort();
}

void main() {
  // ---- Constants ----

  group('Wordlist constants', () {
    test('requiredLength is 2048', () {
      expect(Wordlist.requiredLength, equals(2048));
    });
  });

  // ---- length ----

  group('Wordlist.length', () {
    test('returns the number of words', () {
      final wl = _TestWordlist(_sortedWords(2048));
      expect(wl.length, equals(2048));
    });
  });

  // ---- wordAt ----

  group('Wordlist.wordAt', () {
    late _TestWordlist wl;

    setUp(() => wl = _TestWordlist(_sortedWords(2048)));

    test('returns word at index 0', () {
      expect(wl.wordAt(0), equals('word0000'));
    });

    test('returns word at index 2047 (last)', () {
      expect(wl.wordAt(2047), equals('word2047'));
    });

    test('returns word at arbitrary index', () {
      expect(wl.wordAt(100), equals('word0100'));
    });

    test('throws RangeError for index -1', () {
      expect(() => wl.wordAt(-1), throwsA(isA<RangeError>()));
    });

    test('throws RangeError for index 2048', () {
      expect(() => wl.wordAt(2048), throwsA(isA<RangeError>()));
    });
  });

  // ---- indexOf (binary search) ----

  group('Wordlist.indexOf', () {
    late _TestWordlist wl;

    setUp(() => wl = _TestWordlist(_sortedWords(2048)));

    test('finds word at index 0', () {
      expect(wl.indexOf('word0000'), equals(0));
    });

    test('finds word at index 2047 (last)', () {
      expect(wl.indexOf('word2047'), equals(2047));
    });

    test('finds word at arbitrary index', () {
      expect(wl.indexOf('word0500'), equals(500));
    });

    test('returns -1 for word not in list', () {
      expect(wl.indexOf('notaword'), equals(-1));
    });

    test('returns -1 for empty string', () {
      expect(wl.indexOf(''), equals(-1));
    });

    test('wordAt and indexOf are consistent (round-trip)', () {
      for (final i in [0, 1, 100, 1000, 2046, 2047]) {
        final word = wl.wordAt(i);
        expect(wl.indexOf(word), equals(i));
      }
    });
  });

  // ---- contains ----

  group('Wordlist.contains', () {
    late _TestWordlist wl;

    setUp(() => wl = _TestWordlist(_sortedWords(2048)));

    test('returns true for existing word', () {
      expect(wl.contains('word0000'), isTrue);
      expect(wl.contains('word1024'), isTrue);
      expect(wl.contains('word2047'), isTrue);
    });

    test('returns false for non-existing word', () {
      expect(wl.contains('notaword'), isFalse);
    });

    test('returns false for empty string', () {
      expect(wl.contains(''), isFalse);
    });
  });

  // ---- validate ----

  group('Wordlist.validate', () {
    test('passes for valid 2048-word sorted wordlist', () {
      final wl = _TestWordlist(_sortedWords(2048));
      // ignore: unnecessary_lambdas
      expect(() => wl.validate(), returnsNormally);
    });

    test('throws StateError for wordlist with fewer than 2048 words', () {
      final wl = _TestWordlist(_sortedWords(2047));
      // ignore: unnecessary_lambdas
      expect(() => wl.validate(), throwsA(isA<StateError>()));
    });

    test('throws StateError for wordlist with more than 2048 words', () {
      final wl = _TestWordlist(_sortedWords(2049));
      // ignore: unnecessary_lambdas
      expect(() => wl.validate(), throwsA(isA<StateError>()));
    });

    test('throws StateError for unsorted wordlist', () {
      final unsorted = _sortedWords(2048)
        ..insert(0, 'zzzzz')
        ..removeLast();
      final wl = _TestWordlist(unsorted);
      // ignore: unnecessary_lambdas
      expect(() => wl.validate(), throwsA(isA<StateError>()));
    });

    test('throws StateError for wordlist with duplicate words', () {
      final withDupe = _sortedWords(2048);
      withDupe[100] = withDupe[99]; // duplicate
      final wl = _TestWordlist(withDupe);
      // ignore: unnecessary_lambdas
      expect(() => wl.validate(), throwsA(isA<StateError>()));
    });
  });
}
