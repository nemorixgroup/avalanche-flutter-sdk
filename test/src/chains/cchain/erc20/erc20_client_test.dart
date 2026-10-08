import 'dart:convert';
import 'dart:typed_data';

import 'package:avalanche_flutter_sdk/src/chains/cchain/cchain_client.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/erc20/erc20_client.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/erc20/erc20_constants.dart';
import 'package:avalanche_flutter_sdk/src/client/network_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../cchain_client_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  late MockClient mockHttp;
  late CChainClient cchainClient;
  late ERC20Client erc20;

  const usdcFuji = ERC20Constants.usdcFuji;
  const testAddress = '0xe9d70EE1dfcEd40152eA3f030d0a3918F2EE81a8';

  setUp(() {
    mockHttp = MockClient();
    cchainClient = CChainClient(
      network: NetworkConfig.fuji,
      httpClient: mockHttp,
    );
    erc20 = ERC20Client(cchainClient);
  });

  void mockCallResponse(String result) {
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

  // ---- ABI encoding verification ----

  group('ERC20Client - ABI encoding', () {
    test('balanceOf encodes correct selector 0x70a08231', () async {
      mockCallResponse('0x${'0' * 63}1'); // returns 1
      await erc20.balanceOf(
        tokenAddress: usdcFuji,
        ownerAddress: testAddress,
      );
      final captured = verify(
        mockHttp.post(
          any,
          headers: anyNamed('headers'),
          body: captureAnyNamed('body'),
        ),
      ).captured;
      final body = jsonDecode(captured.first as String) as Map<String, dynamic>;
      final params = body['params'] as List<dynamic>;
      final txData = (params[0] as Map<String, dynamic>)['data'] as String;
      expect(txData.startsWith('0x70a08231'), isTrue);
    });

    test('transfer encodes correct selector 0xa9059cbb', () {
      final data = Uint8List.fromList([
        ...ERC20Constants.selectorTransfer,
        ...List.filled(64, 0),
      ]);
      expect(data[0], equals(0xa9));
      expect(data[1], equals(0x05));
      expect(data[2], equals(0x9c));
      expect(data[3], equals(0xbb));
    });

    test('approve encodes correct selector 0x095ea7b3', () {
      const selector = ERC20Constants.selectorApprove;
      expect(selector, equals([0x09, 0x5e, 0xa7, 0xb3]));
    });

    test('allowance encodes correct selector 0xdd62ed3e', () {
      const selector = ERC20Constants.selectorAllowance;
      expect(selector, equals([0xdd, 0x62, 0xed, 0x3e]));
    });

    test('transferFrom encodes correct selector 0x23b872dd', () {
      const selector = ERC20Constants.selectorTransferFrom;
      expect(selector, equals([0x23, 0xb8, 0x72, 0xdd]));
    });
  });

  // ---- balanceOf ----

  group('ERC20Client.balanceOf', () {
    test('decodes uint256 balance correctly', () async {
      // 1,000,000 USDC units (1 USDC with 6 decimals)
      mockCallResponse(
        '0x00000000000000000000000000000000000000000000000000000000000F4240',
      );
      final balance = await erc20.balanceOf(
        tokenAddress: usdcFuji,
        ownerAddress: testAddress,
      );
      expect(balance, equals(BigInt.from(1000000)));
    });

    test('returns zero for empty result', () async {
      mockCallResponse('0x${'0' * 64}');
      final balance = await erc20.balanceOf(
        tokenAddress: usdcFuji,
        ownerAddress: testAddress,
      );
      expect(balance, equals(BigInt.zero));
    });
  });

  // ---- decimals ----

  group('ERC20Client.decimals', () {
    test('decodes USDC decimals (6)', () async {
      mockCallResponse(
        '0x0000000000000000000000000000000000000000000000000000000000000006',
      );
      final result = await erc20.decimals(usdcFuji);
      expect(result, equals(6));
    });

    test('decodes standard 18 decimals', () async {
      mockCallResponse(
        '0x0000000000000000000000000000000000000000000000000000000000000012',
      );
      final result = await erc20.decimals(usdcFuji);
      expect(result, equals(18));
    });
  });

  // ---- symbol ----

  group('ERC20Client.symbol', () {
    test('decodes "USDC" symbol correctly', () async {
      // ABI-encoded string "USDC":
      // offset (32) + length (4) + "USDC" padded to 32 bytes
      const abiEncodedUsdc = '0x'
          '0000000000000000000000000000000000000000000000000000000000000020'
          '0000000000000000000000000000000000000000000000000000000000000004'
          '5553444300000000000000000000000000000000000000000000000000000000';
      mockCallResponse(abiEncodedUsdc);
      final result = await erc20.symbol(usdcFuji);
      expect(result, equals('USDC'));
    });
  });

  // ---- allowance ----

  group('ERC20Client.allowance', () {
    test('decodes allowance correctly', () async {
      // 500,000 USDC units allowance
      mockCallResponse(
        '0x000000000000000000000000000000000000000000000000000000000007A120',
      );
      final result = await erc20.allowance(
        tokenAddress: usdcFuji,
        ownerAddress: testAddress,
        spenderAddress: '0x0fEB475783E004621b9463Aae30F33665485FafA',
      );
      expect(result, equals(BigInt.from(500000)));
    });
  });

  // ---- USDC constants ----

  group('ERC20Constants - USDC addresses', () {
    test('USDC Fuji address matches Circle official docs', () {
      // Source: https://developers.circle.com/stablecoins/usdc-contract-addresses
      expect(
        ERC20Constants.usdcFuji,
        equals('0x5425890298aed601595a70AB815c96711a31Bc65'),
      );
    });

    test('USDC Mainnet address matches Circle official docs', () {
      expect(
        ERC20Constants.usdcMainnet,
        equals('0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E'),
      );
    });
  });
}
