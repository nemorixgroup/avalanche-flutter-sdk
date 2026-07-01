# Changelog

All notable changes to avalanche_flutter_sdk will be documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.0.2-dev

Phase 1 in progress: secp256k1 cryptography implemented and verified.

### Added

- `PrivateKey`: secp256k1 private key generation, import, and export
  - `PrivateKey.generate()` using `FortunaRandom` (cryptographically
    secure pseudo-random number generator)
  - `PrivateKey.fromHex()` with strict range validation against the
    curve order `n` (rejects `d <= 0` and `d >= n`)
  - `toHex()`, `toBytes()`: 32-byte big-endian export
  - `publicKey` getter: derives `Q = d * G` per secp256k1
  - `toString()` returns `PrivateKey[REDACTED]` - key material is
    never exposed via logs, error messages, or debug output
- `PublicKey`: secp256k1 public key derivation, import, and encoding
  - `PublicKey.fromEcPoint()`, `PublicKey.fromHex()` (accepts both
    compressed and uncompressed SEC1 encodings)
  - `toCompressed()`: 33-byte SEC1 encoding - required input for
    X-Chain/P-Chain address derivation (sha256 + ripemd160)
  - `toUncompressed()` / `toRawUncompressed()`: 65-byte and 64-byte
    encodings - required input for C-Chain/EVM address derivation
    (keccak256)
  - Value equality (`==`, `hashCode`) based on the underlying
    elliptic curve point
- `pointycastle: ^4.0.0` and `meta: ^1.15.0` added as dependencies
- 60 new unit tests (18/18 -> 78/78 total passing)

### Verified

- secp256k1 curve order `n` confirmed directly from `pointycastle`'s
  `ECDomainParameters('secp256k1')` at runtime:
  `fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141`
- Private key range validation tested at all boundaries:
  `d=0` (rejected), `d=1` (accepted), `d=n-1` (accepted), `d=n`
  (rejected), `d=n+1` (rejected)
- Compressed/uncompressed public key encodings verified to decode to
  the same elliptic curve point (round-trip equality)

### Status

Phase 1 in progress: secp256k1 `PrivateKey`/`PublicKey` complete and
tested.  
Not ready for production use.  
Next: CB58 encoding, then EVM and X/P-Chain address derivation.

## 0.0.1-dev

Phase 1 in progress: SDK skeleton and project architecture.

### Added
- `AvalancheClient`: main entry point for the SDK
  - accepts `NetworkConfig` for Mainnet or Fuji Testnet
- `NetworkConfig`: official Avalanche RPC endpoint configurations
  - `NetworkConfig.mainnet`: Avalanche Mainnet (C-Chain, P-Chain, X-Chain, Glacier API)
  - `NetworkConfig.fuji`: Avalanche Fuji Testnet (C-Chain, P-Chain, X-Chain, Glacier API)
  - endpoint URLs sourced from `docs.avax.network`
- `NetworkId`: enum for Mainnet (1) and Fuji Testnet (5)
- `AvalancheException`: base exception class for all SDK errors
- `analysis_options.yaml` with `very_good_analysis` linter (zero warnings enforced)
- `scripts/pre_commit.ps1`: local quality gate (format + analyze + test)
- `.github/workflows/ci.yml`: GitHub Actions CI pipeline
  - format check, static analysis, test suite, coverage threshold (85%), pub publish dry-run
  - daily integration test job against Fuji Testnet (on `develop` push)
- `.github/pull_request_template.md`: PR checklist
- `CONTRIBUTING.md`: branch strategy, commit conventions, code and testing standards
- `SECURITY.md`: vulnerability reporting policy and key handling rules
- 6 initial unit tests (6/6 passing)

### Status
Phase 1 in progress: SDK skeleton, project architecture, and CI infrastructure complete.  
Not ready for production use.  
Next: secp256k1 key generation, BIP-39 mnemonics (EN + ES), HD key derivation (BIP-44).
