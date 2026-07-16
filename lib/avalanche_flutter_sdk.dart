/// The first native Flutter/Dart SDK for the Avalanche network.
///
/// Pure Dart implementation covering:
/// - C-Chain EVM (EIP-1559, ERC-20/721/1155, gas estimation)
/// - Data API / Glacier (balances, history, NFTs, WebSocket)
/// - P-Chain (staking, validators, delegation)
/// - X-Chain (UTXO native asset transfers, cross-chain)
/// - Cryptography (secp256k1, CB58, BIP-39 EN/ES, HD key derivation)
library avalanche_flutter_sdk;

// ---- Client ----
export 'src/client/avalanche_client.dart';
export 'src/client/network_config.dart';

// ---- Crypto ----
export 'src/crypto/cb58.dart';
export 'src/crypto/mnemonic/entropy.dart';
export 'src/crypto/mnemonic/mnemonic.dart';
export 'src/crypto/mnemonic/wordlist.dart';
export 'src/crypto/mnemonic/wordlist_en.dart';
export 'src/crypto/mnemonic/wordlist_es.dart';
export 'src/crypto/private_key.dart';
export 'src/crypto/public_key.dart';

// ---- Exceptions ----
export 'src/exceptions/avalanche_exception.dart';

// ---- Models ----
export 'src/models/network_id.dart';
