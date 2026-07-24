import 'package:avalanche_flutter_sdk/src/crypto/address/xp_address.dart';
import 'package:avalanche_flutter_sdk/src/crypto/hd/hd_wallet.dart';
import 'package:avalanche_flutter_sdk/src/crypto/mnemonic/mnemonic.dart';
import 'package:avalanche_flutter_sdk/src/crypto/private_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---- Algorithm verification ----
  // Source: https://docs.avax.network/docs/rpcs/other/standards/cryptographic-primitives
  // "The 33-byte compressed representation of the public key is hashed with
  //  sha256 once. The result is then hashed with ripemd160 to yield a
  //  20-byte address."

  group('XPAddress - address format', () {
    test('X-Chain mainnet address starts with X-avax1', () {
      final pk = PrivateKey.generate();
      final address = XPAddress.fromPublicKey(pk.publicKey);
      expect(address.xChainAddress(), startsWith('X-avax1'));
    });

    test('P-Chain mainnet address starts with P-avax1', () {
      final pk = PrivateKey.generate();
      final address = XPAddress.fromPublicKey(pk.publicKey);
      expect(address.pChainAddress(), startsWith('P-avax1'));
    });

    test('X-Chain Fuji address starts with X-fuji1', () {
      final pk = PrivateKey.generate();
      final address = XPAddress.fromPublicKey(pk.publicKey);
      expect(
        address.xChainAddress(network: AvalancheNetwork.fuji),
        startsWith('X-fuji1'),
      );
    });

    test('P-Chain Fuji address starts with P-fuji1', () {
      final pk = PrivateKey.generate();
      final address = XPAddress.fromPublicKey(pk.publicKey);
      expect(
        address.pChainAddress(network: AvalancheNetwork.fuji),
        startsWith('P-fuji1'),
      );
    });

    test('X-Chain and P-Chain share same 20-byte address (same bech32 data)',
        () {
      final pk = PrivateKey.generate();
      final address = XPAddress.fromPublicKey(pk.publicKey);
      final xAddr = address.xChainAddress();
      final pAddr = address.pChainAddress();
      // Strip chain prefix - everything after "X-" and "P-" should be equal
      expect(xAddr.substring(2), equals(pAddr.substring(2)));
    });
  });

  group('XPAddress - bytes', () {
    test('raw bytes are exactly 20 bytes', () {
      final pk = PrivateKey.generate();
      final address = XPAddress.fromPublicKey(pk.publicKey);
      expect(address.bytes.length, equals(20));
    });

    test('bytes returns a defensive copy', () {
      final pk = PrivateKey.generate();
      final address = XPAddress.fromPublicKey(pk.publicKey);
      final copy = address.bytes;
      copy[0] = 0xff;
      expect(address.bytes[0], isNot(equals(0xff)));
    });
  });

  group('XPAddress - determinism', () {
    test('same public key always produces same address', () {
      final pk = PrivateKey.fromHex('1'.padLeft(64, '0'));
      final a1 = XPAddress.fromPublicKey(pk.publicKey);
      final a2 = XPAddress.fromPublicKey(pk.publicKey);
      expect(a1.xChainAddress(), equals(a2.xChainAddress()));
    });

    test('different keys produce different addresses', () {
      final a1 = XPAddress.fromPublicKey(PrivateKey.generate().publicKey);
      final a2 = XPAddress.fromPublicKey(PrivateKey.generate().publicKey);
      expect(a1.xChainAddress(), isNot(equals(a2.xChainAddress())));
    });
  });

  group('XPAddress - Bech32 structure', () {
    test('mainnet address has correct total length', () {
      // X- (2) + avax1 (5) + 32 data chars + 6 checksum = 45
      final pk = PrivateKey.generate();
      final address = XPAddress.fromPublicKey(pk.publicKey);
      expect(address.xChainAddress().length, equals(45));
    });

    test('fuji address has correct total length', () {
      // X- (2) + fuji1 (5) + 32 data chars + 6 checksum = 45
      final pk = PrivateKey.generate();
      final address = XPAddress.fromPublicKey(pk.publicKey);
      expect(
        address.xChainAddress(network: AvalancheNetwork.fuji).length,
        equals(45),
      );
    });

    test('address only contains valid Bech32 characters after prefix', () {
      const validChars = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';
      final pk = PrivateKey.generate();
      final address = XPAddress.fromPublicKey(pk.publicKey);
      // Strip "X-avax1" prefix
      final bech32Part = address.xChainAddress().substring(7);
      for (final c in bech32Part.split('')) {
        expect(validChars.contains(c), isTrue);
      }
    });
  });

  group('XPAddress - equality', () {
    test('same key produces equal XPAddress instances', () {
      final pk = PrivateKey.fromHex('1'.padLeft(64, '0'));
      final a1 = XPAddress.fromPublicKey(pk.publicKey);
      final a2 = XPAddress.fromPublicKey(pk.publicKey);
      expect(a1, equals(a2));
    });

    test('toString includes X-Chain mainnet address', () {
      final pk = PrivateKey.generate();
      final address = XPAddress.fromPublicKey(pk.publicKey);
      expect(address.toString(), startsWith('XPAddress(X-avax1'));
    });
  });

  group('XPAddress - HD wallet integration', () {
    const abandonPhrase = 'abandon abandon abandon abandon abandon abandon '
        'abandon abandon abandon abandon abandon abandon '
        'abandon abandon abandon abandon abandon abandon '
        'abandon abandon abandon abandon abandon art';

    test('derives X/P-Chain address from abandon mnemonic at index 0', () {
      final mnemonic = Mnemonic.fromPhrase(abandonPhrase);
      final wallet = HDWallet.fromMnemonic(mnemonic);
      final pubKey = wallet.derivePublicKeyForXPChain();
      final address = XPAddress.fromPublicKey(pubKey);
      expect(address.xChainAddress(), startsWith('X-avax1'));
      expect(address.xChainAddress().length, equals(45));
    });

    test('different indices produce different X/P-Chain addresses', () {
      final mnemonic = Mnemonic.fromPhrase(abandonPhrase);
      final wallet = HDWallet.fromMnemonic(mnemonic);
      final a0 = XPAddress.fromPublicKey(
        wallet.derivePublicKeyForXPChain(),
      );
      final a1 = XPAddress.fromPublicKey(
        wallet.derivePublicKeyForXPChain(index: 1),
      );
      expect(a0.xChainAddress(), isNot(equals(a1.xChainAddress())));
    });

    test('C-Chain and X/P-Chain addresses are different (different paths)', () {
      final mnemonic = Mnemonic.fromPhrase(abandonPhrase);
      final wallet = HDWallet.fromMnemonic(mnemonic);
      final evmPubKey = wallet.derivePublicKeyForCChain();
      final xpPubKey = wallet.derivePublicKeyForXPChain();
      expect(evmPubKey.toHex(), isNot(equals(xpPubKey.toHex())));
    });
  });
}
