import 'package:avalanche_flutter_sdk/src/chains/cchain/transaction/avax_transfer_tx.dart';
import 'package:avalanche_flutter_sdk/src/crypto/private_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Known test address (EIP-55 checksummed)
  const testAddress = '0x71C7656EC7ab88b098defB751B7401B5f6d8976F';

  // Known private key for deterministic tests
  final testKey = PrivateKey.fromHex('1'.padLeft(64, '0'));

  AvaxTransferTransaction buildTx({
    int chainId = 43113,
    int nonce = 0,
    BigInt? maxPriorityFeePerGas,
    BigInt? maxFeePerGas,
    BigInt? gasLimit,
    String to = testAddress,
    BigInt? value,
  }) {
    return AvaxTransferTransaction(
      chainId: chainId,
      nonce: nonce,
      maxPriorityFeePerGas: maxPriorityFeePerGas ?? BigInt.from(25000000000),
      maxFeePerGas: maxFeePerGas ?? BigInt.from(50000000000),
      gasLimit: gasLimit ?? BigInt.from(21000),
      to: to,
      value: value ?? BigInt.from(10000000000000000), // 0.01 AVAX
    );
  }

  // ---- unsignedHash ----

  group('AvaxTransferTransaction.unsignedHash', () {
    test('returns exactly 32 bytes', () {
      final hash = buildTx().unsignedHash();
      expect(hash.length, equals(32));
    });

    test('is deterministic for same fields', () {
      final tx = buildTx();
      final hash1 = tx.unsignedHash();
      final hash2 = tx.unsignedHash();
      expect(hash1, equals(hash2));
    });

    test('changes when chainId changes', () {
      final hash1 = buildTx().unsignedHash();
      final hash2 = buildTx(chainId: 43114).unsignedHash();
      expect(hash1, isNot(equals(hash2)));
    });

    test('changes when nonce changes', () {
      final hash1 = buildTx().unsignedHash();
      final hash2 = buildTx(nonce: 1).unsignedHash();
      expect(hash1, isNot(equals(hash2)));
    });

    test('changes when value changes', () {
      final hash1 = buildTx(value: BigInt.from(1000)).unsignedHash();
      final hash2 = buildTx(value: BigInt.from(2000)).unsignedHash();
      expect(hash1, isNot(equals(hash2)));
    });

    test('changes when to address changes', () {
      final hash1 = buildTx().unsignedHash();
      final hash2 = buildTx(
        to: '0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359',
      ).unsignedHash();
      expect(hash1, isNot(equals(hash2)));
    });
  });

  // ---- sign ----

  group('AvaxTransferTransaction.sign', () {
    test('returns hex string starting with 0x02', () {
      final rawTx = buildTx().sign(testKey);
      expect(rawTx.startsWith('0x02'), isTrue);
    });

    test('returns lowercase hex string', () {
      final rawTx = buildTx().sign(testKey);
      expect(rawTx, equals(rawTx.toLowerCase()));
    });

    test('is deterministic (same inputs -> same raw tx)', () {
      final tx = buildTx();
      final raw1 = tx.sign(testKey);
      final raw2 = tx.sign(testKey);
      expect(raw1, equals(raw2));
    });

    test('different keys produce different raw transactions', () {
      final tx = buildTx();
      final key2 = PrivateKey.fromHex('2'.padLeft(64, '0'));
      final raw1 = tx.sign(testKey);
      final raw2 = tx.sign(key2);
      expect(raw1, isNot(equals(raw2)));
    });

    test('different nonces produce different raw transactions', () {
      final raw1 = buildTx().sign(testKey);
      final raw2 = buildTx(nonce: 1).sign(testKey);
      expect(raw1, isNot(equals(raw2)));
    });

    test('accepts address without 0x prefix', () {
      final tx = buildTx(
        to: '71C7656EC7ab88b098defB751B7401B5f6d8976F',
      );
      expect(() => tx.sign(testKey), returnsNormally);
    });

    test('throws ArgumentError for invalid address length', () {
      final tx = buildTx(to: '0x1234');
      // ignore: unnecessary_lambdas
      expect(() => tx.sign(testKey), throwsA(isA<ArgumentError>()));
    });

    test('raw tx is valid hex (all chars are hex digits)', () {
      final rawTx = buildTx().sign(testKey);
      final hexPart = rawTx.substring(2); // remove 0x
      final hexRegex = RegExp(r'^[0-9a-f]+$');
      expect(hexRegex.hasMatch(hexPart), isTrue);
    });

    test('Fuji chainId (43113) and Mainnet (43114) produce different txs', () {
      final rawFuji = buildTx().sign(testKey);
      final rawMainnet = buildTx(chainId: 43114).sign(testKey);
      expect(rawFuji, isNot(equals(rawMainnet)));
    });
  });
}
