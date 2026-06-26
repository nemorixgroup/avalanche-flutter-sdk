# Security Policy

## Supported Versions

| Version | Supported |
|---|---|
| 0.0.1-dev | ✅ Active development |

## Reporting a Vulnerability

**Do NOT open a public GitHub issue for security vulnerabilities.**

Email: **avalanche@nemorixpay.com**

Include in your report:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (optional)

**Response timeline:**

- Acknowledgment: within 48 hours
- Initial assessment: within 5 days
- Patched release: within 7 days of confirmation

## Security Design Principles

This SDK handles cryptographic key material (secp256k1 private keys,
BIP-39 mnemonics). The following rules are enforced in every release:

- `PrivateKey` and `Mnemonic` classes return `[REDACTED]` from `toString()`
- No key material appears in exception messages or stack traces
- All dependencies are pinned in `pubspec.lock` (not committed for libraries,
  but CI runs with locked versions via `flutter pub get`)
- Dependency updates require manual review and changelog entry
