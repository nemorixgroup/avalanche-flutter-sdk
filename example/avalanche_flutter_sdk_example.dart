import 'phase1/network_config_example.dart';

/// avalanche_flutter_sdk - Quick Start Examples
///
/// This file is the entry point for all SDK examples.
/// Each section corresponds to a phase of development.
///
/// Implementation details can be found in:
/// https://github.com/nemorixgroup/avalanche-flutter-sdk/tree/main/example/
///
/// Running this example:
/// ```sh
/// dart run example/avalanche_flutter_sdk_example.dart
/// ```
///
/// Planned phases:
///   Phase 1 - Architecture + Crypto/Wallet (secp256k1, BIP-39, HD derivation)
///   Phase 2 - C-Chain Core (EIP-1559 transfers, ERC-20, gas estimation)
///   Phase 3 - Data API / Glacier (balances, history, NFTs, WebSocket)
///   Phase 4 - P-Chain + X-Chain (staking, UTXO, cross-chain)
Future<void> main() async {
  // ---- Phase 1: Architecture + Network Configuration ----
  // See: example/phase1/

  // AvalancheClient setup, NetworkConfig (Mainnet / Fuji Testnet), NetworkId
  await networkConfigExamples();

  // ---- Phase 2: Cryptography + Wallet (coming in M1) ----
  // secp256k1 key generation, BIP-39 mnemonics (EN + ES),
  // HD key derivation (BIP-44: m/44'/60'/0'/0/n), EVM address derivation

  // ---- Phase 3: C-Chain Core EVM (coming in M2) ----
  // EIP-1559 AVAX transfer, ERC-20 transfers, gas estimation,
  // eth_sendRawTransaction, eth_getTransactionReceipt

  // ---- Phase 4: Data API / Glacier (coming in M3) ----
  // GlacierClient REST, balance queries, transaction history,
  // NFT metadata (ERC-721/1155), WebSocket real-time subscriptions

  // ---- Phase 5: P-Chain + X-Chain (coming in M4) ----
  // P-Chain staking, validator queries, AddDelegatorTransaction,
  // X-Chain UTXO transfers, cross-chain export/import
}
