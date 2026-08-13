// test/src/chains/cchain/cchain_client_test.dart

import 'dart:convert';

import 'package:avalanche_flutter_sdk/src/chains/cchain/cchain_client.dart';
import 'package:avalanche_flutter_sdk/src/client/network_config.dart';
import 'package:avalanche_flutter_sdk/src/exceptions/avalanche_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'cchain_client_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  late MockClient mockHttp;
  late CChainClient client;

  setUp(() {
    mockHttp = MockClient();
    client = CChainClient(
      network: NetworkConfig.fuji,
      httpClient: mockHttp,
    );
  });

  // ---- Helper ----

  void mockResponse(String result) {
    when(
      mockHttp.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      ),
    ).thenAnswer(
      (_) async => http.Response(
        jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': result}),
        200,
      ),
    );
  }

  void mockMapResponse(Map<String, dynamic> result) {
    when(
      mockHttp.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      ),
    ).thenAnswer(
      (_) async => http.Response(
        jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': result}),
        200,
      ),
    );
  }

  void mockError(int code, String message) {
    when(
      mockHttp.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      ),
    ).thenAnswer(
      (_) async => http.Response(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'error': {'code': code, 'message': message},
        }),
        200,
      ),
    );
  }

  // ---- getBalance ----

  group('CChainClient.getBalance', () {
    test('returns balance in Wei from hex result', () async {
      // 1 AVAX = 10^18 Wei = 0xDE0B6B3A7640000
      mockResponse('0xDE0B6B3A7640000');
      final balance =
          await client.getBalance('0x71C7656EC7ab88b098defB751B7401B5f6d8976F');
      expect(balance, equals(BigInt.parse('1000000000000000000')));
    });

    test('returns zero for empty account', () async {
      mockResponse('0x0');
      final balance =
          await client.getBalance('0x0000000000000000000000000000000000000000');
      expect(balance, equals(BigInt.zero));
    });

    test('throws AvalancheException on RPC error', () async {
      mockError(-32602, 'invalid argument');
      expect(
        () => client.getBalance('0xinvalid'),
        throwsA(isA<AvalancheException>()),
      );
    });
  });

  // ---- getTransactionCount ----

  group('CChainClient.getTransactionCount', () {
    test('returns nonce as integer', () async {
      mockResponse('0x5');
      final nonce = await client.getTransactionCount(
        '0x71C7656EC7ab88b098defB751B7401B5f6d8976F',
      );
      expect(nonce, equals(5));
    });

    test('returns 0 for new account', () async {
      mockResponse('0x0');
      final nonce = await client.getTransactionCount(
        '0x0000000000000000000000000000000000000000',
      );
      expect(nonce, equals(0));
    });
  });

  // ---- getBlockNumber ----

  group('CChainClient.getBlockNumber', () {
    test('returns block number as integer', () async {
      mockResponse('0x1b4');
      final block = await client.getBlockNumber();
      expect(block, equals(436));
    });
  });

  // ---- getBaseFee ----

  group('CChainClient.getBaseFee', () {
    test('returns base fee in Wei from hex', () async {
      // 0x34630b8a00 = 225,000,000,000 Wei = 225 nAVAX
      mockResponse('0x34630b8a00');
      final baseFee = await client.getBaseFee();
      expect(baseFee, equals(BigInt.parse('225000000000')));
    });

    test('minimum base fee is 1 nAVAX (10^9 Wei)', () async {
      // 1 nAVAX = 0x3B9ACA00
      mockResponse('0x3B9ACA00');
      final baseFee = await client.getBaseFee();
      expect(baseFee, equals(BigInt.from(1000000000)));
    });
  });

  // ---- getMaxPriorityFeePerGas ----

  group('CChainClient.getMaxPriorityFeePerGas', () {
    test('returns priority fee in Wei from hex', () async {
      mockResponse('0x5d21dba00');
      final fee = await client.getMaxPriorityFeePerGas();
      expect(fee, equals(BigInt.parse('25000000000')));
    });
  });

  // ---- suggestPriceOptions ----

  group('CChainClient.suggestPriceOptions', () {
    test('parses slow/normal/fast options correctly', () async {
      // Official example from build.avax.network/docs/rpcs/c-chain
      mockMapResponse({
        'slow': {
          'maxPriorityFeePerGas': '0x5d21dba00',
          'maxFeePerGas': '0x6fc23ac00',
        },
        'normal': {
          'maxPriorityFeePerGas': '0x2540be400',
          'maxFeePerGas': '0x4a817c800',
        },
        'fast': {
          'maxPriorityFeePerGas': '0x12a05f200',
          'maxFeePerGas': '0x37e11d600',
        },
      });

      final options = await client.suggestPriceOptions();

      // slow
      expect(
        options.slow.maxPriorityFeePerGas,
        equals(BigInt.parse('25000000000')),
      );
      expect(options.slow.maxFeePerGas, equals(BigInt.parse('30000000000')));

      // normal
      expect(
        options.normal.maxPriorityFeePerGas,
        equals(BigInt.parse('10000000000')),
      );
      expect(options.normal.maxFeePerGas, equals(BigInt.parse('20000000000')));

      // fast
      expect(
        options.fast.maxPriorityFeePerGas,
        equals(BigInt.parse('5000000000')),
      );
      expect(options.fast.maxFeePerGas, equals(BigInt.parse('15000000000')));
    });
  });

  // ---- estimateGas ----

  group('CChainClient.estimateGas', () {
    test('returns gas estimate from hex', () async {
      // 0x5208 = 21000 (standard AVAX transfer)
      mockResponse('0x5208');
      final gas = await client.estimateGas(
        to: '0x71C7656EC7ab88b098defB751B7401B5f6d8976F',
        from: '0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359',
        value: BigInt.parse('1000000000000000000'),
      );
      expect(gas, equals(BigInt.from(21000)));
    });
  });

  // ---- getTransactionReceipt ----

  group('CChainClient.getTransactionReceipt', () {
    test('returns null for pending transaction', () async {
      when(
        mockHttp.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': null}),
          200,
        ),
      );
      final receipt = await client.getTransactionReceipt('0xabc123');
      expect(receipt, isNull);
    });

    test('returns receipt map for confirmed transaction', () async {
      mockMapResponse({
        'transactionHash': '0xabc123',
        'status': '0x1',
        'blockNumber': '0x1b4',
        'gasUsed': '0x5208',
      });
      final receipt = await client.getTransactionReceipt('0xabc123');
      expect(receipt, isNotNull);
      expect(receipt!['status'], equals('0x1'));
    });
  });

  // ---- HTTP error ----

  group('CChainClient - HTTP errors', () {
    test('throws AvalancheException on non-200 HTTP status', () async {
      when(
        mockHttp.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('Service Unavailable', 503));
      expect(
        () => client.getBalance('0x71C7656EC7ab88b098defB751B7401B5f6d8976F'),
        throwsA(isA<AvalancheException>()),
      );
    });
  });
}
