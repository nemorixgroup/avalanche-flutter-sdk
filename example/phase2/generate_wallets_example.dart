// ignore_for_file: avoid_print

import 'package:avalanche_flutter_sdk/avalanche_flutter_sdk.dart';

/// Example: Generate Fuji Testnet wallets for testing.
///
/// Generates two wallets (sender and receiver) with their
/// addresses and private keys for use in Fuji Testnet examples.
///
/// WARNING: Never use these wallets on Mainnet.
/// WARNING: Never share or commit real private keys.
///
/// Get test AVAX from:
/// https://build.avax.network/console/primary-network/faucet
Future<void> generateWalletsExample() async {
  print('=== Generate Fuji Testnet Wallets ===\n');

  // Wallet 1 - Sender
  final m1 = Mnemonic.generate();
  final w1 = HDWallet.fromMnemonic(m1);
  final addr1 = EvmAddress.fromPublicKey(w1.derivePublicKeyForCChain());
  final pk1 = w1.derivePrivateKeyForCChain();
  print('=== Wallet 1 (Sender) ===');
  print('Mnemonic : ${m1.phrase}');
  print('Address  : ${addr1.checksumAddress}');
  print('PrivKey  : ${pk1.toHex()}');

  // Wallet 2 - Receiver
  final m2 = Mnemonic.generate();
  final w2 = HDWallet.fromMnemonic(m2);
  final addr2 = EvmAddress.fromPublicKey(w2.derivePublicKeyForCChain());
  print('\n=== Wallet 2 (Receiver) ===');
  print('Mnemonic : ${m2.phrase}');
  print('Address  : ${addr2.checksumAddress}');
  print('\nGet test AVAX at: '
      'https://build.avax.network/console/primary-network/faucet');

  print('\n=== Done ===');
}

Future<void> main() => generateWalletsExample();
