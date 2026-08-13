// ignore_for_file: avoid_print

import 'package:avalanche_flutter_sdk/avalanche_flutter_sdk.dart';

/// Example: C-Chain Read Operations (v0.1.1-dev)
///
/// Demonstrates reading data from the Avalanche C-Chain using
/// CChainClient and GasEstimator on Fuji Testnet.
///
/// Note: This example requires network access to Fuji Testnet.
/// Endpoint: https://api.avax-test.network/ext/bc/C/rpc
///
/// Source: https://build.avax.network/docs/rpcs/c-chain
Future<void> cchainReadExample() async {
  print('=== C-Chain Read Operations Example (Fuji Testnet) ===\n');

  // ---- Setup ----
  final client = CChainClient(network: NetworkConfig.fuji);
  final estimator = GasEstimator(client);

  // ---- Block info ----
  print('--- Block Info ---');
  final blockNumber = await client.getBlockNumber();
  print('Latest block : $blockNumber');
  print('');

  // ---- Balance query ----
  // Using a known Fuji Testnet address for demonstration.
  // Replace with any valid C-Chain address.
  const address = '0x8db97C7cEcE249c2b98bDC0226Cc4C2A57BF52FC';
  print('--- Account: $address ---');

  final balance = await client.getBalance(address);
  final nonce = await client.getTransactionCount(address);
  final balanceInAvax = balance.toDouble() / 1e18;

  print('Balance : $balance Wei');
  print('Balance : ${balanceInAvax.toStringAsFixed(6)} AVAX');
  print('Nonce   : $nonce');
  print('');

  // ---- Gas estimation ----
  print('--- Gas Estimation (eth_suggestPriceOptions) ---');
  final options = await estimator.getPriceOptions();
  print('Slow   maxFeePerGas : ${options.slow.maxFeePerGas} Wei'
      ' (${options.slow.maxFeePerGasInNAvax.toStringAsFixed(9)} nAVAX)');
  print('Normal maxFeePerGas : ${options.normal.maxFeePerGas} Wei'
      ' (${options.normal.maxFeePerGasInNAvax.toStringAsFixed(9)} nAVAX)');
  print('Fast   maxFeePerGas : ${options.fast.maxFeePerGas} Wei'
      ' (${options.fast.maxFeePerGasInNAvax.toStringAsFixed(9)} nAVAX)');
  print('');

  // ---- Base fee ----
  print('--- Base Fee (eth_baseFee) ---');
  final baseFee = await estimator.getBaseFee();
  final baseFeeInNAvax = baseFee.toDouble() / 1e9;
  print('Base fee : $baseFee Wei'
      ' (${baseFeeInNAvax.toStringAsFixed(9)} nAVAX)');
  print('');

  // ---- Transfer fee estimate ----
  print('--- AVAX Transfer Fee Estimate ---');
  print('Gas limit : ${GasEstimator.avaxTransferGasLimit} gas units'
      ' (standard EVM transfer)');

  final slowFee = await estimator.estimateTransferFee(speed: GasSpeed.slow);
  final normalFee = await estimator.estimateTransferFee();
  final fastFee = await estimator.estimateTransferFee(speed: GasSpeed.fast);

  print('Slow   : $slowFee Wei'
      ' (${(slowFee.toDouble() / 1e9).toStringAsFixed(6)} nAVAX)');
  print('Normal : $normalFee Wei'
      ' (${(normalFee.toDouble() / 1e9).toStringAsFixed(6)} nAVAX)');
  print('Fast   : $fastFee Wei'
      ' (${(fastFee.toDouble() / 1e9).toStringAsFixed(6)} nAVAX)');

  print('\n=== Done ===');
}

// Allow running this file directly
Future<void> main() => cchainReadExample();
