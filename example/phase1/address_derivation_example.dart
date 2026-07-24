// ignore_for_file: avoid_print

import 'package:avalanche_flutter_sdk/avalanche_flutter_sdk.dart';

/// Example: Avalanche Address Derivation (C-Chain, X-Chain, P-Chain)
///
/// Demonstrates deriving addresses for all three Avalanche chains
/// from a BIP-39 mnemonic using BIP-44 HD key derivation.
///
/// Derivation paths (Core Wallet compatible):
/// - C-Chain: m/44'/60'/0'/0/n  (EVM, coin_type=60)
/// - X-Chain: m/44'/9000'/0'/0/n (Avalanche native, coin_type=9000)
/// - P-Chain: m/44'/9000'/0'/0/n (same path as X-Chain)
///
/// Sources:
/// - https://docs.avax.network/docs/rpcs/other/standards/cryptographic-primitives
/// - https://support.core.app/en/articles/7004986
/// - https://eips.ethereum.org/EIPS/eip-55
void addressDerivationExample() {
  print('=== Avalanche Address Derivation Example ===\n');

  // ---- Generate a wallet ----
  final mnemonic = Mnemonic.generate(wordlist: WordlistEs.instance);
  final wallet = HDWallet.fromMnemonic(mnemonic);

  print('Mnemonic (${mnemonic.wordlist.language}): ${mnemonic.phrase}');
  print('');

  // ---- C-Chain addresses (EVM) ----
  print('--- C-Chain Addresses (EVM) ---');
  print("Path: m/44'/60'/0'/0/n\n");
  for (var i = 0; i < 3; i++) {
    final pubKey = wallet.derivePublicKeyForCChain(index: i);
    final address = EvmAddress.fromPublicKey(pubKey);
    print('index $i: ${address.checksumAddress}');
  }
  print('');

  // ---- X-Chain addresses ----
  print('--- X-Chain Addresses ---');
  print("Path: m/44'/9000'/0'/0/n\n");
  for (var i = 0; i < 3; i++) {
    final pubKey = wallet.derivePublicKeyForXPChain(index: i);
    final address = XPAddress.fromPublicKey(pubKey);
    print('index $i: ${address.xChainAddress()}');
  }
  print('');

  // ---- P-Chain addresses ----
  print('--- P-Chain Addresses ---');
  print("Path: m/44'/9000'/0'/0/n\n");
  for (var i = 0; i < 3; i++) {
    final pubKey = wallet.derivePublicKeyForXPChain(index: i);
    final address = XPAddress.fromPublicKey(pubKey);
    print('index $i: ${address.pChainAddress()}');
  }
  print('');

  // ---- Fuji Testnet addresses ----
  print('--- Fuji Testnet X-Chain Addresses ---');
  for (var i = 0; i < 3; i++) {
    final pubKey = wallet.derivePublicKeyForXPChain(index: i);
    final address = XPAddress.fromPublicKey(pubKey);
    print(
      'index $i: ${address.xChainAddress(network: AvalancheNetwork.fuji)}',
    );
  }
  print('');

  // ---- Key insight: X-Chain and P-Chain share the same address ----
  print('--- Note: X-Chain and P-Chain share the same address space ---');
  final pubKey0 = wallet.derivePublicKeyForXPChain();
  final addr0 = XPAddress.fromPublicKey(pubKey0);
  print('X-Chain[0]: ${addr0.xChainAddress()}');
  print('P-Chain[0]: ${addr0.pChainAddress()}');
  print('(same 20-byte address, different chain prefix)');

  print('\n=== Done ===');
}
