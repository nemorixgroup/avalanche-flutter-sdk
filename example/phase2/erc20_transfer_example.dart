// ignore_for_file: avoid_print

import 'dart:math';

import 'package:avalanche_flutter_sdk/avalanche_flutter_sdk.dart';

/// Example: ERC-20 USDC Transfer on Fuji Testnet (v0.2.0-dev)
///
/// Demonstrates reading ERC-20 token data and transferring USDC
/// on Avalanche Fuji Testnet using avalanche_flutter_sdk.
///
/// USDC Fuji contract: 0x5425890298aed601595a70AB815c96711a31Bc65
/// Source: https://developers.circle.com/stablecoins/usdc-contract-addresses
///
/// WARNING: Never use real private keys in examples.
/// Replace senderPrivKeyHex with your own Fuji Testnet key.
/// Get test USDC from: https://faucet.circle.com/
Future<void> erc20TransferExample() async {
  print('=== ERC-20 USDC Transfer Example (Fuji Testnet) ===\n');

  // ---- Setup ----
  // WARNING: Never hardcode private keys in production code.
  // This example uses a Fuji Testnet key for demonstration only.
  const senderPrivKeyHex = 'YOUR_FUJI_TESTNET_PRIVATE_KEY_HERE';
  const receiverAddress = '0x0fEB475783E004621b9463Aae30F33665485FafA';
  const usdcFuji = ERC20Constants.usdcFuji;

  // Transfer 1 USDC (USDC has 6 decimals: 1 USDC = 1_000_000 units)
  final amountUsdc = BigInt.from(1000000); // 1 USDC

  final client = CChainClient(network: NetworkConfig.fuji);
  final erc20 = ERC20Client(client);
  final senderKey = PrivateKey.fromHex(senderPrivKeyHex);
  final senderAddress =
      EvmAddress.fromPublicKey(senderKey.publicKey).checksumAddress;

  print('Sender   : $senderAddress');
  print('Receiver : $receiverAddress');
  print('Token    : $usdcFuji');
  print('Network  : Fuji Testnet (chainId: 43113)');
  print('');

  // ---- Step 1: Read token info ----
  print('--- Step 1: Reading token info ---');
  final tokenSymbol = await erc20.symbol(usdcFuji);
  final tokenDecimals = await erc20.decimals(usdcFuji);
  final senderBalance = await erc20.balanceOf(
    tokenAddress: usdcFuji,
    ownerAddress: senderAddress,
  );
  final receiverBalanceBefore = await erc20.balanceOf(
    tokenAddress: usdcFuji,
    ownerAddress: receiverAddress,
  );
  final divisor = pow(10, tokenDecimals);

  print('Symbol          : $tokenSymbol');
  print('Decimals        : $tokenDecimals');
  print('Sender balance  : '
      '${senderBalance / BigInt.from(divisor.toInt())} $tokenSymbol');
  print('Receiver balance: '
      '${receiverBalanceBefore / BigInt.from(divisor.toInt())} $tokenSymbol');
  print('Amount to send  : '
      '${amountUsdc / BigInt.from(divisor.toInt())} $tokenSymbol');
  print('');

  // ---- Step 2: Read on-chain state ----
  print('--- Step 2: Reading on-chain state ---');
  final nonce = await client.getTransactionCount(senderAddress);
  print('Nonce : $nonce');
  print('');

  // ---- Step 3: Transfer USDC ----
  print('--- Step 3: Transferring $tokenSymbol ---');
  final txHash = await erc20.transfer(
    tokenAddress: usdcFuji,
    toAddress: receiverAddress,
    amount: amountUsdc,
    privateKey: senderKey,
    nonce: nonce,
    chainId: 43113,
  );
  print('TX Hash  : $txHash');
  print('Explorer : https://testnet.snowtrace.io/tx/$txHash');
  print('');

  // ---- Step 4: Wait for confirmation ----
  print('--- Step 4: Waiting for confirmation ---');
  Map<String, dynamic>? receipt;
  var attempts = 0;
  while (receipt == null && attempts < 10) {
    await Future<void>.delayed(const Duration(seconds: 2));
    receipt = await client.getTransactionReceipt(txHash);
    attempts++;
    print('Attempt $attempts: '
        '${receipt == null ? 'pending...' : 'confirmed!'}');
  }

  if (receipt != null) {
    final status = receipt['status'] as String;
    final success = status == '0x1';
    print('');
    print('=== Transaction ${success ? 'SUCCESS ✅' : 'FAILED ❌'} ===');
    print('Status : $status (${success ? 'success' : 'failed'})');

    // Verify receiver balance after transfer
    final receiverBalanceAfter = await erc20.balanceOf(
      tokenAddress: usdcFuji,
      ownerAddress: receiverAddress,
    );
    print('Receiver balance after: '
        '${receiverBalanceAfter / BigInt.from(divisor.toInt())} $tokenSymbol');
  } else {
    print('Transaction not confirmed after ${attempts * 2}s');
  }

  print('\n=== Done ===');
}

Future<void> main() => erc20TransferExample();
