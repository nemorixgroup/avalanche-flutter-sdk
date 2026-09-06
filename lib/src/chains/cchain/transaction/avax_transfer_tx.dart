import 'dart:typed_data';

import 'package:avalanche_flutter_sdk/src/chains/cchain/utils/rlp_encoder.dart';
import 'package:avalanche_flutter_sdk/src/crypto/private_key.dart';
import 'package:pointycastle/export.dart' hide PrivateKey, PublicKey;

// ---- AvaxTransferTransaction ----

/// An EIP-1559 AVAX transfer transaction for the Avalanche C-Chain.
///
/// Builds, signs, and encodes a simple AVAX transfer (no contract interaction).
/// Compatible with Core Wallet, MetaMask, and all EVM-compatible tools.
///
/// Transaction format (EIP-2718 type 2):
/// ```sh
/// 0x02 || RLP([chainId, nonce, maxPriorityFeePerGas, maxFeePerGas,
///   gasLimit, to, value, data, accessList,
///   signatureYParity, signatureR, signatureS])
/// ```
///
/// Sources:
/// - https://eips.ethereum.org/EIPS/eip-1559
/// - https://build.avax.network/docs/rpcs/other/guides/txn-fees
class AvaxTransferTransaction {
  // ---- Constructor ----

  /// Creates an [AvaxTransferTransaction] with the given fields.
  ///
  /// All fee values must be in Wei.
  /// [value] is the amount of AVAX to send in Wei.
  /// [gasLimit] for a simple AVAX transfer is always 21,000.
  AvaxTransferTransaction({
    required this.chainId,
    required this.nonce,
    required this.maxPriorityFeePerGas,
    required this.maxFeePerGas,
    required this.gasLimit,
    required this.to,
    required this.value,
  });

  // ---- Fields ----

  /// The chain ID of the target network.
  ///
  /// Fuji Testnet: 43113, Mainnet: 43114.
  /// Source: build.avax.network/docs/rpcs/c-chain
  final int chainId;

  /// The transaction count (nonce) of the sender address.
  ///
  /// Obtained via `CChainClient.getTransactionCount`.
  final int nonce;

  /// The maximum priority fee per gas unit in Wei (tip above base fee).
  final BigInt maxPriorityFeePerGas;

  /// The maximum total fee per gas unit in Wei (base fee + tip cap).
  final BigInt maxFeePerGas;

  /// The maximum gas units for this transaction.
  ///
  /// For a simple AVAX transfer: always 21,000 gas units.
  final BigInt gasLimit;

  /// The recipient address (EVM format, with or without 0x prefix).
  final String to;

  /// The amount of AVAX to transfer in Wei (10^18 Wei = 1 AVAX).
  final BigInt value;

  // ---- Public API ----

  /// Computes the signing hash for this transaction.
  ///
  /// Per EIP-1559:
  /// ```sh
  /// hash = keccak256(0x02 || RLP([chainId, nonce, maxPriorityFeePerGas,
  ///   maxFeePerGas, gasLimit, to, value, data, accessList]))
  /// ```
  ///
  /// Source: https://eips.ethereum.org/EIPS/eip-1559
  Uint8List unsignedHash() {
    final payload = _buildUnsignedPayload();
    return KeccakDigest(256).process(payload);
  }

  /// Signs this transaction with [privateKey] and returns the
  /// hex-encoded raw transaction ready for broadcast.
  ///
  /// The raw transaction starts with `0x02` (EIP-1559 type byte)
  /// followed by the RLP-encoded signed fields.
  ///
  /// Pass the result to `CChainClient.sendRawTransaction`.
  String sign(PrivateKey privateKey) {
    final hash = unsignedHash();
    final sig = privateKey.signDigest(hash);

    final toBytes = _addressToBytes(to);
    final signedRlp = RlpEncoder.encode([
      BigInt.from(chainId),
      BigInt.from(nonce),
      maxPriorityFeePerGas,
      maxFeePerGas,
      gasLimit,
      toBytes,
      value,
      Uint8List(0), // data: empty for AVAX transfer
      <dynamic>[], // accessList: empty for AVAX transfer
      BigInt.from(sig.v), // signatureYParity: 0 or 1 (EIP-1559)
      sig.r,
      sig.s,
    ]);

    final rawTx = Uint8List(1 + signedRlp.length);
    rawTx[0] = 0x02; // EIP-2718 type byte for EIP-1559
    rawTx.setAll(1, signedRlp);

    return '0x${rawTx.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  // ---- Internal ----

  Uint8List _buildUnsignedPayload() {
    final toBytes = _addressToBytes(to);
    final unsignedRlp = RlpEncoder.encode([
      BigInt.from(chainId),
      BigInt.from(nonce),
      maxPriorityFeePerGas,
      maxFeePerGas,
      gasLimit,
      toBytes,
      value,
      Uint8List(0), // data
      <dynamic>[], // accessList
    ]);

    final payload = Uint8List(1 + unsignedRlp.length);
    payload[0] = 0x02; // EIP-2718 type byte
    payload.setAll(1, unsignedRlp);
    return payload;
  }

  static Uint8List _addressToBytes(String address) {
    final clean = address.startsWith('0x') || address.startsWith('0X')
        ? address.substring(2)
        : address;
    if (clean.length != 40) {
      throw ArgumentError(
        'Invalid EVM address length: expected 40hex chars, got ${clean.length}',
      );
    }
    return Uint8List.fromList(
      List.generate(
        20,
        (i) => int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16),
      ),
    );
  }
}
