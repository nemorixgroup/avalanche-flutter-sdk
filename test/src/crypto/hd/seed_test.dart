import 'package:avalanche_flutter_sdk/src/crypto/hd/seed.dart';
import 'package:avalanche_flutter_sdk/src/crypto/mnemonic/mnemonic.dart';
import 'package:avalanche_flutter_sdk/src/crypto/mnemonic/wordlist_es.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---- Official BIP-39 test vectors ----
  // Source: https://github.com/trezor/python-mnemonic/blob/master/vectors.json
  // Passphrase used in all official vectors: "TREZOR"

  group('Seed - BIP-39 official test vectors', () {
    test('vector 1: abandon x11 + about, passphrase TREZOR', () {
      // Entropy: 00000000000000000000000000000000
      const phrase = 'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon about';
      const expectedHex = 'c55257c360c07c72029aebc1b53c05ed0362ada38ead3e'
          '3e9efa3708e53495531f09a6987599d18264c1e1c92f2c'
          'f141630c7a3c4ab7c81b2f001698e7463b04';

      final seed = Seed.fromPhrase(phrase, passphrase: 'TREZOR');
      expect(seed.toHex(), equals(expectedHex));
    });

    test('vector 2: legal winner... yellow, passphrase TREZOR', () {
      const phrase = 'legal winner thank year wave sausage '
          'worth useful legal winner thank yellow';
      // Source: github.com/trezor/python-mnemonic/blob/master/vectors.json
      const expectedHex =
          '2e8905819b8723fe2c1d161860e5ee1830318dbf49a83bd451cfb8440c28bd6f'
          'a457fe1296106559a3c80937a1c1069be3a3a5bd381ee6260e8d9739fce1f607';
      final seed = Seed.fromPhrase(phrase, passphrase: 'TREZOR');
      expect(seed.toHex(), equals(expectedHex));
    });

    test('vector 3: letter advice... above, passphrase TREZOR', () {
      const phrase = 'letter advice cage absurd amount doctor '
          'acoustic avoid letter advice cage above';
      // Source: github.com/trezor/python-mnemonic/blob/master/vectors.json
      const expectedHex =
          'd71de856f81a8acc65e6fc851a38d4d7ec216fd0796d0a6827a3ad6ed5511a30'
          'fa280f12eb2e47ed2ac03b5c462a0358d18d69fe4f985ec81778c1b370b652a8';
      final seed = Seed.fromPhrase(phrase, passphrase: 'TREZOR');
      expect(seed.toHex(), equals(expectedHex));
    });
  });

  // ---- No passphrase (empty string) ----

  group('Seed - no passphrase', () {
    test('empty passphrase produces different seed than "TREZOR"', () {
      const phrase = 'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon about';

      final seedNoPass = Seed.fromPhrase(phrase);
      final seedTrezor = Seed.fromPhrase(phrase, passphrase: 'TREZOR');

      expect(seedNoPass.toHex(), isNot(equals(seedTrezor.toHex())));
    });

    test('default passphrase is empty string', () {
      const phrase = 'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon about';

      final seed1 = Seed.fromPhrase(phrase);
      final seed2 = Seed.fromPhrase(phrase);

      expect(seed1.toHex(), equals(seed2.toHex()));
    });
  });

  // ---- fromMnemonic() ----

  group('Seed.fromMnemonic', () {
    test('produces same result as fromPhrase for same phrase', () {
      const phrase = 'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon about';

      final mnemonic = Mnemonic.fromPhrase(phrase);
      final seedFromMnemonic =
          Seed.fromMnemonic(mnemonic, passphrase: 'TREZOR');
      final seedFromPhrase = Seed.fromPhrase(phrase, passphrase: 'TREZOR');

      expect(seedFromMnemonic.toHex(), equals(seedFromPhrase.toHex()));
    });

    test('generates a valid seed from a random mnemonic', () {
      final mnemonic = Mnemonic.generate();
      final seed = Seed.fromMnemonic(mnemonic);
      expect(seed.bytes.length, equals(Seed.seedLength));
    });

    test('same mnemonic always produces same seed (deterministic)', () {
      final mnemonic = Mnemonic.generate();
      final seed1 = Seed.fromMnemonic(mnemonic);
      final seed2 = Seed.fromMnemonic(mnemonic);
      expect(seed1.toHex(), equals(seed2.toHex()));
    });

    test('different mnemonics produce different seeds', () {
      final m1 = Mnemonic.generate();
      final m2 = Mnemonic.generate();
      final s1 = Seed.fromMnemonic(m1);
      final s2 = Seed.fromMnemonic(m2);
      expect(s1.toHex(), isNot(equals(s2.toHex())));
    });
  });

  // ---- Output format ----

  group('Seed - output format', () {
    test('bytes returns exactly 64 bytes', () {
      final seed = Seed.fromPhrase('abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon abandon abandon about');
      expect(seed.bytes.length, equals(64));
    });

    test('toHex returns exactly 128 hex chars', () {
      final seed = Seed.fromPhrase('abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon abandon abandon about');
      expect(seed.toHex().length, equals(128));
    });

    test('bytes returns a copy (modifying it does not affect seed)', () {
      final seed = Seed.fromPhrase('abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon abandon abandon about');
      final copy = seed.bytes;
      copy[0] = 0xff;
      expect(seed.bytes[0], isNot(equals(0xff)));
    });
  });

  // ---- Security ----

  group('Seed - security', () {
    test('toString() returns [REDACTED]', () {
      final seed = Seed.fromPhrase('abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon abandon abandon about');
      expect(seed.toString(), equals('Seed[REDACTED]'));
    });

    test('toString() does not contain seed hex', () {
      final seed = Seed.fromPhrase('abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon abandon abandon about');
      expect(seed.toString().contains(seed.toHex()), isFalse);
    });
  });

  // ---- Spanish mnemonic ----

  group('Seed - Spanish wordlist', () {
    test('Spanish mnemonic produces a valid 64-byte seed', () {
      final mnemonic = Mnemonic.generate(wordlist: WordlistEs.instance);
      final seed = Seed.fromMnemonic(mnemonic);
      expect(seed.bytes.length, equals(64));
    });

    test('same Spanish mnemonic always produces same seed', () {
      final mnemonic = Mnemonic.generate(wordlist: WordlistEs.instance);
      final s1 = Seed.fromMnemonic(mnemonic);
      final s2 = Seed.fromMnemonic(mnemonic);
      expect(s1.toHex(), equals(s2.toHex()));
    });
  });
}
