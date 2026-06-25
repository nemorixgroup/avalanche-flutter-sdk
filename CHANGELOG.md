# Changelog

All notable changes to avalanche_flutter_sdk will be documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
