import 'dart:convert';
import 'dart:typed_data';

import 'package:avalanche_flutter_sdk/src/chains/cchain/erc20/erc20_constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart' show KeccakDigest;

void main() {
  String keccakHex(String text) {
    final hash = KeccakDigest(256).process(
      Uint8List.fromList(utf8.encode(text)),
    );
    return '0x${hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  group('ERC20Constants.transferEventTopic', () {
    test('equals keccak256 of the Transfer event signature', () {
      expect(
        ERC20Constants.transferEventTopic,
        equals(keccakHex('Transfer(address,address,uint256)')),
      );
    });

    test('is a 0x-prefixed lowercase 32-byte hex string', () {
      expect(
        ERC20Constants.transferEventTopic,
        matches(RegExp(r'^0x[0-9a-f]{64}$')),
      );
    });

    test('matches the topic 0 of a live USDC Transfer log on Fuji', () {
      // Captured from an eth_subscribe("logs") notification (block 0x3a74aba).
      expect(
        ERC20Constants.transferEventTopic,
        equals(
          '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef',
        ),
      );
    });
  });
}
