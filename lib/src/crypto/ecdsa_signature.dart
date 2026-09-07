/// A secp256k1 ECDSA signature with recovery id.
///
/// Used internally by `PrivateKey.signDigest` to produce the components
/// needed to build a signed EIP-1559 transaction.
class EcdsaSignature {
  /// Creates an [EcdsaSignature] with the given components.
  const EcdsaSignature({
    required this.r,
    required this.s,
    required this.v,
  });

  /// The r component of the ECDSA signature (32 bytes as BigInt).
  final BigInt r;

  /// The s component of the ECDSA signature (32 bytes as BigInt).
  ///
  /// Always low-S normalized (s <= n/2) to prevent signature malleability.
  final BigInt s;

  /// The recovery id (y-parity bit): 0 or 1.
  ///
  /// Used as `signatureYParity` in EIP-1559 transactions.
  /// This is NOT the legacy v value (27 or 28).
  ///
  /// Source: https://eips.ethereum.org/EIPS/eip-1559
  final int v;
}
