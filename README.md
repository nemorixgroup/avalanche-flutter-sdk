# avalanche_flutter_sdk

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-teal.svg)](https://opensource.org/licenses/Apache-2.0)
[![Dart](https://img.shields.io/badge/Dart-3.x-teal.svg)](https://dart.dev)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev)
[![CI](https://github.com/nemorixgroup/avalanche-flutter-sdk/actions/workflows/ci.yml/badge.svg)](https://github.com/nemorixgroup/avalanche-flutter-sdk/actions)
[![Status](https://img.shields.io/badge/Status-Phase%201%20In%20Progress-red.svg)]()

The first native Flutter/Dart SDK for the Avalanche network.  
Pure Dart · No platform channels · Apache 2.0 · pub.dev  

> ⚠️ **Status: Early Development** - API is not stable.  
> Current phase: M1 - Architecture + Crypto/Wallet.


## Planned Features (v1.0.0)

| Feature | Status |
|---|---|
| AvalancheClient + NetworkConfig (Mainnet / Fuji) | ✅ Done |
| secp256k1 PrivateKey / PublicKey | ✅ Done |
| CB58 encoding / decoding | ✅ Done |
| BIP-39 mnemonics (EN + ES) + HD derivation | 🔄 M1 |
| C-Chain EVM (EIP-1559, ERC-20/721/1155) | ⏳ M2 |
| Data API / Glacier (REST + WebSocket) | ⏳ M3 |
| P-Chain staking | ⏳ M4 |
| X-Chain native assets | ⏳ M4 |


## Installation

```yaml
# pubspec.yaml
dependencies:
  avalanche_flutter_sdk: ^0.0.1-dev
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

// Private keys are always redacted in logs - key material is never exposed
print(privateKey); // PrivateKey[REDACTED]
print(publicKey);  // PublicKey(0x02b33c...)
```

### Public Key Encodings

```dart
final publicKey = PrivateKey.generate().publicKey;

// Compressed (33 bytes) - required for X-Chain / P-Chain address derivation
// sha256(compressed) -> ripemd160 -> address
final compressed = publicKey.toCompressed();

// Raw uncompressed (64 bytes, no 0x04 prefix) - required for C-Chain
// EVM address derivation: keccak256(raw) -> last 20 bytes -> 0x... address
final raw = publicKey.toRawUncompressed();
```

### CB58 Encoding / Decoding

```dart
// Encode raw bytes to CB58 (used for PrivateKey export, NodeID, etc.)
final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
final encoded = CB58.encode(bytes);    // e.g. "3HCXF4n..."
final decoded = CB58.decode(encoded);  // back to original bytes

// PrivateKey in Avalanche export format: "PrivateKey-<cb58>"
final privateKey = PrivateKey.generate();
final exportString = 'PrivateKey-${CB58.encode(privateKey.toBytes())}';
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

- Mnemonics BIP-39 en **espanol** (proximamente)
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
