// ignore_for_file: avoid_print

import 'package:avalanche_flutter_sdk/avalanche_flutter_sdk.dart';

/// Example: Glacier Data API read operations (v0.2.1-dev)
///
/// Demonstrates balances, transaction history, ERC-20 transfer history and
/// pagination against Fuji Testnet using [GlacierClient].
///
/// No private key is needed: every call is a read of public data.
///
/// The API key is optional. Without it the unauthenticated rate limit
/// applies (6,000 CUs/min). A free key raises it to 8,000 CUs/min:
/// https://build.avax.network/console/utilities/data-api-keys
///
/// Source: https://build.avax.network/docs/api-reference/data-api/usage
Future<void> glacierReadExample() async {
  print('=== Glacier Data API Example (Fuji Testnet) ===\n');

  // Public Fuji test wallet used in the C-Chain examples.
  const address = '0xe9d70EE1dfcEd40152eA3f030d0a3918F2EE81a8';
  const knownAvaxTx =
      '0x43f9d7b50013a5b18b0c1b6eda82875a39f7e7a01d114fa62595ced6f52d1ff2';

  final glacier = GlacierClient(network: NetworkConfig.fuji);
  print('Address : $address\n');

  // ---- Step 1: Native balance ----
  print('--- Step 1: AVAX balance ---');
  final avax = await glacier.getAvaxBalance(address);
  print('Balance : ${avax.balanceInAvax.toStringAsFixed(6)} ${avax.symbol}');
  print('Raw     : ${avax.balance} Wei');
  print('');

  // ---- Step 2: ERC-20 balances ----
  print('--- Step 2: ERC-20 balances ---');
  final tokens = await glacier.getErc20Balances(address);
  if (tokens.items.isEmpty) {
    print('No ERC-20 balances returned (Glacier filters spam tokens by '
        'default).');
  }
  for (final token in tokens.items) {
    print('${token.symbol.padRight(8)}: '
        '${token.balanceInTokens.toStringAsFixed(token.decimals.clamp(0, 6))}'
        ' (${token.address})');
  }
  print('');

  // ---- Step 3: Native transaction history with pagination ----
  print('--- Step 3: Native transaction history (pageSize: 3) ---');
  final firstPage = await glacier.getTransactions(address, pageSize: 3);
  for (final tx in firstPage.items) {
    _printTx(tx);
  }
  print('Has next page: ${firstPage.hasNextPage}');

  if (firstPage.hasNextPage) {
    final secondPage = await glacier.getTransactions(
      address,
      pageSize: 3,
      pageToken: firstPage.nextPageToken,
    );
    print('Second page: ${secondPage.items.length} transactions');
  }
  print('');

  // ---- Step 4: ERC-20 transfer history ----
  print('--- Step 4: ERC-20 transfers (pageSize: 3) ---');
  final transfers = await glacier.getErc20Transfers(address, pageSize: 3);
  if (transfers.items.isEmpty) {
    print('No ERC-20 transfers returned.');
  }
  for (final transfer in transfers.items) {
    print('${_formatTime(transfer.blockTimestamp)} | '
        '${transfer.valueInTokens.toStringAsFixed(2)} '
        '${transfer.tokenSymbol} | '
        '${_short(transfer.from)} -> ${_short(transfer.to)} | '
        '${_short(transfer.txHash)}');
  }
  print('');

  // ---- Step 5: Single transaction ----
  print('--- Step 5: Transaction details ---');
  final tx = await glacier.getTransaction(knownAvaxTx);
  _printTx(tx);
  print('Block   : ${tx.blockNumber}');
  print('Success : ${tx.isSuccess}');

  print('\n=== Done ===');
}

void _printTx(GlacierTransaction tx) {
  print('${_formatTime(tx.blockTimestamp)} | '
      '${tx.valueInAvax.toStringAsFixed(6)} AVAX | '
      '${_short(tx.from)} -> ${_short(tx.to)} | '
      '${tx.isSuccess ? 'ok' : 'failed'} | '
      '${_short(tx.txHash)}');
}

String _formatTime(int unixSeconds) {
  final time = DateTime.fromMillisecondsSinceEpoch(
    unixSeconds * 1000,
    isUtc: true,
  );
  return time.toIso8601String();
}

String _short(String value) {
  if (value.length <= 12) return value;
  return '${value.substring(0, 8)}...${value.substring(value.length - 4)}';
}

Future<void> main() => glacierReadExample();
