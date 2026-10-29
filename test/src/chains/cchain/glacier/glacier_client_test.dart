import 'dart:convert';

import 'package:avalanche_flutter_sdk/src/chains/cchain/glacier/glacier_client.dart';
import 'package:avalanche_flutter_sdk/src/client/network_config.dart';
import 'package:avalanche_flutter_sdk/src/exceptions/avalanche_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'glacier_client_test.mocks.dart';

// Fixtures follow the response schemas published at
// build.avax.network/docs/api-reference/data-api (evm-balances and
// evm-transactions sections).

@GenerateMocks([http.Client])
void main() {
  late MockClient mockHttp;
  late GlacierClient glacier;

  const sender = '0xe9d70EE1dfcEd40152eA3f030d0a3918F2EE81a8';
  const receiver = '0x0fEB475783E004621b9463Aae30F33665485FafA';
  const usdcFuji = '0x5425890298aed601595a70AB815c96711a31Bc65';
  const avaxTxHash =
      '0x43f9d7b50013a5b18b0c1b6eda82875a39f7e7a01d114fa62595ced6f52d1ff2';
  const usdcTxHash =
      '0x398ac7a99a3407d1b481d7c61ba5aee298b6cc6d500ecdcb614d12a7742aaa71';

  setUp(() {
    mockHttp = MockClient();
    glacier = GlacierClient(
      network: NetworkConfig.fuji,
      httpClient: mockHttp,
    );
  });

  // ---- Helpers ----

  void mockResponse(Map<String, dynamic> body, {int statusCode = 200}) {
    reset(mockHttp);
    when(mockHttp.get(any, headers: anyNamed('headers'))).thenAnswer(
      (_) async => http.Response(jsonEncode(body), statusCode),
    );
  }

  void mockRawResponse(String body, int statusCode) {
    reset(mockHttp);
    when(mockHttp.get(any, headers: anyNamed('headers'))).thenAnswer(
      (_) async => http.Response(body, statusCode),
    );
  }

  Map<String, dynamic> nativeBalanceJson() => {
        'nativeTokenBalance': {
          'name': 'Avalanche',
          'symbol': 'AVAX',
          'decimals': 18,
          'chainId': '43113',
          'balance': '1000000000000000000',
        },
      };

  Map<String, dynamic> nativeTx({
    String txStatus = '1',
    String value = '1000000000000000',
    bool contractCreation = false,
  }) =>
      {
        'blockNumber': '58211707',
        'blockTimestamp': 1788658685,
        'blockHash': '0xabc',
        'chainId': '43113',
        'blockIndex': 0,
        'txHash': avaxTxHash,
        'txStatus': txStatus,
        'txType': 2,
        'gasLimit': '21000',
        'gasUsed': '21000',
        'gasPrice': '160',
        'nonce': '0',
        'from': {'address': sender},
        'to': contractCreation ? null : {'address': receiver},
        'value': value,
      };

  Map<String, dynamic> erc20Transfer() => {
        'blockNumber': '59193138',
        'blockTimestamp': 1791482664,
        'blockHash': '0xdef',
        'txHash': usdcTxHash,
        'from': {'address': sender},
        'to': {'address': receiver},
        'logIndex': 3,
        'value': '1000000',
        'erc20Token': {
          'address': usdcFuji,
          'name': 'USD Coin',
          'symbol': 'USDC',
          'decimals': 6,
          'ercType': 'ERC-20',
        },
      };

  // ---- NetworkConfig.chainId ----

  group('NetworkConfig.chainId', () {
    test('Fuji chainId is 43113', () {
      expect(NetworkConfig.fuji.chainId, equals('43113'));
    });

    test('Mainnet chainId is 43114', () {
      expect(NetworkConfig.mainnet.chainId, equals('43114'));
    });
  });

  // ---- Constructor and API key ----

  group('GlacierClient - API key', () {
    test('creates without API key', () {
      final client = GlacierClient(network: NetworkConfig.fuji);
      expect(client.apiKey, isNull);
    });

    test('creates with API key', () {
      final client = GlacierClient(
        network: NetworkConfig.fuji,
        apiKey: 'test_key',
      );
      expect(client.apiKey, equals('test_key'));
    });

    test('sends x-glacier-api-key header when a key is provided', () async {
      final clientWithKey = GlacierClient(
        network: NetworkConfig.fuji,
        apiKey: 'test_key_123',
        httpClient: mockHttp,
      );
      mockResponse(nativeBalanceJson());
      await clientWithKey.getAvaxBalance(sender);
      final headers = verify(
        mockHttp.get(any, headers: captureAnyNamed('headers')),
      ).captured.single as Map<String, String>;
      expect(headers['x-glacier-api-key'], equals('test_key_123'));
    });

    test('omits x-glacier-api-key header when no key is provided', () async {
      mockResponse(nativeBalanceJson());
      await glacier.getAvaxBalance(sender);
      final headers = verify(
        mockHttp.get(any, headers: captureAnyNamed('headers')),
      ).captured.single as Map<String, String>;
      expect(headers.containsKey('x-glacier-api-key'), isFalse);
    });
  });

  // ---- Request building ----

  group('GlacierClient - request building', () {
    test('getAvaxBalance calls the balances:getNative path for Fuji', () async {
      mockResponse(nativeBalanceJson());
      await glacier.getAvaxBalance(sender);
      final uri = verify(
        mockHttp.get(captureAny, headers: anyNamed('headers')),
      ).captured.single as Uri;
      expect(
        uri.path,
        equals('/v1/chains/43113/addresses/$sender/balances:getNative'),
      );
      expect(uri.host, equals('glacier-api.avax.network'));
    });

    test('sends pageSize and pageToken as query parameters', () async {
      mockResponse({'transactions': <Map<String, dynamic>>[]});
      await glacier.getTransactions(sender, pageSize: 25, pageToken: 'tok-1');
      final uri = verify(
        mockHttp.get(captureAny, headers: anyNamed('headers')),
      ).captured.single as Uri;
      expect(uri.queryParameters['pageSize'], equals('25'));
      expect(uri.queryParameters['pageToken'], equals('tok-1'));
    });

    test('sends no query string when no paging options are given', () async {
      mockResponse({'transactions': <Map<String, dynamic>>[]});
      await glacier.getTransactions(sender);
      final uri = verify(
        mockHttp.get(captureAny, headers: anyNamed('headers')),
      ).captured.single as Uri;
      expect(uri.hasQuery, isFalse);
    });
  });

  // ---- getAvaxBalance ----

  group('GlacierClient.getAvaxBalance', () {
    test('parses native balance correctly', () async {
      mockResponse(nativeBalanceJson());
      final result = await glacier.getAvaxBalance(sender);
      expect(result.balance, equals(BigInt.parse('1000000000000000000')));
      expect(result.symbol, equals('AVAX'));
      expect(result.decimals, equals(18));
      expect(result.chainId, equals('43113'));
    });

    test('balanceInAvax converts correctly (1 AVAX)', () async {
      mockResponse(nativeBalanceJson());
      final result = await glacier.getAvaxBalance(sender);
      expect(result.balanceInAvax, closeTo(1.0, 0.0001));
    });
  });

  // ---- getErc20Balances ----

  group('GlacierClient.getErc20Balances', () {
    Map<String, dynamic> usdcBalance({Object? price}) => {
          'address': usdcFuji,
          'name': 'USD Coin',
          'symbol': 'USDC',
          'decimals': 6,
          'ercType': 'ERC-20',
          'chainId': '43113',
          'balance': '20000000',
          if (price != null) 'price': price,
        };

    test('parses ERC-20 balance list correctly', () async {
      mockResponse({
        'erc20TokenBalances': [usdcBalance()],
      });
      final result = await glacier.getErc20Balances(sender);
      expect(result.items.length, equals(1));
      expect(result.items.first.symbol, equals('USDC'));
      expect(result.items.first.decimals, equals(6));
      expect(result.items.first.balance, equals(BigInt.from(20000000)));
      expect(result.hasNextPage, isFalse);
    });

    test('balanceInTokens converts USDC correctly (20 USDC)', () async {
      mockResponse({
        'erc20TokenBalances': [usdcBalance()],
      });
      final result = await glacier.getErc20Balances(sender);
      expect(result.items.first.balanceInTokens, closeTo(20.0, 0.0001));
    });

    test('parses price object {currencyCode, value}', () async {
      mockResponse({
        'erc20TokenBalances': [
          usdcBalance(price: {'currencyCode': 'usd', 'value': '1.0'}),
        ],
      });
      final result = await glacier.getErc20Balances(sender);
      expect(result.items.first.price, closeTo(1.0, 0.0001));
      expect(result.items.first.priceCurrency, equals('usd'));
    });

    test('price is null when the API omits it', () async {
      mockResponse({
        'erc20TokenBalances': [usdcBalance()],
      });
      final result = await glacier.getErc20Balances(sender);
      expect(result.items.first.price, isNull);
      expect(result.items.first.priceCurrency, isNull);
    });

    test('returns nextPageToken when more pages are available', () async {
      mockResponse({
        'erc20TokenBalances': <Map<String, dynamic>>[],
        'nextPageToken': 'abc-123-uuid',
      });
      final result = await glacier.getErc20Balances(sender);
      expect(result.nextPageToken, equals('abc-123-uuid'));
      expect(result.hasNextPage, isTrue);
    });

    test('returns empty list when the wallet has no tokens', () async {
      mockResponse({'erc20TokenBalances': <Map<String, dynamic>>[]});
      final result = await glacier.getErc20Balances(sender);
      expect(result.items, isEmpty);
      expect(result.hasNextPage, isFalse);
    });

    test('tolerates a missing erc20TokenBalances key', () async {
      mockResponse(<String, dynamic>{});
      final result = await glacier.getErc20Balances(sender);
      expect(result.items, isEmpty);
    });
  });

  // ---- getTransactions ----

  group('GlacierClient.getTransactions', () {
    test('parses native transaction list correctly', () async {
      mockResponse({
        'transactions': [nativeTx()],
      });
      final result = await glacier.getTransactions(sender);
      final tx = result.items.single;
      expect(tx.txHash, equals(avaxTxHash));
      expect(tx.blockNumber, equals('58211707'));
      expect(tx.from, equals(sender));
      expect(tx.to, equals(receiver));
      expect(tx.gasUsed, equals('21000'));
      expect(tx.gasPrice, equals('160'));
      expect(tx.chainId, equals('43113'));
      expect(tx.isSuccess, isTrue);
    });

    test('isSuccess is false when txStatus is "0"', () async {
      mockResponse({
        'transactions': [nativeTx(txStatus: '0')],
      });
      final result = await glacier.getTransactions(sender);
      expect(result.items.single.isSuccess, isFalse);
    });

    test('valueInAvax converts correctly (1 AVAX)', () async {
      mockResponse({
        'transactions': [nativeTx(value: '1000000000000000000')],
      });
      final result = await glacier.getTransactions(sender);
      expect(result.items.single.valueInAvax, closeTo(1.0, 0.0001));
    });

    test('to is empty for contract creation (null recipient)', () async {
      mockResponse({
        'transactions': [nativeTx(contractCreation: true)],
      });
      final result = await glacier.getTransactions(sender);
      expect(result.items.single.to, isEmpty);
    });

    test('returns nextPageToken when present', () async {
      mockResponse({
        'transactions': [nativeTx()],
        'nextPageToken': 'next-uuid',
      });
      final result = await glacier.getTransactions(sender);
      expect(result.hasNextPage, isTrue);
      expect(result.nextPageToken, equals('next-uuid'));
    });
  });

  // ---- getErc20Transfers ----

  group('GlacierClient.getErc20Transfers', () {
    test('parses ERC-20 transfer list correctly', () async {
      mockResponse({
        'transactions': [erc20Transfer()],
      });
      final result = await glacier.getErc20Transfers(sender);
      final transfer = result.items.single;
      expect(transfer.txHash, equals(usdcTxHash));
      expect(transfer.blockNumber, equals('59193138'));
      expect(transfer.from, equals(sender));
      expect(transfer.to, equals(receiver));
      expect(transfer.logIndex, equals(3));
      expect(transfer.value, equals(BigInt.from(1000000)));
      expect(transfer.tokenAddress, equals(usdcFuji));
      expect(transfer.tokenSymbol, equals('USDC'));
      expect(transfer.tokenDecimals, equals(6));
    });

    test('valueInTokens converts 1 USDC correctly', () async {
      mockResponse({
        'transactions': [erc20Transfer()],
      });
      final result = await glacier.getErc20Transfers(sender);
      expect(result.items.single.valueInTokens, closeTo(1.0, 0.0001));
    });

    test('calls the transactions:listErc20 path', () async {
      mockResponse({'transactions': <Map<String, dynamic>>[]});
      await glacier.getErc20Transfers(sender);
      final uri = verify(
        mockHttp.get(captureAny, headers: anyNamed('headers')),
      ).captured.single as Uri;
      expect(
        uri.path,
        equals('/v1/chains/43113/addresses/$sender/transactions:listErc20'),
      );
    });

    test('returns empty page when there are no transfers', () async {
      mockResponse({'transactions': <Map<String, dynamic>>[]});
      final result = await glacier.getErc20Transfers(sender);
      expect(result.items, isEmpty);
      expect(result.hasNextPage, isFalse);
    });
  });

  // ---- getTransaction ----

  group('GlacierClient.getTransaction', () {
    test('parses the nativeTransaction object', () async {
      mockResponse({
        'erc20Transfers': <Map<String, dynamic>>[],
        'erc721Transfers': <Map<String, dynamic>>[],
        'erc1155Transfers': <Map<String, dynamic>>[],
        'internalTransactions': <Map<String, dynamic>>[],
        'nativeTransaction': nativeTx(),
      });
      final result = await glacier.getTransaction(avaxTxHash);
      expect(result.txHash, equals(avaxTxHash));
      expect(result.blockNumber, equals('58211707'));
      expect(result.isSuccess, isTrue);
    });

    test('calls the transactions/{txHash} path', () async {
      mockResponse({'nativeTransaction': nativeTx()});
      await glacier.getTransaction(avaxTxHash);
      final uri = verify(
        mockHttp.get(captureAny, headers: anyNamed('headers')),
      ).captured.single as Uri;
      expect(uri.path, equals('/v1/chains/43113/transactions/$avaxTxHash'));
    });
  });

  // ---- Error handling ----

  group('GlacierClient - errors', () {
    test('throws AvalancheException on 429 rate limit', () async {
      mockResponse(
        {'message': 'rate limit exceeded', 'statusCode': 429},
        statusCode: 429,
      );
      expect(
        () => glacier.getAvaxBalance(sender),
        throwsA(isA<AvalancheException>()),
      );
    });

    test('throws AvalancheException on 404 with JSON body', () async {
      mockResponse(
        {'message': 'not found', 'statusCode': 404, 'error': 'Not Found'},
        statusCode: 404,
      );
      expect(
        () => glacier.getTransaction(avaxTxHash),
        throwsA(isA<AvalancheException>()),
      );
    });

    test('throws AvalancheException (not FormatException) on non-JSON 502',
        () async {
      mockRawResponse('<html>Bad Gateway</html>', 502);
      expect(
        () => glacier.getAvaxBalance(sender),
        throwsA(isA<AvalancheException>()),
      );
    });
  });
}
