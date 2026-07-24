import 'package:avalanche_flutter_sdk/src/crypto/hd/hd_wallet.dart';
import 'package:avalanche_flutter_sdk/src/crypto/hd/seed.dart';
import 'package:avalanche_flutter_sdk/src/crypto/mnemonic/mnemonic.dart';
import 'package:avalanche_flutter_sdk/src/crypto/mnemonic/wordlist_es.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---- Official test vector ----
  // Mnemonic: "abandon abandon abandon ... art" (24 words, all-zeros entropy)
  // Source: https://gist.github.com/pnowosie/a4cebe9c4250e1a6397a660408f6c491
  // Path m/44'/60'/0'/0/0 → 0xF278cF59F82eDcf871d630F28EcC8056f25C1cdb

  const abandonPhrase = 'abandon abandon abandon abandon abandon abandon '
      'abandon abandon abandon abandon abandon abandon '
      'abandon abandon abandon abandon abandon abandon '
      'abandon abandon abandon abandon abandon art';

  group('HDWallet - BIP-44 C-Chain derivation', () {
    test("derives private key at m/44'/60'/0'/0/0 (index 0)", () {
      final mnemonic = Mnemonic.fromPhrase(abandonPhrase);
      final wallet = HDWallet.fromMnemonic(mnemonic);
      final privateKey = wallet.derivePrivateKeyForCChain();
      expect(privateKey.toHex().length, equals(64));
    });

    test('derives different keys for different indices', () {
      final mnemonic = Mnemonic.fromPhrase(abandonPhrase);
      final wallet = HDWallet.fromMnemonic(mnemonic);
      final key0 = wallet.derivePrivateKeyForCChain();
      final key1 = wallet.derivePrivateKeyForCChain(index: 1);
      expect(key0.toHex(), isNot(equals(key1.toHex())));
    });

    test('derivation is deterministic (same key for same index)', () {
      final mnemonic = Mnemonic.fromPhrase(abandonPhrase);
      final wallet = HDWallet.fromMnemonic(mnemonic);
      final key1 = wallet.derivePrivateKeyForCChain();
      final key2 = wallet.derivePrivateKeyForCChain();
      expect(key1.toHex(), equals(key2.toHex()));
    });

    test('derives public key for C-Chain', () {
      final mnemonic = Mnemonic.fromPhrase(abandonPhrase);
      final wallet = HDWallet.fromMnemonic(mnemonic);
      final pubKey = wallet.derivePublicKeyForCChain();
      expect(pubKey.toCompressed().length, equals(33));
    });
  });

  group('HDWallet - BIP-44 X/P-Chain derivation', () {
    test("derives private key at m/44'/9000'/0'/0/0", () {
      final mnemonic = Mnemonic.fromPhrase(abandonPhrase);
      final wallet = HDWallet.fromMnemonic(mnemonic);
      final key = wallet.derivePrivateKeyForXPChain();
      expect(key.toHex().length, equals(64));
    });

    test('C-Chain and X/P-Chain keys are different', () {
      final mnemonic = Mnemonic.fromPhrase(abandonPhrase);
      final wallet = HDWallet.fromMnemonic(mnemonic);
      final cKey = wallet.derivePrivateKeyForCChain();
      final xpKey = wallet.derivePrivateKeyForXPChain();
      expect(cKey.toHex(), isNot(equals(xpKey.toHex())));
    });

    test('derives public key for X/P-Chain', () {
      final mnemonic = Mnemonic.fromPhrase(abandonPhrase);
      final wallet = HDWallet.fromMnemonic(mnemonic);
      final pubKey = wallet.derivePublicKeyForXPChain();
      expect(pubKey.toCompressed().length, equals(33));
    });
  });

  group('HDWallet.fromSeed', () {
    test('produces same result as fromMnemonic', () {
      final mnemonic = Mnemonic.fromPhrase(abandonPhrase);
      final seed = Seed.fromMnemonic(mnemonic);
      final walletFromMnemonic = HDWallet.fromMnemonic(mnemonic);
      final walletFromSeed = HDWallet.fromSeed(seed);
      final key1 = walletFromMnemonic.derivePrivateKeyForCChain();
      final key2 = walletFromSeed.derivePrivateKeyForCChain();
      expect(key1.toHex(), equals(key2.toHex()));
    });
  });

  group('HDWallet - different mnemonics', () {
    test('different mnemonics produce different keys', () {
      final m1 = Mnemonic.generate();
      final m2 = Mnemonic.generate();
      final w1 = HDWallet.fromMnemonic(m1);
      final w2 = HDWallet.fromMnemonic(m2);
      final k1 = w1.derivePrivateKeyForCChain();
      final k2 = w2.derivePrivateKeyForCChain();
      expect(k1.toHex(), isNot(equals(k2.toHex())));
    });

    test('Spanish mnemonic derives valid keys', () {
      final mnemonic = Mnemonic.generate(wordlist: WordlistEs.instance);
      final wallet = HDWallet.fromMnemonic(mnemonic);
      final key = wallet.derivePrivateKeyForCChain();
      expect(key.toHex().length, equals(64));
    });
  });

  group('HDWallet - security', () {
    test('toString returns [REDACTED]', () {
      final mnemonic = Mnemonic.fromPhrase(abandonPhrase);
      final wallet = HDWallet.fromMnemonic(mnemonic);
      expect(wallet.toString(), equals('HDWallet[REDACTED]'));
    });
  });
}
