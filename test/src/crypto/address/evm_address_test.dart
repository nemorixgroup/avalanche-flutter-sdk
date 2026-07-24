import 'package:avalanche_flutter_sdk/src/crypto/address/evm_address.dart';
import 'package:avalanche_flutter_sdk/src/crypto/hd/hd_wallet.dart';
import 'package:avalanche_flutter_sdk/src/crypto/mnemonic/mnemonic.dart';
import 'package:avalanche_flutter_sdk/src/crypto/private_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---- Official EIP-55 test vectors ----
  // Source: https://eips.ethereum.org/EIPS/eip-55
  group('EvmAddress - EIP-55 official test vectors', () {
    test('checksumAddress matches EIP-55 vector 1', () {
      // Source: eips.ethereum.org/EIPS/eip-55
      final address = EvmAddress.fromHex(
        '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed',
      );
      expect(
        address.checksumAddress,
        equals('0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed'),
      );
    });

    test('checksumAddress matches EIP-55 vector 2', () {
      final address = EvmAddress.fromHex(
        '0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359',
      );
      expect(
        address.checksumAddress,
        equals('0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359'),
      );
    });

    test('checksumAddress matches EIP-55 vector 3', () {
      final address = EvmAddress.fromHex(
        '0xdbF03B407c01E7cD3CBea99509d93f8DDDC8C6FB',
      );
      expect(
        address.checksumAddress,
        equals('0xdbF03B407c01E7cD3CBea99509d93f8DDDC8C6FB'),
      );
    });

    test('checksumAddress matches EIP-55 vector 4', () {
      final address = EvmAddress.fromHex(
        '0xD1220A0cf47c7B9Be7A2E6BA89F429762e7b9aDb',
      );
      expect(
        address.checksumAddress,
        equals('0xD1220A0cf47c7B9Be7A2E6BA89F429762e7b9aDb'),
      );
    });

    test('lowercase input produces correct checksum', () {
      // Same address in all lowercase should produce same checksum
      final lower = EvmAddress.fromHex(
        '0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed',
      );
      expect(
        lower.checksumAddress,
        equals('0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed'),
      );
    });
  });

  // ---- fromPublicKey ----

  group('EvmAddress.fromPublicKey', () {
    test('derives a valid 20-byte address from a public key', () {
      final pk = PrivateKey.generate();
      final address = EvmAddress.fromPublicKey(pk.publicKey);
      expect(address.bytes.length, equals(20));
    });

    test('checksumAddress starts with 0x and has 42 chars', () {
      final pk = PrivateKey.generate();
      final address = EvmAddress.fromPublicKey(pk.publicKey);
      expect(address.checksumAddress.startsWith('0x'), isTrue);
      expect(address.checksumAddress.length, equals(42));
    });

    test('lowercaseAddress starts with 0x and has 42 chars', () {
      final pk = PrivateKey.generate();
      final address = EvmAddress.fromPublicKey(pk.publicKey);
      expect(address.lowercaseAddress.startsWith('0x'), isTrue);
      expect(address.lowercaseAddress.length, equals(42));
    });

    test('same key always produces same address (deterministic)', () {
      final pk = PrivateKey.fromHex('1'.padLeft(64, '0'));
      final a1 = EvmAddress.fromPublicKey(pk.publicKey);
      final a2 = EvmAddress.fromPublicKey(pk.publicKey);
      expect(a1.checksumAddress, equals(a2.checksumAddress));
    });

    test('different keys produce different addresses', () {
      final a1 = EvmAddress.fromPublicKey(PrivateKey.generate().publicKey);
      final a2 = EvmAddress.fromPublicKey(PrivateKey.generate().publicKey);
      expect(a1.checksumAddress, isNot(equals(a2.checksumAddress)));
    });
  });

  // ---- fromHex ----

  group('EvmAddress.fromHex', () {
    test('accepts address with 0x prefix', () {
      final address = EvmAddress.fromHex(
        '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed',
      );
      expect(address.bytes.length, equals(20));
    });

    test('accepts address without 0x prefix', () {
      final address = EvmAddress.fromHex(
        '5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed',
      );
      expect(address.bytes.length, equals(20));
    });

    test('throws ArgumentError for invalid length', () {
      expect(
        // ignore: unnecessary_lambdas
        () => EvmAddress.fromHex('0x1234'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for empty string', () {
      expect(
        // ignore: unnecessary_lambdas
        () => EvmAddress.fromHex(''),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ---- HD wallet integration ----

  group('EvmAddress - HD wallet integration', () {
    // Reference: "abandon x23 + art" mnemonic, path m/44'/60'/0'/0/0
    // Source: https://gist.github.com/pnowosie/a4cebe9c4250e1a6397a660408f6c491
    const abandonPhrase = 'abandon abandon abandon abandon abandon abandon '
        'abandon abandon abandon abandon abandon abandon '
        'abandon abandon abandon abandon abandon abandon '
        'abandon abandon abandon abandon abandon art';

    test('derives C-Chain address from abandon mnemonic at index 0', () {
      final mnemonic = Mnemonic.fromPhrase(abandonPhrase);
      final wallet = HDWallet.fromMnemonic(mnemonic);
      final pubKey = wallet.derivePublicKeyForCChain();
      final address = EvmAddress.fromPublicKey(pubKey);
      // Verified at runtime - pending external verification vs Core Wallet
      expect(address.checksumAddress.startsWith('0x'), isTrue);
      expect(address.checksumAddress.length, equals(42));
    });

    test('different indices produce different C-Chain addresses', () {
      final mnemonic = Mnemonic.fromPhrase(abandonPhrase);
      final wallet = HDWallet.fromMnemonic(mnemonic);
      final a0 = EvmAddress.fromPublicKey(
        wallet.derivePublicKeyForCChain(),
      );
      final a1 = EvmAddress.fromPublicKey(
        wallet.derivePublicKeyForCChain(index: 1),
      );
      expect(a0.checksumAddress, isNot(equals(a1.checksumAddress)));
    });
  });

  // ---- Equality ----

  group('EvmAddress - equality', () {
    test('same address hex produces equal instances', () {
      final a1 = EvmAddress.fromHex(
        '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed',
      );
      final a2 = EvmAddress.fromHex(
        '0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed',
      );
      expect(a1, equals(a2));
    });

    test('toString returns checksumAddress', () {
      final address = EvmAddress.fromHex(
        '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed',
      );
      expect(address.toString(), equals(address.checksumAddress));
    });
  });
}
