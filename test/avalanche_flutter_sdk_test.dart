import 'package:avalanche_flutter_sdk/avalanche_flutter_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---- AvalancheClient ----

  group('AvalancheClient', () {
    test('creates client with Fuji Testnet config', () {
      final client = AvalancheClient(network: NetworkConfig.fuji);
      expect(client.network.networkId, equals(5));
    });

    test('creates client with Mainnet config', () {
      final client = AvalancheClient(network: NetworkConfig.mainnet);
      expect(client.network.networkId, equals(1));
    });
  });

  // ---- NetworkConfig ----

  group('NetworkConfig', () {
    test('Fuji C-Chain RPC URL is correct', () {
      expect(
        NetworkConfig.fuji.cChainRpcUrl,
        equals('https://api.avax-test.network/ext/bc/C/rpc'),
      );
    });

    test('Mainnet C-Chain RPC URL is correct', () {
      expect(
        NetworkConfig.mainnet.cChainRpcUrl,
        equals('https://api.avax.network/ext/bc/C/rpc'),
      );
    });
  });

  // ---- NetworkId ----

  group('NetworkId', () {
    test('mainnet has value 1', () {
      expect(NetworkId.mainnet.value, equals(1));
    });

    test('fuji has value 5', () {
      expect(NetworkId.fuji.value, equals(5));
    });
  });
}
