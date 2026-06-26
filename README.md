# avalanche_flutter_sdk

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-teal.svg)](https://opensource.org/licenses/Apache-2.0)
[![Dart](https://img.shields.io/badge/Dart-3.x-teal.svg)](https://dart.dev)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev)
[![Status](https://img.shields.io/badge/Status-Phase%201%20In%20Progress-red.svg)]()

The first native Flutter/Dart SDK for the Avalanche network.  
Pure Dart · No platform channels · Apache 2.0 · pub.dev

> ⚠️ **Status: Early Development** - API is not stable.  
> Current phase: M1 - Architecture + Crypto/Wallet.

## Planned Features (v1.0.0)

| Feature | Status |
|---|---|
| C-Chain EVM (EIP-1559, ERC-20/721/1155) | 🔄 M2 |
| Data API / Glacier (REST + WebSocket) | 🔄 M3 |
| secp256k1 + BIP-39 (EN + ES) | 🔄 M1 |
| P-Chain staking | 🔄 M4 |
| X-Chain native assets | 🔄 M4 |

## Installation

```yaml
# pubspec.yaml
dependencies:
  avalanche_flutter_sdk: ^0.0.1-dev
```

## Networks

```dart
// Fuji Testnet
final client = AvalancheClient(network: NetworkConfig.fuji);

// Mainnet
final client = AvalancheClient(network: NetworkConfig.mainnet);
```

## Contributing

The SDK is not ready for external contributions yet.
Follow this repository for updates; contributions will
be welcome starting with v1.0.0.

See [CONTRIBUTING.md](CONTRIBUTING.md) for future guidelines.

## License

Licensed under [Apache 2.0](LICENSE).

## Para desarrolladores en LATAM

Este SDK esta siendo desarrollado con soporte nativo para la region:

- Mnemonics BIP-39 en **espanol**
- Caso de uso principal: remesas **Estados Unidos hacia Latinoamerica**
- Desarrollado por [Nemorix Group](https://nemorixpay.com); Ohio, USA

Siguenos para actualizaciones:
**sdks@nemorixpay.com**

## Support This Project

If this SDK is useful to you or your team, consider supporting its
development. Every contribution helps cover infrastructure,
documentation, and the time invested in building and maintaining this
open source tool for the Avalanche and Flutter community. Thank you!

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-Support-FFDD00?logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/nemorixgroupllc)
[![Sponsor](https://img.shields.io/badge/Sponsor-GitHub-EA4AAA?logo=github-sponsors&logoColor=white)](https://github.com/sponsors/nemorixgroup)
[![Ko-fi](https://img.shields.io/badge/Ko--fi-Support-FF5E5B?logo=ko-fi&logoColor=white)](https://ko-fi.com/nemorixgroupllc)

---

<p align="center">
  <sub>Built by <a href="https://nemorixpay.com">Nemorix Group</a>
  · Apache 2.0</sub>
</p>
