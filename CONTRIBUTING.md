# Contributing to avalanche_flutter_sdk

Thank you for your interest in contributing to the first native Flutter/Dart SDK
for the Avalanche network. This document defines the standards and workflow for
all contributions.

---

## Table of Contents

1. [Development Setup](#1-development-setup)
2. [Branch Strategy](#2-branch-strategy)
3. [Commit Conventions](#3-commit-conventions)
4. [Code Standards](#4-code-standards)
5. [Testing Standards](#5-testing-standards)
6. [Pre-Commit Gate](#6-pre-commit-gate)
7. [Pull Request Process](#7-pull-request-process)
8. [Adding a New Feature](#8-adding-a-new-feature)
9. [Security Policy](#9-security-policy)

---

## 1. Development Setup

**Requirements:**

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Windows + PowerShell (primary dev environment)

**Clone and setup:**

```powershell
git clone https://github.com/nemorixgroup/avalanche-flutter-sdk.git
cd avalanche-flutter-sdk
git checkout develop
flutter pub get
```

**Verify setup:**

```powershell
.\scripts\pre_commit.ps1
```

All checks must pass green before your first change.

---

## 2. Branch Strategy

main          <- stable releases only (tagged)
develop       <- integration branch for all features
feature/*     <- one branch per feature or fix

**Branch naming:**

Examples:  
feature/crypto-secp256k1
feature/cchain-eip1559-transfer
fix/glacier-pagination-edge-case
docs/readme-quick-start

**Rules:**

- Never commit directly to `main` or `develop`
- Every feature branch is created from `develop`
- Merges to `develop` via Pull Request only
- Merges to `main` via Pull Request from `develop` at release time

---

## 3. Commit Conventions

This project uses **Conventional Commits**.
Format: `<type>(<scope>): <description>`

| Type | When to use |
|---|---|
| `feat` | New feature or capability |
| `fix` | Bug fix |
| `test` | Adding or updating tests |
| `docs` | Documentation changes only |
| `refactor` | Code change with no behavior change |
| `chore` | Build, deps, CI, tooling |
| `perf` | Performance improvement |

**Scope examples:**

feat(crypto): add secp256k1 key generation
feat(cchain): implement EIP-1559 transfer
fix(glacier): handle empty pagination cursor
test(network): add NetworkConfig URL tests
docs(readme): add quick start example
chore(ci): add coverage threshold check

**Rules:**

- Description in lowercase, no period at end
- One logical change per commit
- If a commit closes an issue: add `Closes #42` in the body

---

## 4. Code Standards

**Linter:** `very_good_analysis` — zero warnings, zero infos.

**Section comments:** Use `// ---- Section Name ----` for logical grouping:
```dart
// ---- Constructor ----

// ---- Fields ----

// ---- Public Methods ----

// ---- Private Methods ----
```

**Documentation:** Every public API element must have a dartdoc comment:
```dart
/// Sends an AVAX transfer on C-Chain using EIP-1559.
///
/// Throws [AvalancheException] if the transaction fails to broadcast.
///
/// Example:
/// ```dart
/// final tx = await client.cchain.sendAvax(
///   to: '0xRecipient...',
///   amount: AvaxAmount.fromAVAX(1.0),
///   privateKey: myKey,
/// );
/// ```
Future<TransactionHash> sendAvax({...}) async { ... }
```

**No hardcoded secrets:** Private keys, mnemonics, and API keys must never
appear in source code, tests, or logs.

**No `print()` statements:** Use proper error propagation via exceptions.

---

## 5. Testing Standards

**Coverage target:** >= 85% line and branch coverage across all modules.

**Test file location:** Mirror the `lib/src/` structure under `test/src/`:

lib/src/client/avalanche_client.dart
test/src/client/avalanche_client_test.dart

**Test structure:**

```dart
void main() {
  // ---- GroupName ----

  group('ClassName', () {
    setUp(() { ... });

    test('does something specific', () {
      // Arrange
      // Act
      // Assert
    });

    test('throws AvalancheException when ...', () {
      expect(
        () => someCall(),
        throwsA(isA<AvalancheException>()),
      );
    });
  });
}
```

**Every feature must include:**

- Happy path test
- Error path tests (invalid input, network failure, edge cases)
- Security test: private keys must not appear in exception messages

---

## 6. Pre-Commit Gate

Run before **every** commit:
```powershell
.\scripts\pre_commit.ps1
```

This runs in order:
1. `dart format --set-exit-if-changed .`
2. `dart analyze --fatal-infos`
3. `flutter test`

**The gate must pass green before any `git commit`.** No exceptions.

---

## 7. Pull Request Process

1. Create your feature branch from `develop`
2. Make your changes with passing pre-commit
3. Open a PR targeting `develop`
4. Fill in the PR template completely
5. Wait for CI to pass (GitHub Actions)
6. Request review if needed

**PR title** must follow Conventional Commits format:

feat(cchain): implement EIP-1559 AVAX transfer with gas estimation

---

## 8. Adding a New Feature

Example: adding `CChainClient`:

```powershell
# 1. Create branch
git checkout develop
git pull origin develop
git checkout -b feature/cchain-client

# 2. Create files
# lib/src/chains/cchain/cchain_client.dart
# test/src/chains/cchain/cchain_client_test.dart

# 3. Export from barrel file
# lib/avalanche_flutter_sdk.dart -> add export

# 4. Run pre-commit
.\scripts\pre_commit.ps1

# 5. Commit
git add .
git commit -m "feat(cchain): add CChainClient skeleton with JSON-RPC base"

# 6. Push and open PR
git push origin feature/cchain-client
```

---

## 9. Security Policy

**Reporting a vulnerability:**

- Do NOT open a public GitHub issue for security vulnerabilities
- Email: avalanche@nemorixpay.com
- We will respond within 48 hours
- A patched version will be released within 7 days of confirmation

**Key handling rules:**

- `PrivateKey` and `Mnemonic` classes must override `toString()` to return
  a redacted string (e.g., `PrivateKey[REDACTED]`)
- No key material may appear in exception messages, stack traces, or logs
- Security tests are non-negotiable blockers for every milestone

---

## Questions?

Open a [GitHub Discussion](https://github.com/nemorixgroup/avalanche-flutter-sdk/discussions) or reach out on the [Avalanche Discord](https://discord.gg/avalanche) `#dev-tools` channel.
