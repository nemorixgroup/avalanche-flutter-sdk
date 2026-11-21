// ignore_for_file: lines_longer_than_80_chars

import 'package:avalanche_flutter_sdk/src/chains/cchain/websocket/models/accepted_transaction.dart';
import 'package:flutter_test/flutter_test.dart';

// Live newAcceptedTransactions (fullTx) results captured on Fuji. Only the
// calldata was shortened (the contract creation carried about 4 KB).

// Legacy (type 0x0) contract creation: "to" is null.
Map<String, dynamic> legacyCreation() => <String, dynamic>{
      'blockHash':
          '0x810731966bd5b550c8737c0cb1ede617c591ab93e5bac48d84a84d605f5f1232',
      'blockNumber': '0x3a74ab7',
      'from': '0x4406f0d6115ba233cb413356dc8c91a60a921bc5',
      'gas': '0x16e360',
      'gasPrice': '0x5d21dba00',
      'hash':
          '0x919767b5f5ed6e548da1e219c2c7b826f4b07701b6c016f5ce61da50e57c9b67',
      'input': '0x6080604052',
      'nonce': '0x17',
      'to': null,
      'transactionIndex': '0x0',
      'value': '0x0',
      'type': '0x0',
      'chainId': '0xa869',
      'v': '0x150f5',
      'r': '0x7bc302a83926e7a99542db1238ab80dcf42f111dca0b34c1314b61d3eb0965b9',
      's': '0x235dc5be49f0ae210a82aeeca97fda9e6a81d2cf34a86c74658d9bf8438e2466',
    };

// EIP-1559 (type 0x2) contract call.
Map<String, dynamic> eip1559Call() => <String, dynamic>{
      'blockHash':
          '0x2d4db8c6a455ac4b45a207d91affdb99d1188a0801909e3b3444af0be8400fc8',
      'blockNumber': '0x3a74ab8',
      'from': '0xdd110b48369185e7b7e9c1688a5b258088108c64',
      'gas': '0xd69d',
      'gasPrice': '0x252db46e',
      'maxFeePerGas': '0x252db478',
      'maxPriorityFeePerGas': '0x252db464',
      'hash':
          '0x1d6a80b15369344db97b3e9eb73331bc58957664afaa92a5b3002eaebc1a5573',
      'input': '0x7620d582',
      'nonce': '0x6997a',
      'to': '0xb55002d5b086684f99bd75ea48a1dee959da23a4',
      'transactionIndex': '0x0',
      'value': '0x0',
      'type': '0x2',
      'accessList': <dynamic>[],
      'chainId': '0xa869',
      'v': '0x0',
      'r': '0xb78598b4da62cd144b3b5d8c44babd131cb519c973281295efe4a0617340b308',
      's': '0x14277fd419bc513800342d5a222a81a3ed724243efc26cbc2c5439dc91476d20',
      'yParity': '0x0',
    };

void main() {
  group('AcceptedTransaction - legacy contract creation', () {
    test('parses the live frame', () {
      final tx = AcceptedTransaction.fromJson(legacyCreation());
      expect(tx.blockNumber, equals(0x3a74ab7));
      expect(tx.from, equals('0x4406f0d6115ba233cb413356dc8c91a60a921bc5'));
      expect(tx.gas, equals(BigInt.from(0x16e360)));
      expect(tx.gasPrice, equals(BigInt.from(0x5d21dba00)));
      expect(tx.nonce, equals(0x17));
      expect(tx.value, equals(BigInt.zero));
      expect(tx.type, equals(0));
      expect(tx.chainId, equals(43113));
      expect(tx.v, equals(BigInt.from(0x150f5)));
      expect(tx.r > BigInt.zero, isTrue);
      expect(tx.s > BigInt.zero, isTrue);
    });

    test('a null "to" means contract creation', () {
      final tx = AcceptedTransaction.fromJson(legacyCreation());
      expect(tx.to, isNull);
      expect(tx.isContractCreation, isTrue);
    });

    test('has no EIP-1559 fields', () {
      final tx = AcceptedTransaction.fromJson(legacyCreation());
      expect(tx.isEip1559, isFalse);
      expect(tx.maxFeePerGas, isNull);
      expect(tx.maxPriorityFeePerGas, isNull);
      expect(tx.accessList, isNull);
      expect(tx.yParity, isNull);
    });
  });

  group('AcceptedTransaction - EIP-1559 call', () {
    test('parses the live frame', () {
      final tx = AcceptedTransaction.fromJson(eip1559Call());
      expect(tx.blockNumber, equals(0x3a74ab8));
      expect(tx.to, equals('0xb55002d5b086684f99bd75ea48a1dee959da23a4'));
      expect(tx.gas, equals(BigInt.from(0xd69d)));
      expect(tx.nonce, equals(0x6997a));
      expect(tx.input, equals('0x7620d582'));
      expect(tx.chainId, equals(43113));
    });

    test('parses the EIP-1559 fee fields', () {
      final tx = AcceptedTransaction.fromJson(eip1559Call());
      expect(tx.isEip1559, isTrue);
      expect(tx.isContractCreation, isFalse);
      expect(tx.maxFeePerGas, equals(BigInt.from(0x252db478)));
      expect(tx.maxPriorityFeePerGas, equals(BigInt.from(0x252db464)));
      expect(tx.yParity, equals(0));
      expect(tx.accessList, isEmpty);
    });
  });

  group('AcceptedTransaction - general', () {
    test('valueInAvax converts 1 AVAX', () {
      final json = eip1559Call()..['value'] = '0xde0b6b3a7640000';
      final tx = AcceptedTransaction.fromJson(json);
      expect(tx.valueInAvax, closeTo(1.0, 0.0001));
    });

    test('chainId is null when absent', () {
      final json = legacyCreation()..remove('chainId');
      expect(AcceptedTransaction.fromJson(json).chainId, isNull);
    });

    test('throws a TypeError when a required field is missing', () {
      final json = eip1559Call()..remove('hash');
      expect(
        () => AcceptedTransaction.fromJson(json),
        throwsA(isA<TypeError>()),
      );
    });

    test('toString does not print the calldata', () {
      final tx = AcceptedTransaction.fromJson(legacyCreation());
      expect(tx.toString(), isNot(contains('6080604052')));
    });
  });
}
