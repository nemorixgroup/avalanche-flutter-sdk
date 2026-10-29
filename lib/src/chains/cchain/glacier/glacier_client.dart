import 'dart:convert';

import 'package:avalanche_flutter_sdk/src/chains/cchain/glacier/models/glacier_erc20_balance.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/glacier/models/glacier_erc20_transfer.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/glacier/models/glacier_native_balance.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/glacier/models/glacier_page.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/glacier/models/glacier_transaction.dart';
import 'package:avalanche_flutter_sdk/src/client/network_config.dart';
import 'package:avalanche_flutter_sdk/src/exceptions/avalanche_exception.dart';
import 'package:http/http.dart' as http;

// ---- GlacierClient ----

/// REST client for the Avalanche Glacier Data API.
///
/// Provides indexed blockchain data including balances, transaction
/// history, and token transfers. Powered by Ava Labs.
///
/// The API key is optional. Without a key, the unauthenticated tier
/// applies (6,000 CUs/min). With a free key from AvaCloud, the limit
/// increases to 8,000 CUs/min.
///
/// Get a free API key at:
/// https://build.avax.network/console/utilities/data-api-keys
///
/// Source: https://build.avax.network/docs/api-reference/data-api/usage
class GlacierClient {
  // ---- Constructor ----

  /// Creates a [GlacierClient] for the given [network].
  ///
  /// [apiKey] is optional. Without it, unauthenticated rate limits apply
  /// (6,000 CUs/min). With a free key from AvaCloud, limits increase to
  /// 8,000 CUs/min.
  GlacierClient({
    required this.network,
    this.apiKey,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  // ---- Fields ----

  /// The Avalanche network configuration (Mainnet or Fuji Testnet).
  final NetworkConfig network;

  /// Optional Glacier API key for higher rate limits.
  ///
  /// Get a free key at:
  /// https://build.avax.network/console/utilities/data-api-keys
  final String? apiKey;

  final http.Client _http;

  // ---- Constants ----

  static const String _baseUrl = 'https://glacier-api.avax.network/v1';
  static const String _apiKeyHeader = 'x-glacier-api-key';

  // ---- Public API: Balances ----

  /// Returns the native AVAX balance of [address].
  ///
  /// Uses `GET /v1/chains/{chainId}/addresses/{address}/balances:getNative`
  ///
  /// Source:
  /// build.avax.network/docs/api-reference/data-api/evm-balances/getNativeBalance
  Future<GlacierNativeBalance> getAvaxBalance(String address) async {
    final response = await _get(
      '/chains/${network.chainId}/addresses/$address/balances:getNative',
    );
    final json = response['nativeTokenBalance'] as Map<String, dynamic>;
    return GlacierNativeBalance.fromJson(json);
  }

  /// Returns the ERC-20 token balances of [address].
  ///
  /// [pageSize] accepts 1 to 500 (API default: 10). Spam tokens are
  /// filtered out by default on the API side.
  ///
  /// Uses `GET /v1/chains/{chainId}/addresses/{address}/balances:listErc20`
  ///
  /// Source:
  /// build.avax.network/docs/api-reference/data-api/evm-balances/listErc20Balances
  Future<GlacierPage<GlacierErc20Balance>> getErc20Balances(
    String address, {
    int? pageSize,
    String? pageToken,
  }) async {
    final response = await _get(
      '/chains/${network.chainId}/addresses/$address/balances:listErc20',
      queryParams: _pageParams(pageSize, pageToken),
    );

    final items =
        (response['erc20TokenBalances'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => GlacierErc20Balance.fromJson(e as Map<String, dynamic>))
            .toList();

    return GlacierPage(
      items: items,
      nextPageToken: response['nextPageToken'] as String?,
    );
  }

  // ---- Public API: Transactions ----

  /// Returns native AVAX transaction history for [address].
  ///
  /// [pageSize] accepts 1 to 100 (API default: 10).
  ///
  /// Uses
  /// `GET /v1/chains/{chainId}/addresses/{address}/transactions:listNative`
  ///
  /// Source:
  /// build.avax.network/docs/api-reference/data-api/evm-transactions/listNativeTransactions
  Future<GlacierPage<GlacierTransaction>> getTransactions(
    String address, {
    int? pageSize,
    String? pageToken,
  }) async {
    final response = await _get(
      '/chains/${network.chainId}/addresses/$address/transactions:listNative',
      queryParams: _pageParams(pageSize, pageToken),
    );

    final items = (response['transactions'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => GlacierTransaction.fromJson(e as Map<String, dynamic>))
        .toList();

    return GlacierPage(
      items: items,
      nextPageToken: response['nextPageToken'] as String?,
    );
  }

  /// Returns ERC-20 token transfer history for [address].
  ///
  /// Items are token transfer events ([GlacierErc20Transfer]), not full
  /// transactions. [pageSize] accepts 1 to 100 (API default: 10).
  ///
  /// Uses
  /// `GET /v1/chains/{chainId}/addresses/{address}/transactions:listErc20`
  ///
  /// Source:
  /// build.avax.network/docs/api-reference/data-api/evm-transactions/listErc20Transactions
  Future<GlacierPage<GlacierErc20Transfer>> getErc20Transfers(
    String address, {
    int? pageSize,
    String? pageToken,
  }) async {
    final response = await _get(
      '/chains/${network.chainId}/addresses/$address/transactions:listErc20',
      queryParams: _pageParams(pageSize, pageToken),
    );

    final items = (response['transactions'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => GlacierErc20Transfer.fromJson(e as Map<String, dynamic>))
        .toList();

    return GlacierPage(
      items: items,
      nextPageToken: response['nextPageToken'] as String?,
    );
  }

  /// Returns the native transaction details for [txHash].
  ///
  /// The API response also contains `erc20Transfers`, `erc721Transfers`,
  /// `erc1155Transfers` and `internalTransactions` for the same
  /// transaction; these are not modeled yet. Only the `nativeTransaction`
  /// object is returned here.
  ///
  /// Uses `GET /v1/chains/{chainId}/transactions/{txHash}`
  ///
  /// Source:
  /// build.avax.network/docs/api-reference/data-api/evm-transactions/getTransaction
  Future<GlacierTransaction> getTransaction(String txHash) async {
    final response = await _get(
      '/chains/${network.chainId}/transactions/$txHash',
    );
    final json = response['nativeTransaction'] as Map<String, dynamic>;
    return GlacierTransaction.fromJson(json);
  }

  // ---- Internal: HTTP ----

  static Map<String, String> _pageParams(int? pageSize, String? pageToken) {
    return <String, String>{
      if (pageSize != null) 'pageSize': pageSize.toString(),
      if (pageToken != null) 'pageToken': pageToken,
    };
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: queryParams?.isNotEmpty ?? false ? queryParams : null,
    );

    final headers = <String, String>{
      'accept': 'application/json',
      if (apiKey != null) _apiKeyHeader: apiKey!,
    };

    final response = await _http.get(uri, headers: headers);

    if (response.statusCode == 429) {
      throw AvalancheException(
        'Glacier API rate limit exceeded. '
        'Add an API key for higher limits: '
        'build.avax.network/console/utilities/data-api-keys',
      );
    }

    if (response.statusCode != 200) {
      throw AvalancheException(
        'Glacier API error ${response.statusCode}: '
        '${_errorMessage(response.body)}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static String _errorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return '${decoded['message'] ?? decoded['error'] ?? 'Unknown error'}';
      }
    } on FormatException {
      // Non-JSON error body (e.g. HTML from a gateway); fall through.
    }
    return 'Unknown error';
  }
}
