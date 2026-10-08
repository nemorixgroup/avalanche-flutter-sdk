import 'dart:typed_data';

import 'package:avalanche_flutter_sdk/avalanche_flutter_sdk.dart';

// ---- ERC20Client ----

/// Client for interacting with ERC-20 tokens on Avalanche C-Chain.
///
/// Supports read operations via `eth_call` and write operations via
/// signed EIP-1559 transactions (`eth_sendRawTransaction`).
///
/// Compatible with any ERC-20 token on Avalanche C-Chain, including
/// USDC ([ERC20Constants.usdcMainnet]) and USDT
/// ([ERC20Constants.usdtMainnet]).
///
/// ABI encoding is implemented from scratch following the Ethereum
/// ABI specification - no external libraries required.
///
/// Sources:
/// - https://eips.ethereum.org/EIPS/eip-20
/// - https://docs.soliditylang.org/en/latest/abi-spec.html
class ERC20Client {
  // ---- Constructor ----

  /// Creates an [ERC20Client] backed by the given [CChainClient].
  ERC20Client(this._client);

  // ---- Fields ----

  final CChainClient _client;

  // ---- Public API: Read operations (eth_call) ----

  /// Returns the token balance of [ownerAddress] for the ERC-20
  /// token at [tokenAddress], in the token's smallest unit.
  ///
  /// For USDC (6 decimals): divide by 10^6 to get USDC amount.
  /// For tokens with 18 decimals: divide by 10^18.
  ///
  /// Uses `eth_call` with `balanceOf(address)` -> `0x70a08231`.
  Future<BigInt> balanceOf({
    required String tokenAddress,
    required String ownerAddress,
  }) async {
    final data = _encodeAddress(
      ERC20Constants.selectorBalanceOf,
      ownerAddress,
    );
    final result = await _ethCall(tokenAddress, data);
    return _decodeUint256(result);
  }

  /// Returns the number of decimals the token uses.
  ///
  /// USDC uses 6 decimals. Most ERC-20 tokens use 18 decimals.
  ///
  /// Uses `eth_call` with `decimals()` -> `0x313ce567`.
  Future<int> decimals(String tokenAddress) async {
    final data = Uint8List.fromList(ERC20Constants.selectorDecimals);
    final result = await _ethCall(tokenAddress, data);
    return _decodeUint256(result).toInt();
  }

  /// Returns the symbol of the token (e.g. "USDC", "USDT").
  ///
  /// Uses `eth_call` with `symbol()` -> `0x95d89b41`.
  Future<String> symbol(String tokenAddress) async {
    final data = Uint8List.fromList(ERC20Constants.selectorSymbol);
    final result = await _ethCall(tokenAddress, data);
    return _decodeString(result);
  }

  /// Returns the remaining allowance that [spenderAddress] is
  /// allowed to spend on behalf of [ownerAddress].
  ///
  /// Uses `eth_call` with `allowance(address,address)` -> `0xdd62ed3e`.
  Future<BigInt> allowance({
    required String tokenAddress,
    required String ownerAddress,
    required String spenderAddress,
  }) async {
    final data = _encodeTwoAddresses(
      ERC20Constants.selectorAllowance,
      ownerAddress,
      spenderAddress,
    );
    final result = await _ethCall(tokenAddress, data);
    return _decodeUint256(result);
  }

  // ---- Public API: Write operations (signed EIP-1559 tx) ----

  /// Transfers [amount] tokens from the sender to [toAddress].
  ///
  /// Signs and broadcasts an EIP-1559 transaction calling
  /// `transfer(address,uint256)` -> `0xa9059cbb`.
  ///
  /// Returns the transaction hash.
  Future<String> transfer({
    required String tokenAddress,
    required String toAddress,
    required BigInt amount,
    required PrivateKey privateKey,
    required int nonce,
    required int chainId,
    BigInt? maxFeePerGas,
    BigInt? maxPriorityFeePerGas,
  }) async {
    final fees = await _resolveFees(maxFeePerGas, maxPriorityFeePerGas);
    final data = _encodeAddressUint256(
      ERC20Constants.selectorTransfer,
      toAddress,
      amount,
    );
    return _sendContractTx(
      contractAddress: tokenAddress,
      data: data,
      privateKey: privateKey,
      nonce: nonce,
      chainId: chainId,
      maxFeePerGas: fees.$1,
      maxPriorityFeePerGas: fees.$2,
    );
  }

  /// Approves [spenderAddress] to spend up to [amount] tokens
  /// on behalf of the transaction sender.
  ///
  /// Signs and broadcasts an EIP-1559 transaction calling
  /// `approve(address,uint256)` -> `0x095ea7b3`.
  ///
  /// Returns the transaction hash.
  Future<String> approve({
    required String tokenAddress,
    required String spenderAddress,
    required BigInt amount,
    required PrivateKey privateKey,
    required int nonce,
    required int chainId,
    BigInt? maxFeePerGas,
    BigInt? maxPriorityFeePerGas,
  }) async {
    final fees = await _resolveFees(maxFeePerGas, maxPriorityFeePerGas);
    final data = _encodeAddressUint256(
      ERC20Constants.selectorApprove,
      spenderAddress,
      amount,
    );
    return _sendContractTx(
      contractAddress: tokenAddress,
      data: data,
      privateKey: privateKey,
      nonce: nonce,
      chainId: chainId,
      maxFeePerGas: fees.$1,
      maxPriorityFeePerGas: fees.$2,
    );
  }

  /// Transfers [amount] tokens from [fromAddress] to [toAddress]
  /// using a previously set allowance.
  ///
  /// Signs and broadcasts an EIP-1559 transaction calling
  /// `transferFrom(address,address,uint256)` -> `0x23b872dd`.
  ///
  /// Returns the transaction hash.
  Future<String> transferFrom({
    required String tokenAddress,
    required String fromAddress,
    required String toAddress,
    required BigInt amount,
    required PrivateKey privateKey,
    required int nonce,
    required int chainId,
    BigInt? maxFeePerGas,
    BigInt? maxPriorityFeePerGas,
  }) async {
    final fees = await _resolveFees(maxFeePerGas, maxPriorityFeePerGas);
    final data = _encodeTwoAddressesUint256(
      ERC20Constants.selectorTransferFrom,
      fromAddress,
      toAddress,
      amount,
    );
    return _sendContractTx(
      contractAddress: tokenAddress,
      data: data,
      privateKey: privateKey,
      nonce: nonce,
      chainId: chainId,
      maxFeePerGas: fees.$1,
      maxPriorityFeePerGas: fees.$2,
    );
  }

  // ---- Internal: eth_call ----

  Future<String> _ethCall(String contractAddress, Uint8List data) async {
    final hex =
        '0x${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
    return _client.ethCall(to: contractAddress, data: hex);
  }

  // ---- Internal: send contract transaction ----

  Future<String> _sendContractTx({
    required String contractAddress,
    required Uint8List data,
    required PrivateKey privateKey,
    required int nonce,
    required int chainId,
    required BigInt maxFeePerGas,
    required BigInt maxPriorityFeePerGas,
  }) async {
    // Derive sender address from private key for estimateGas
    final senderAddress =
        EvmAddress.fromPublicKey(privateKey.publicKey).checksumAddress;

    final gasLimit = await _client.estimateGas(
      to: contractAddress,
      from: senderAddress,
      data: '0x${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
    );

    final tx = AvaxTransferTransaction(
      chainId: chainId,
      nonce: nonce,
      maxPriorityFeePerGas: maxPriorityFeePerGas,
      maxFeePerGas: maxFeePerGas,
      gasLimit: gasLimit,
      to: contractAddress,
      value: BigInt.zero, // <- fix
      data: data,
    );

    final rawTx = tx.sign(privateKey);
    return _client.sendRawTransaction(rawTx);
  }

  // ---- Internal: fee resolution ----

  Future<(BigInt, BigInt)> _resolveFees(
    BigInt? maxFeePerGas,
    BigInt? maxPriorityFeePerGas,
  ) async {
    if (maxFeePerGas != null && maxPriorityFeePerGas != null) {
      return (maxFeePerGas, maxPriorityFeePerGas);
    }
    final estimator = GasEstimator(_client);
    final options = await estimator.getPriceOptions();
    return (
      maxFeePerGas ?? options.normal.maxFeePerGas,
      maxPriorityFeePerGas ?? options.normal.maxPriorityFeePerGas,
    );
  }

  // ---- Internal: ABI encoding ----
  // Per Ethereum ABI spec: https://docs.soliditylang.org/en/latest/abi-spec.html
  // address: padded to 32 bytes (left-padded with zeros)
  // uint256: big-endian 32 bytes

  static Uint8List _padAddress(String address) {
    final clean = address.startsWith('0x') ? address.substring(2) : address;
    final padded = clean.padLeft(64, '0');
    return Uint8List.fromList(
      List.generate(
        32,
        (i) => int.parse(padded.substring(i * 2, i * 2 + 2), radix: 16),
      ),
    );
  }

  static Uint8List _padUint256(BigInt value) {
    final hex = value.toRadixString(16).padLeft(64, '0');
    return Uint8List.fromList(
      List.generate(
        32,
        (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
      ),
    );
  }

  /// Encodes: selector(4) + address(32)
  static Uint8List _encodeAddress(List<int> selector, String address) {
    return Uint8List.fromList([...selector, ..._padAddress(address)]);
  }

  /// Encodes: selector(4) + address(32) + uint256(32)
  static Uint8List _encodeAddressUint256(
    List<int> selector,
    String address,
    BigInt value,
  ) {
    return Uint8List.fromList([
      ...selector,
      ..._padAddress(address),
      ..._padUint256(value),
    ]);
  }

  /// Encodes: selector(4) + address(32) + address(32)
  static Uint8List _encodeTwoAddresses(
    List<int> selector,
    String address1,
    String address2,
  ) {
    return Uint8List.fromList([
      ...selector,
      ..._padAddress(address1),
      ..._padAddress(address2),
    ]);
  }

  /// Encodes: selector(4) + address(32) + address(32) + uint256(32)
  static Uint8List _encodeTwoAddressesUint256(
    List<int> selector,
    String address1,
    String address2,
    BigInt value,
  ) {
    return Uint8List.fromList([
      ...selector,
      ..._padAddress(address1),
      ..._padAddress(address2),
      ..._padUint256(value),
    ]);
  }

  // ---- Internal: ABI decoding ----

  /// Decodes a uint256 from a 32-byte hex result.
  static BigInt _decodeUint256(String hexResult) {
    final clean =
        hexResult.startsWith('0x') ? hexResult.substring(2) : hexResult;
    if (clean.isEmpty) return BigInt.zero;
    return BigInt.parse(clean, radix: 16);
  }

  /// Decodes a dynamic string from ABI-encoded hex result.
  ///
  /// ABI string encoding:
  /// - bytes 0-31:  offset to string data (always 0x20 = 32)
  /// - bytes 32-63: length of string in bytes
  /// - bytes 64+:   UTF-8 string data (padded to 32-byte boundary)
  static String _decodeString(String hexResult) {
    final clean =
        hexResult.startsWith('0x') ? hexResult.substring(2) : hexResult;
    if (clean.length < 128) return '';

    // Length is at bytes 32-63 (chars 64-127)
    final lengthHex = clean.substring(64, 128);
    final length = int.parse(lengthHex, radix: 16);
    if (length == 0) return '';

    // String data starts at byte 64 (char 128)
    final dataHex = clean.substring(128, 128 + length * 2);
    final bytes = Uint8List.fromList(
      List.generate(
        length,
        (i) => int.parse(dataHex.substring(i * 2, i * 2 + 2), radix: 16),
      ),
    );
    return String.fromCharCodes(bytes);
  }
}
