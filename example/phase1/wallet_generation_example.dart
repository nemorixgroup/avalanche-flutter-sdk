// ignore_for_file: avoid_print

import 'package:avalanche_flutter_sdk/avalanche_flutter_sdk.dart';

/// Example: BIP-39 Wallet Generation for Avalanche
///
/// Demonstrates generating HD wallets from BIP-39 mnemonics in both
/// English and Spanish, deriving seeds, and creating HD wallets ready
/// for address derivation on all Avalanche chains.
///
/// Source: https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki
/// Paths:  https://support.core.app/en/articles/7004986
void walletGenerationExample() {
  print('=== Avalanche Wallet Generation Example ===\n');

  // ---- English Wallet (12 words) ----
  print('--- English Wallet (12 words) ---');
  final mnemonicEn = Mnemonic.generate();
  print('Mnemonic : ${mnemonicEn.phrase}');
  print('Words    : ${mnemonicEn.wordCount}');
  print('Language : ${mnemonicEn.wordlist.language}');
  print('Redacted : $mnemonicEn'); // always Mnemonic[REDACTED]

  final seedEn = Seed.fromMnemonic(mnemonicEn);
  print('Seed     : ${seedEn.toHex().substring(0, 16)}... (truncated)');
  print('Redacted : $seedEn'); // always Seed[REDACTED]

  final walletEn = HDWallet.fromMnemonic(mnemonicEn);
  print('Wallet   : $walletEn'); // always HDWallet[REDACTED]
  print('');

  // ---- Spanish Wallet (24 words) ----
  print('--- Spanish Wallet (24 words) ---');
  final mnemonicEs = Mnemonic.generate(
    strength: MnemonicStrength.words24,
    wordlist: WordlistEs.instance,
  );
  print('Mnemonic : ${mnemonicEs.phrase}');
  print('Words    : ${mnemonicEs.wordCount}');
  print('Language : ${mnemonicEs.wordlist.language}');

  final seedEs = Seed.fromMnemonic(mnemonicEs);
  print('Seed     : ${seedEs.toHex().substring(0, 16)}... (truncated)');

  final walletEs = HDWallet.fromMnemonic(mnemonicEs);
  print('Wallet   : $walletEs'); // always HDWallet[REDACTED]
  print('');

  // ---- Import from existing phrase ----
  print('--- Import from existing phrase ---');
  const existingPhrase = 'abandon abandon abandon abandon abandon abandon '
      'abandon abandon abandon abandon abandon about';
  final imported = Mnemonic.fromPhrase(existingPhrase);
  final importedWallet = HDWallet.fromMnemonic(imported);
  print('Imported : ${imported.wordCount} words, '
      'language: ${imported.wordlist.language}');
  print('Wallet   : $importedWallet');
  print('');

  // ---- Optional passphrase ----
  print('--- Wallet with passphrase ---');
  final mnemonic = Mnemonic.generate();
  final seedNoPass = Seed.fromMnemonic(mnemonic);
  final seedWithPass = Seed.fromMnemonic(mnemonic, passphrase: 'my-passphrase');
  print('Same mnemonic, different passphrase → different seed:');
  print('Without: ${seedNoPass.toHex().substring(0, 16)}...');
  print('With   : ${seedWithPass.toHex().substring(0, 16)}...');

  print('\n=== Done ===');
}
