import 'package:avalanche_flutter_sdk/src/client/network_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NetworkConfig.cChainWsUrl', () {
    test('Mainnet uses the public api.avax.network WebSocket', () {
      expect(
        NetworkConfig.mainnet.cChainWsUrl,
        equals('wss://api.avax.network/ext/bc/C/ws'),
      );
    });

    test('Fuji uses the public api.avax-test.network WebSocket', () {
      expect(
        NetworkConfig.fuji.cChainWsUrl,
        equals('wss://api.avax-test.network/ext/bc/C/ws'),
      );
    });

    test('both networks use the secure wss scheme and the /ext/bc/C/ws path',
        () {
      for (final network in [NetworkConfig.mainnet, NetworkConfig.fuji]) {
        final uri = Uri.parse(network.cChainWsUrl);
        expect(uri.scheme, equals('wss'));
        expect(uri.path, equals('/ext/bc/C/ws'));
      }
    });

    test('WebSocket host matches the C-Chain RPC host of the same network', () {
      for (final network in [NetworkConfig.mainnet, NetworkConfig.fuji]) {
        expect(
          Uri.parse(network.cChainWsUrl).host,
          equals(Uri.parse(network.cChainRpcUrl).host),
        );
      }
    });
  });
}
