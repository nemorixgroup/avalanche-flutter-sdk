// ignore_for_file: avoid_print

import 'package:avalanche_flutter_sdk/avalanche_flutter_sdk.dart';

/// Example: AVAX Transfer on Fuji Testnet (v0.1.2-dev)
///
/// Demonstrates building, signing, and broadcasting a real EIP-1559
/// AVAX transfer on Avalanche Fuji Testnet using avalanche_flutter_sdk.
///
/// Source: https://build.avax.network/docs/rpcs/c-chain
///
/// /// WARNING: Never use real private keys in examples.
/// Replace senderPrivKeyHex with your own Fuji Testnet key.
/// Get test AVAX from: https://build.avax.network/console/primary-network/faucet
Future<void> avaxTransferExample() async {
  print('=== AVAX Transfer Example (Fuji Testnet) ===\n');

  // ---- Setup ----
  // WARNING: Never hardcode private keys in production code.
  // This example uses a Fuji Testnet key for demonstration only.
  // In production, derive the key from HDWallet.fromMnemonic().
  const senderPrivKeyHex = 'YOUR_FUJI_TESTNET_PRIVATE_KEY_HERE';
  const receiverAddress = '0x0fEB475783E004621b9463Aae30F33665485FafA';

  // 0.001 AVAX in Wei
  final amountWei = BigInt.parse('1000000000000000');

  final client = CChainClient(network: NetworkConfig.fuji);
  final estimator = GasEstimator(client);
  final senderKey = PrivateKey.fromHex(senderPrivKeyHex);
  final senderAddress =
      EvmAddress.fromPublicKey(senderKey.publicKey).checksumAddress;

  print('Sender   : $senderAddress');
  print('Receiver : $receiverAddress');
  print(
    'Amount   : ${amountWei.toDouble() / 1e18} AVAX ($amountWei Wei)',
  );
  print('Network  : Fuji Testnet (chainId: 43113)');
  print('');

  // ---- Step 1: Read on-chain state ----
  print('--- Step 1: Reading on-chain state ---');
  final nonce = await client.getTransactionCount(senderAddress);
  final options = await estimator.getPriceOptions();
  final senderBalance = await client.getBalance(senderAddress);

  print(
    'Sender balance : ${senderBalance.toDouble() / 1e18} AVAX',
  );
  print('Nonce          : $nonce');
  print(
    'MaxFeePerGas   : ${options.normal.maxFeePerGas} Wei (normal)',
  );
  print(
    'MaxPriorityFee : ${options.normal.maxPriorityFeePerGas} Wei',
  );
  print('');

  // ---- Step 2: Build transaction ----
  print('--- Step 2: Building EIP-1559 transaction ---');
  final tx = AvaxTransferTransaction(
    chainId: 43113,
    nonce: nonce,
    maxPriorityFeePerGas: options.normal.maxPriorityFeePerGas,
    maxFeePerGas: options.normal.maxFeePerGas,
    gasLimit: BigInt.from(GasEstimator.avaxTransferGasLimit),
    to: receiverAddress,
    value: amountWei,
  );

  print('Transaction built:');
  print('  chainId  : 43113 (Fuji)');
  print('  nonce    : $nonce');
  print('  gasLimit : ${GasEstimator.avaxTransferGasLimit}');
  print('  to       : $receiverAddress');
  print('  value    : $amountWei Wei');
  print('');

  // ---- Step 3: Sign ----
  print('--- Step 3: Signing transaction ---');
  final rawTx = tx.sign(senderKey);
  print('Signed tx: ${rawTx.substring(0, 20)}... (truncated)');
  print('Type byte: 0x02 (EIP-1559) ✅');
  print('');

  // ---- Step 4: Broadcast ----
  print('--- Step 4: Broadcasting to Fuji Testnet ---');
  final txHash = await client.sendRawTransaction(rawTx);
  print('TX Hash  : $txHash');
  print('Explorer : https://testnet.snowtrace.io/tx/$txHash');
  print('');

  // ---- Step 5: Wait for receipt ----
  print('--- Step 5: Waiting for confirmation ---');
  Map<String, dynamic>? receipt;
  var attempts = 0;
  while (receipt == null && attempts < 10) {
    await Future<void>.delayed(const Duration(seconds: 2));
    receipt = await client.getTransactionReceipt(txHash);
    attempts++;
    print('Attempt $attempts: ${receipt == null ? 'pending' : 'confirmed'}');
  }

  if (receipt != null) {
    final status = receipt['status'] as String;
    final gasUsed = receipt['gasUsed'] as String;
    final success = status == '0x1';
    print('');
    print('=== Transaction ${success ? 'SUCCESS ✅' : 'FAILED ❌'} ===');
    print('Status   : $status (${success ? 'success' : 'failed'})');
    print('Gas used : ${int.parse(gasUsed.substring(2), radix: 16)} units');

    // Verify receiver balance
    final receiverBalance = await client.getBalance(receiverAddress);
    print(
      'Receiver balance: ${receiverBalance.toDouble() / 1e18} AVAX',
    );
  } else {
    print('Transaction not confirmed after ${attempts * 2}s');
  }

  print('\n=== Done ===');
}

Future<void> main() => avaxTransferExample();
