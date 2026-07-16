# Changelog

All notable changes to avalanche_flutter_sdk will be documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.3-dev]

Phase 1 in progress: BIP-39 mnemonic generation implemented and
verified in English and Spanish.

### Added

- `MnemonicStrength`: enum with 5 valid BIP-39 entropy strengths
  - `words12` (128 bits), `words15` (160 bits), `words18` (192 bits),
    `words21` (224 bits), `words24` (256 bits)
  - Computes `bits`, `bytes`, `checksumBits`, `totalBits`, `wordCount`
    per BIP-39 formula: CS = ENT / 32, MS = (ENT + CS) / 11
- `Entropy`: BIP-39 entropy generation and checksum computation
  - `generate()`: cryptographically secure random bytes using
    `FortunaRandom` + `Random.secure()` (consistent with `PrivateKey`)
  - `validate()`: throws `ArgumentError` for invalid entropy sizes
  - `computeChecksum()`: first ENT/32 bits of SHA256(entropy)
  - `toBits()`: entropy + checksum as bit list for word index computation
- `Wordlist`: abstract base class for BIP-39 wordlists
  - `wordAt(index)`: returns word at index 0-2047
  - `indexOf(word)`: binary search O(log n) - valid per BIP-39 sorted spec
  - `contains(word)`: delegates to `indexOf`
  - `validate()`: checks length == 2048 and words are sorted
- `WordlistEn`: official BIP-39 English wordlist (2048 words)
  - Singleton pattern: `WordlistEn.instance`
  - Source: `github.com/bitcoin/bips/blob/master/bip-0039/english.txt`
  - First word: `abandon` (index 0), last word: `zoo` (index 2047)
- `WordlistEs`: official BIP-39 Spanish wordlist (2048 words)
  - Singleton pattern: `WordlistEs.instance`
  - Source: `github.com/bitcoin/bips/blob/master/bip-0039/spanish.txt`
  - NFKD encoding (per BIP-39 spec); `wordAt()` returns NFC for callers
  - Accent-insensitive lookup: `indexOf('abaco') == indexOf('ábaco')`
  - HashMap-based O(1) lookup (binary search invalid for Spanish alphabet
    where ñ follows n, not unicode order)
  - Case-insensitive: `indexOf('Domingo') == indexOf('domingo')`
- `Mnemonic`: BIP-39 mnemonic generation, import, and validation
  - `Mnemonic.generate()`: generates from cryptographically secure entropy;
    default 12 words English, configurable strength and wordlist
  - `Mnemonic.fromEntropy()`: deterministic generation from entropy bytes
  - `Mnemonic.fromPhrase()`: imports and validates existing phrase;
    verifies BIP-39 checksum; accepts extra whitespace between words
  - `toEntropy()`: reconstructs original entropy from word indices
  - `toString()` returns `Mnemonic[REDACTED]` - phrase is equivalent
    in sensitivity to a private key; use `phrase` getter explicitly
- SDK Documentation & Knowledge Base link added to README
- 192 new unit tests (77/77 → 192/192 total passing)

### Verified

- BIP-39 official test vectors (trezor/python-mnemonic/vectors.json):
  - 128-bit all-zeros → `abandon abandon ... about` (12 words) ✅
  - 128-bit 0x7f...7f → `legal winner ... yellow` (12 words) ✅
  - 128-bit 0x80...80 → `letter advice ... above` (12 words) ✅
  - 128-bit 0xff...ff → `zoo zoo ... wrong` (12 words) ✅
  - 256-bit all-zeros → `abandon abandon ... art` (24 words) ✅
- Spanish wordlist: 2048 words in NFKD encoding, accent-insensitive
  lookup verified at runtime
- `WordlistEn` binary search: `wordAt`/`indexOf` round-trip consistent
  at indices 0, 1024, and 2047

### Status

Phase 1 in progress: BIP-39 mnemonics (EN + ES) complete and tested.  
Not ready for production use.  
Next: HD key derivation (BIP-44) + EVM and X/P-Chain address derivation.  

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
