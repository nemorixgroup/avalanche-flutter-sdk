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

  group('NetworkConfig - Fuji', () {
    test('C-Chain RPC URL is correct', () {
      expect(
        NetworkConfig.fuji.cChainRpcUrl,
        equals('https://api.avax-test.network/ext/bc/C/rpc'),
      );
    });

    test('P-Chain RPC URL is correct', () {
      expect(
        NetworkConfig.fuji.pChainRpcUrl,
        equals('https://api.avax-test.network/ext/bc/P'),
      );
    });

    test('X-Chain RPC URL is correct', () {
      expect(
        NetworkConfig.fuji.xChainRpcUrl,
        equals('https://api.avax-test.network/ext/bc/X'),
      );
    });

    test('Glacier API URL is correct', () {
      expect(
        NetworkConfig.fuji.glacierApiUrl,
        equals('https://glacier-api.avax.network'),
      );
    });

    test('network ID is 5', () {
      expect(NetworkConfig.fuji.networkId, equals(5));
    });
  });

  group('NetworkConfig - Mainnet', () {
    test('C-Chain RPC URL is correct', () {
      expect(
        NetworkConfig.mainnet.cChainRpcUrl,
        equals('https://api.avax.network/ext/bc/C/rpc'),
      );
    });

    test('P-Chain RPC URL is correct', () {
      expect(
        NetworkConfig.mainnet.pChainRpcUrl,
        equals('https://api.avax.network/ext/bc/P'),
      );
    });

    test('X-Chain RPC URL is correct', () {
      expect(
        NetworkConfig.mainnet.xChainRpcUrl,
        equals('https://api.avax.network/ext/bc/X'),
      );
    });

    test('Glacier API URL is correct', () {
      expect(
        NetworkConfig.mainnet.glacierApiUrl,
        equals('https://glacier-api.avax.network'),
      );
    });

    test('network ID is 1', () {
      expect(NetworkConfig.mainnet.networkId, equals(1));
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

    test('contains exactly 2 values', () {
      expect(NetworkId.values.length, equals(2));
    });
  });

  // ---- AvalancheException ----

  group('AvalancheException', () {
    test('stores message correctly', () {
      const exception = AvalancheException('test error');
      expect(exception.message, equals('test error'));
    });

    test('toString includes message', () {
      const exception = AvalancheException('connection failed');
      expect(
        exception.toString(),
        equals('AvalancheException: connection failed'),
      );
    });

    test('is an Exception', () {
      const exception = AvalancheException('test');
      expect(exception, isA<Exception>());
    });
  });
}
