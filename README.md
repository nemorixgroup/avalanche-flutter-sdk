# avalanche_flutter_sdk

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-teal.svg)](https://opensource.org/licenses/Apache-2.0)
[![Dart](https://img.shields.io/badge/Dart-3.x-teal.svg)](https://dart.dev)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev)
[![CI](https://github.com/nemorixgroup/avalanche-flutter-sdk/actions/workflows/ci.yml/badge.svg)](https://github.com/nemorixgroup/avalanche-flutter-sdk/actions)
[![Status](https://img.shields.io/badge/Status-Phase%201%20Complete-green.svg)]()

The first native Flutter/Dart SDK for the Avalanche network.  
Pure Dart · No platform channels · Apache 2.0 · pub.dev  

> ⚠️ **Status: Early Development** - API is not stable.  
> Phase 1 complete: full wallet cycle (mnemonic → seed → HD wallet → addresses).


## Planned Features (v1.0.0)

| Feature | Status |
|---|---|
| AvalancheClient + NetworkConfig (Mainnet / Fuji) | ✅ Done |
| secp256k1 PrivateKey / PublicKey | ✅ Done |
| CB58 encoding / decoding | ✅ Done |
| BIP-39 mnemonics (EN + ES) | ✅ Done |
| HD key derivation (BIP-44) | ✅ Done |
| EVM address derivation (C-Chain) | ✅ Done |
| X/P-Chain address derivation | ✅ Done |
| C-Chain JSON-RPC client (eth_getBalance, eth_getTransactionCount) | 🔄 M2 |
| AVAX transfers (EIP-1559, signing, broadcast) | ⏳ M2 |
| ERC-20 transfers (USDC, USDT, approve, allowance) | ⏳ M2 |
| Glacier REST client (balances, transaction history) | ⏳ M3 |
| Glacier WebSocket (real-time events, subscriptions) | ⏳ M3 |
| ERC-721 / ERC-1155 (NFT metadata, ownership) | ⏳ M3 |
| P-Chain staking (addValidator, addDelegator) | ⏳ M4 |
| P-Chain validator queries | ⏳ M4 |
| X-Chain UTXO transfers (native AVAX) | ⏳ M4 |
| Cross-chain (Export/Import C↔X↔P) | ⏳ M4 |

## SDK Documentation & Knowledge Base

This SDK is built on top of the [Avalanche Knowledge Base](https://github.com/nemorixgroup/Avalanche-Knowledge-Base),
an in-depth guide to the Avalanche network covering consensus,
architecture, multi-chain design, and the development ecosystem.
Recommended reading before diving into the SDK internals.

Every implementation decision behind this SDK - library choices,
encoding standards, verification against official specs - is
documented in [docs-sdk/](https://github.com/nemorixgroup/Avalanche-Knowledge-Base/tree/main/docs-sdk).

## Installation

```yaml
# pubspec.yaml
dependencies:
  avalanche_flutter_sdk: ^0.1.0-dev
```

```sh
flutter pub get
```


## Quick Start

### Network Configuration

```dart
import 'package:avalanche_flutter_sdk/avalanche_flutter_sdk.dart';

// Fuji Testnet
final client = AvalancheClient(network: NetworkConfig.fuji);
print(client.network.cChainRpcUrl);
// -> https://api.avax-test.network/ext/bc/C/rpc

// Mainnet
final client = AvalancheClient(network: NetworkConfig.mainnet);
print(client.network.networkId); // -> 1
```

### Key Generation (secp256k1)

```dart
// Generate a new private key
final privateKey = PrivateKey.generate();

// Derive the public key
final publicKey = privateKey.publicKey;

// Export / import via hex
final hex = privateKey.toHex();           // 64 hex chars (32 bytes)
final imported = PrivateKey.fromHex(hex); // round-trips correctly

// Private keys are always redacted in logs
print(privateKey); // PrivateKey[REDACTED]
print(publicKey);  // PublicKey(0x02b33c...)
```

### Public Key Encodings

```dart
final publicKey = PrivateKey.generate().publicKey;

// Compressed (33 bytes) - input for X/P-Chain address derivation
final compressed = publicKey.toCompressed();

// Raw uncompressed (64 bytes, no 0x04 prefix) - input for C-Chain EVM
final raw = publicKey.toRawUncompressed();
```

### CB58 Encoding / Decoding

```dart
// Encode raw bytes to CB58 (PrivateKey export, NodeID, etc.)
final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
final encoded = CB58.encode(bytes);    // e.g. "3HCXF4n..."
final decoded = CB58.decode(encoded);  // back to original bytes

// PrivateKey in Avalanche export format: "PrivateKey-<cb58>"
final privateKey = PrivateKey.generate();
final exportString = 'PrivateKey-${CB58.encode(privateKey.toBytes())}';
```

### BIP-39 Mnemonics (English + Spanish)

```dart
// Generate a 12-word English mnemonic (default)
final mnemonic = Mnemonic.generate();
print(mnemonic.phrase);
// -> "abandon ability able about above absent absorb..."

// Generate a 24-word Spanish mnemonic
final mnemonicEs = Mnemonic.generate(
  strength: MnemonicStrength.words24,
  wordlist: WordlistEs.instance,
);
print(mnemonicEs.phrase);
// -> "ábaco abdomen abeja abierto abogado..."

// Import from existing phrase (validates checksum automatically)
final imported = Mnemonic.fromPhrase(
  'abandon abandon abandon abandon abandon abandon '
  'abandon abandon abandon abandon abandon about',
);

// Mnemonics are always redacted in logs
print(mnemonic);        // Mnemonic[REDACTED]
print(mnemonic.phrase); // the actual phrase
```

### HD Wallet + Address Derivation

```dart
// Generate wallet from mnemonic (English or Spanish)
final mnemonic = Mnemonic.generate(wordlist: WordlistEs.instance);
final wallet = HDWallet.fromMnemonic(mnemonic);

// C-Chain address (EVM) - compatible with Core Wallet + MetaMask
// Path: m/44'/60'/0'/0/n
final cPubKey  = wallet.derivePublicKeyForCChain(index: 0);
final cAddress = EvmAddress.fromPublicKey(cPubKey);
print(cAddress.checksumAddress); // 0x71C7656EC7ab88b098defB751B7401B5...
print(cAddress.lowercaseAddress);

// X-Chain address - Avalanche native
// Path: m/44'/9000'/0'/0/n
final xpPubKey  = wallet.derivePublicKeyForXPChain(index: 0);
final xpAddress = XPAddress.fromPublicKey(xpPubKey);
print(xpAddress.xChainAddress());                              // X-avax1...
print(xpAddress.xChainAddress(network: AvalancheNetwork.fuji)); // X-fuji1...

// P-Chain address (same key as X-Chain, different prefix)
print(xpAddress.pChainAddress()); // P-avax1...

// Wallets and seeds are always redacted in logs
print(wallet); // HDWallet[REDACTED]
```


## Networks

| Network | Chain ID | C-Chain RPC |
|---|---|---|
| Mainnet | 1 | `https://api.avax.network/ext/bc/C/rpc` |
| Fuji Testnet | 5 | `https://api.avax-test.network/ext/bc/C/rpc` |


## Contributing

The SDK is not ready for external contributions yet.
Follow this repository for updates; contributions will
be welcome starting with v1.0.0.

See [CONTRIBUTING.md](CONTRIBUTING.md) for future guidelines.

## License

Licensed under [Apache 2.0](LICENSE).


## Para desarrolladores en LATAM

Este SDK esta siendo desarrollado con soporte nativo para la region:

- Mnemonics BIP-39 en **español** ✅ disponible desde v0.0.3-dev
- HD wallet + direcciones en las 3 chains ✅ disponible desde v0.1.0-dev
- Caso de uso principal: remesas **Estados Unidos hacia Latinoamerica**
- Desarrollado por [Nemorix Group](https://nemorixpay.com), Ohio, USA

Siguenos para actualizaciones: **sdks@nemorixpay.com**


## Support This Project

If this SDK is useful to you or your team, consider supporting its
development. Every contribution helps cover infrastructure,
documentation, and the time invested in building and maintaining this
open source tool for the Avalanche and Flutter community. Thank you!

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-Support-FFDD00?logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/nemorixgroupllc)
[![Sponsor](https://img.shields.io/badge/Sponsor-GitHub-EA4AAA?logo=github-sponsors&logoColor=white)](https://github.com/sponsors/nemorixgroup)
[![Ko-fi](https://img.shields.io/badge/Ko--fi-Support-FF5F5B?logo=ko-fi&logoColor=white)](https://ko-fi.com/nemorixgroupllc)

---

<p align="center">
  <sub>Built by <a href="https://nemorixpay.com">Nemorix Group</a>
  · Apache 2.0</sub>
</p>
