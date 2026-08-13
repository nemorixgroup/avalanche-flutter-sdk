import 'dart:convert';

import 'package:avalanche_flutter_sdk/src/chains/cchain/models/gas_price_option.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/models/gas_price_options.dart';
import 'package:avalanche_flutter_sdk/src/client/network_config.dart';
import 'package:avalanche_flutter_sdk/src/exceptions/avalanche_exception.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

// ---- CChainClient ----

/// JSON-RPC client for the Avalanche C-Chain.
///
/// The C-Chain is fully EVM-compatible and exposes a JSON-RPC API identical
/// to Geth, plus Avalanche-specific methods ([getBaseFee],
/// [suggestPriceOptions]).
///
/// Endpoint: `{network.cChainRpcUrl}` (e.g. `/ext/bc/C/rpc`)
///
/// Sources:
/// - https://build.avax.network/docs/rpcs/c-chain
/// - https://build.avax.network/docs/rpcs/other/guides/txn-fees
class CChainClient {
  // ---- Constructor ----

  /// Creates a [CChainClient] for the given [network].
  ///
  /// An optional [httpClient] can be provided for testing.
  CChainClient({required this.network, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  // ---- Fields ----

  /// The Avalanche network configuration (Mainnet or Fuji Testnet).
  final NetworkConfig network;

  final http.Client _http;

  static int _idCounter = 1;

  // ---- Public API: Account ----

  /// Returns the AVAX balance of [address] in Wei.
  ///
  /// Uses `eth_getBalance` with `"latest"` block tag.
  ///
  /// To convert to AVAX: divide by 10^18.
  ///
  /// Source: https://build.avax.network/docs/rpcs/c-chain
  Future<BigInt> getBalance(String address) async {
    final result = await _call(
      method: 'eth_getBalance',
      params: [address, 'latest'],
    );
    return _hexToBigInt(result as String);
  }

  /// Returns the transaction count (nonce) of [address].
  ///
  /// Uses `eth_getTransactionCount` with `"latest"` block tag.
  /// The nonce is required when building and signing transactions.
  ///
  /// Source: https://build.avax.network/docs/rpcs/c-chain
  Future<int> getTransactionCount(String address) async {
    final result = await _call(
      method: 'eth_getTransactionCount',
      params: [address, 'latest'],
    );
    return _hexToInt(result as String);
  }

  // ---- Public API: Block ----

  /// Returns the number of the most recently accepted block.
  ///
  /// Uses `eth_blockNumber`.
  ///
  /// Source: https://build.avax.network/docs/rpcs/c-chain
  Future<int> getBlockNumber() async {
    final result = await _call(
      method: 'eth_blockNumber',
      params: [],
    );
    return _hexToInt(result as String);
  }

  /// Returns the transaction receipt for [txHash], or `null` if not found.
  ///
  /// Uses `eth_getTransactionReceipt`. Returns `null` if the transaction
  /// has not been included in a block yet.
  ///
  /// Source: https://build.avax.network/docs/rpcs/c-chain
  Future<Map<String, dynamic>?> getTransactionReceipt(String txHash) async {
    final result = await _call(
      method: 'eth_getTransactionReceipt',
      params: [txHash],
    );
    if (result == null) return null;
    return Map<String, dynamic>.from(result as Map);
  }

  // ---- Public API: Gas (Avalanche-specific) ----

  /// Returns the base fee for the next block in Wei.
  ///
  /// Uses `eth_baseFee` - an Avalanche-specific method (not in standard Geth).
  ///
  /// Per Avalanche docs: "The base fee can go as low as 1 nAVAX (Gwei)
  /// and has no upper bound."
  ///
  /// Source: https://build.avax.network/docs/rpcs/c-chain#eth_basefee
  Future<BigInt> getBaseFee() async {
    final result = await _call(
      method: 'eth_baseFee',
      params: [],
    );
    return _hexToBigInt(result as String);
  }

  /// Returns the suggested maximum priority fee per gas in Wei.
  ///
  /// Uses `eth_maxPriorityFeePerGas`. Analyzes recent blocks to determine
  /// the priority fee needed to be included.
  ///
  /// Source: https://build.avax.network/docs/rpcs/c-chain
  Future<BigInt> getMaxPriorityFeePerGas() async {
    final result = await _call(
      method: 'eth_maxPriorityFeePerGas',
      params: [],
    );
    return _hexToBigInt(result as String);
  }

  /// Returns suggested gas price options (slow, normal, fast).
  ///
  /// Uses `eth_suggestPriceOptions` - an Avalanche-specific method that
  /// provides ready-to-use [GasPriceOptions] for EIP-1559 transactions.
  ///
  /// Each option includes [GasPriceOption.maxPriorityFeePerGas] and
  /// [GasPriceOption.maxFeePerGas] already calculated.
  ///
  /// Source: https://build.avax.network/docs/rpcs/c-chain#eth_suggestpriceoptions
  Future<GasPriceOptions> suggestPriceOptions() async {
    final result = await _call(
      method: 'eth_suggestPriceOptions',
      params: [],
    );
    final map = Map<String, dynamic>.from(result as Map);
    return GasPriceOptions(
      slow: _parseGasPriceOption(Map<String, dynamic>.from(map['slow'] as Map)),
      normal:
          _parseGasPriceOption(Map<String, dynamic>.from(map['normal'] as Map)),
      fast: _parseGasPriceOption(Map<String, dynamic>.from(map['fast'] as Map)),
    );
  }

  /// Estimates the gas required for a transaction.
  ///
  /// Uses `eth_estimateGas`. Pass a transaction object with at least
  /// [to], and optionally [from], [value], [data].
  ///
  /// Returns the estimated gas in gas units.
  ///
  /// Source: https://build.avax.network/docs/rpcs/c-chain
  Future<BigInt> estimateGas({
    required String to,
    String? from,
    BigInt? value,
    String? data,
  }) async {
    final tx = <String, dynamic>{'to': to};
    if (from != null) tx['from'] = from;
    if (value != null) tx['value'] = '0x${value.toRadixString(16)}';
    if (data != null) tx['data'] = data;

    final result = await _call(
      method: 'eth_estimateGas',
      params: [tx],
    );
    return _hexToBigInt(result as String);
  }

  // ---- Internal: JSON-RPC ----

  /// Exposes the internal JSON-RPC call for testing purposes.
  @visibleForTesting
  Future<dynamic> call({
    required String method,
    required List<dynamic> params,
  }) =>
      _call(method: method, params: params);

  Future<dynamic> _call({
    required String method,
    required List<dynamic> params,
  }) async {
    final id = _idCounter++;
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params,
    });

    final response = await _http.post(
      Uri.parse(network.cChainRpcUrl),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw AvalancheException(
        'C-Chain RPC HTTP error: ${response.statusCode}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (json.containsKey('error')) {
      final error = json['error'] as Map<String, dynamic>;
      throw AvalancheException(
        'C-Chain RPC error: ${error['message']} '
        '(code: ${error['code']})',
      );
    }

    return json['result'];
  }

  // ---- Internal: Helpers ----

  static BigInt _hexToBigInt(String hex) {
    final clean = hex.startsWith('0x') ? hex.substring(2) : hex;
    return BigInt.parse(clean.isEmpty ? '0' : clean, radix: 16);
  }

  static int _hexToInt(String hex) => _hexToBigInt(hex).toInt();

  static GasPriceOption _parseGasPriceOption(Map<String, dynamic> map) {
    return GasPriceOption(
      maxPriorityFeePerGas: _hexToBigInt(map['maxPriorityFeePerGas'] as String),
      maxFeePerGas: _hexToBigInt(map['maxFeePerGas'] as String),
    );
  }
}
