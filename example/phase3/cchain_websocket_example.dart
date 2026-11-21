// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:avalanche_flutter_sdk/avalanche_flutter_sdk.dart';

// Public Fuji test address that receives the USDC in these examples.
const _receiver = '0x0fEB475783E004621b9463Aae30F33665485FafA';
const _usdcDecimals = 6;

/// Example: C-Chain WebSocket subscriptions (v0.2.2-dev)
///
/// Read-only demonstration on Fuji Testnet with [CChainWebSocketClient]:
/// new blocks, connection status changes and incoming USDC transfers to an
/// address. It needs no private key and spends nothing.
///
/// The client reconnects on its own after a connection loss
/// ([ReconnectPolicy]) and reports every change through `status`. To see
/// that, set WS_EXAMPLE_WATCH_SECONDS to a longer window (for example 180)
/// and switch the network off for about a minute while step 2 runs. A silent
/// drop is detected within one to two heartbeat intervals (20 to 40 s by
/// default).
///
/// Source: https://build.avax.network/docs/rpcs/c-chain
Future<void> cchainWebSocketExample() async {
  print('=== C-Chain WebSocket Example (Fuji Testnet) ===\n');

  final ws = CChainWebSocketClient(
    network: NetworkConfig.fuji,
    reconnectPolicy: const ReconnectPolicy(),
  );
  final statusSubscription = ws.status.listen(
    (status) => print('[status] ${status.name}'),
  );

  try {
    await ws.connect();
    print('Connected to ${NetworkConfig.fuji.cChainWsUrl}\n');

    print('--- Step 1: new blocks (5 headers) ---');
    await _printBlocks(ws, count: 5);

    final seconds = _watchSeconds();
    print('\n--- Step 2: incoming USDC transfers to ${_short(_receiver)} '
        '($seconds s) ---');
    print('Send test USDC to that address to see an event here.');
    final transfers = ws
        .watchIncomingErc20Transfers(
          tokenAddress: ERC20Constants.usdcFuji,
          to: _receiver,
        )
        .listen(
          (event) => print(_describe(event)),
          onError: (Object e) => print('Transfer stream error: $e'),
        );
    await Future<void>.delayed(Duration(seconds: seconds));
    await transfers.cancel();
  } on AvalancheException catch (e) {
    print('Error: $e');
  } on TimeoutException catch (e) {
    print('Timed out: $e');
  } finally {
    await ws.close();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await statusSubscription.cancel();
  }

  print('\n=== Done ===');
}

/// Example: detect an incoming USDC transfer in real time (v0.2.2-dev)
///
/// Subscribes to the USDC transfers sent to [_receiver], sends 1 USDC from
/// your wallet to that address and measures how long the subscription takes
/// to report it.
///
/// The Fuji Testnet private key is read from the FUJI_PRIVATE_KEY
/// environment variable. Never put a private key in the source code. The
/// wallet needs a little test AVAX for gas and at least 1 test USDC.
///
/// Get test AVAX: https://build.avax.network/console/primary-network/faucet
/// Get test USDC: https://faucet.circle.com/
Future<void> cchainWebSocketTransferExample() async {
  print('=== C-Chain WebSocket: USDC transfer detection (Fuji) ===\n');

  final keyHex = Platform.environment['FUJI_PRIVATE_KEY'];
  if (keyHex == null || keyHex.isEmpty) {
    print('Set FUJI_PRIVATE_KEY to a Fuji Testnet key that holds test AVAX '
        'and USDC.');
    print('This example sends 1 USDC to $_receiver.');
    return;
  }
  final privateKey = PrivateKey.fromHex(keyHex);
  final sender = EvmAddress.fromPublicKey(privateKey.publicKey).checksumAddress;
  print('Sender   : $sender');
  print('Receiver : $_receiver\n');

  final ws = CChainWebSocketClient(
    network: NetworkConfig.fuji,
    reconnectPolicy: const ReconnectPolicy(),
  );
  final seen = <String, Erc20TransferEvent>{};
  StreamSubscription<Erc20TransferEvent>? transfers;

  try {
    await ws.connect();
    transfers = ws
        .watchIncomingErc20Transfers(
      tokenAddress: ERC20Constants.usdcFuji,
      to: _receiver,
    )
        .listen(
      (event) {
        if (!event.removed) {
          seen[event.transactionHash.toLowerCase()] = event;
        }
      },
      onError: (Object e) => print('Transfer stream error: $e'),
    );
    // Give the node a moment to confirm the subscription.
    await Future<void>.delayed(const Duration(seconds: 2));

    final client = CChainClient(network: NetworkConfig.fuji);
    final erc20 = ERC20Client(client);
    final nonce = await client.getTransactionCount(sender);

    final clock = Stopwatch()..start();
    final txHash = await erc20.transfer(
      tokenAddress: ERC20Constants.usdcFuji,
      toAddress: _receiver,
      amount: BigInt.from(1000000), // 1 USDC (6 decimals)
      privateKey: privateKey,
      nonce: nonce,
      chainId: 43113,
    );
    print(
      'Sent 1 USDC: $txHash (broadcast in ${clock.elapsedMilliseconds} ms)',
    );
    print('Explorer: https://testnet.snowtrace.io/tx/$txHash\n');

    final hashKey = txHash.toLowerCase();
    Erc20TransferEvent? match;
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (match == null && DateTime.now().isBefore(deadline)) {
      match = seen[hashKey];
      if (match == null) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }

    if (match == null) {
      print('The transfer was not reported within 30 s.');
    } else {
      print('Reported ${clock.elapsedMilliseconds} ms after the transaction '
          'was sent:');
      print(_describe(match));
    }
  } on AvalancheException catch (e) {
    print('Error: $e');
  } finally {
    await transfers?.cancel();
    await ws.close();
  }

  print('\n=== Done ===');
}

Future<void> _printBlocks(
  CChainWebSocketClient ws, {
  required int count,
}) async {
  final done = Completer<void>();
  var seen = 0;
  final heads = ws.newHeads().listen(
    (head) {
      seen++;
      print('block ${head.number} | ${head.time.toIso8601String()} | '
          'gas used ${head.gasUsed} | base fee ${head.baseFeePerGas} Wei');
      if (seen == count && !done.isCompleted) done.complete();
    },
    onError: (Object e) {
      if (!done.isCompleted) done.completeError(e);
    },
  );
  try {
    await done.future.timeout(const Duration(seconds: 60));
  } finally {
    await heads.cancel();
  }
}

int _watchSeconds() =>
    int.tryParse(Platform.environment['WS_EXAMPLE_WATCH_SECONDS'] ?? '') ?? 10;

String _describe(Erc20TransferEvent event) {
  final amount = event.valueInTokens(_usdcDecimals).toStringAsFixed(2);
  final removed = event.removed ? ' | REMOVED (chain reorganization)' : '';
  return '$amount USDC | ${_short(event.from)} -> ${_short(event.to)} | '
      'block ${event.blockNumber} | tx ${_short(event.transactionHash)}'
      '$removed';
}

String _short(String value) {
  if (value.length <= 12) return value;
  return '${value.substring(0, 8)}...${value.substring(value.length - 4)}';
}

Future<void> main() async {
  await cchainWebSocketExample();
  if (Platform.environment['FUJI_PRIVATE_KEY']?.isNotEmpty ?? false) {
    print('');
    await cchainWebSocketTransferExample();
  }
}
