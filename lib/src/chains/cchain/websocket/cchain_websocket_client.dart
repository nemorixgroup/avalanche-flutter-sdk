import 'dart:async';
import 'dart:convert';

import 'package:avalanche_flutter_sdk/src/chains/cchain/erc20/erc20_constants.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/websocket/models/accepted_transaction.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/websocket/models/erc20_transfer_event.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/websocket/models/evm_log.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/websocket/models/new_head.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/websocket/reconnect_policy.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/websocket/websocket_connection.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/websocket/websocket_status.dart';
import 'package:avalanche_flutter_sdk/src/client/network_config.dart';
import 'package:avalanche_flutter_sdk/src/exceptions/avalanche_exception.dart';

// ---- CChainWebSocketClient ----

/// Real-time subscriptions to the Avalanche C-Chain over WebSocket.
///
/// One WebSocket connection carries any number of subscriptions
/// (`eth_subscribe`). Each subscription is a [Stream]: it is created on the
/// node when the stream is listened to and removed (`eth_unsubscribe`) when
/// the listener cancels. Cancelling returns immediately; the unsubscribe is
/// sent in the background.
///
/// ```dart
/// final ws = CChainWebSocketClient(network: NetworkConfig.fuji);
/// await ws.connect();
///
/// final heads = ws.newHeads().listen((head) => print(head.number));
/// // ...
/// await heads.cancel();
/// await ws.close();
/// ```
///
/// By default, if the connection drops, every active stream receives an
/// [AvalancheException] and then completes. Pass a [ReconnectPolicy] to
/// reconnect with exponential backoff and re-establish the subscriptions
/// automatically: the streams stay open and [status] reports
/// [WebSocketStatus.reconnecting] and [WebSocketStatus.reconnected].
/// Events emitted while the client was disconnected are not replayed, so
/// fill the gap yourself when [WebSocketStatus.reconnected] arrives.
///
/// A frame that cannot be parsed is delivered as an error event on its
/// stream; the subscription stays active.
///
/// Sources:
/// - https://build.avax.network/docs/rpcs/c-chain
/// - https://build.avax.network/docs/nodes/chain-configs/primary-network/c-chain
class CChainWebSocketClient {
  // ---- Constructor ----

  /// Creates a client for the C-Chain WebSocket of [network].
  ///
  /// [pingInterval] is the heartbeat interval and [connectTimeout] bounds
  /// the time spent opening the connection. [reconnectPolicy] enables
  /// automatic reconnection; without it the client does not reconnect. A
  /// custom [connector] replaces the default transport.
  CChainWebSocketClient({
    required this.network,
    this.pingInterval = const Duration(seconds: 20),
    this.connectTimeout = const Duration(seconds: 15),
    this.reconnectPolicy,
    WebSocketConnector? connector,
  }) : _connector = connector ?? defaultWebSocketConnector;

  // ---- Fields ----

  /// The Avalanche network configuration (Mainnet or Fuji Testnet).
  final NetworkConfig network;

  /// The heartbeat interval. If a ping is not answered within this
  /// interval, the connection is closed.
  final Duration pingInterval;

  /// The maximum time to wait while opening the connection.
  final Duration connectTimeout;

  /// How the client reconnects after losing the connection, or null to not
  /// reconnect.
  final ReconnectPolicy? reconnectPolicy;

  final WebSocketConnector _connector;

  WebSocketConnection? _connection;
  StreamSubscription<String>? _messageSubscription;
  Future<void>? _connecting;
  int _nextRequestId = 1;
  int _generation = 0;
  bool _reconnecting = false;
  final Map<int, _PendingRequest> _pending = <int, _PendingRequest>{};
  final Set<_Subscription> _all = <_Subscription>{};
  final Map<String, _Subscription> _byId = <String, _Subscription>{};

  // The controller lives as long as the client, which can reconnect after
  // close(), so it is never closed.
  // ignore: close_sinks
  final StreamController<WebSocketStatus> _status =
      StreamController<WebSocketStatus>.broadcast();

  static final RegExp _addressPattern = RegExp(r'^(0x|0X)?[0-9a-fA-F]{40}$');

  // ---- Connection ----

  /// True while the connection is open.
  bool get isConnected => _connection != null;

  /// True while the client is trying to restore a lost connection.
  bool get isReconnecting => _reconnecting;

  /// The connection state changes: connected, reconnecting, reconnected and
  /// disconnected.
  ///
  /// It is a broadcast stream and does not replay past events.
  Stream<WebSocketStatus> get status => _status.stream;

  /// Opens the connection to the C-Chain WebSocket.
  ///
  /// Does nothing if the client is already connected. Throws an
  /// [AvalancheException] if the connection cannot be opened, or if the
  /// client is already reconnecting on its own.
  Future<void> connect() {
    if (isConnected) return Future<void>.value();
    if (_reconnecting) {
      return Future<void>.error(
        AvalancheException(
          'The client is reconnecting automatically. '
          'Wait for WebSocketStatus.reconnected.',
        ),
      );
    }
    return _connecting ??= _connectOnce().whenComplete(() {
      _connecting = null;
    });
  }

  /// Closes the connection and stops any reconnection in progress.
  ///
  /// Active subscription streams complete without an error. Does nothing if
  /// the client is neither connected nor reconnecting.
  Future<void> close() async {
    _generation++;
    final wasReconnecting = _reconnecting;
    _reconnecting = false;
    final connection = _connection;
    if (connection == null && !wasReconnecting) return;
    _connection = null;
    _failAll(null);
    await _messageSubscription?.cancel();
    _messageSubscription = null;
    _emitStatus(WebSocketStatus.disconnected);
    if (connection != null) await _closeQuietly(connection);
  }

  Future<void> _connectOnce() async {
    final connection = await _openTransport();
    _attach(connection);
    _emitStatus(WebSocketStatus.connected);
  }

  Future<WebSocketConnection> _openTransport() async {
    try {
      return await _connector(
        Uri.parse(network.cChainWsUrl),
        pingInterval: pingInterval,
        connectTimeout: connectTimeout,
      );
    } on Object catch (e) {
      throw AvalancheException(
        'Could not connect to the C-Chain WebSocket '
        '(${network.cChainWsUrl}): $e',
      );
    }
  }

  void _attach(WebSocketConnection connection) {
    _connection = connection;
    _messageSubscription = connection.messages.listen(
      _handleMessage,
      onError: (Object e) =>
          _handleConnectionLost('C-Chain WebSocket error: $e'),
      onDone: () => _handleConnectionLost(
        'C-Chain WebSocket closed (code: ${connection.closeCode}, '
        'reason: ${connection.closeReason})',
      ),
    );
  }

  Future<void> _closeQuietly(WebSocketConnection connection) async {
    try {
      await connection.close();
    } on Object {
      // Closing is best effort: the connection may already be gone.
    }
  }

  void _emitStatus(WebSocketStatus value) {
    if (!_status.isClosed) _status.add(value);
  }

  // ---- Subscriptions ----

  /// Streams every new block header.
  ///
  /// Uses `eth_subscribe("newHeads")`.
  Stream<NewHead> newHeads() {
    return _subscribe<NewHead>(
      <Object?>['newHeads'],
      (Object? payload) => NewHead.fromJson(_asObject(payload)),
    );
  }

  /// Streams event logs that match the optional filter.
  ///
  /// [address] restricts the logs to one contract. [topics] filters by
  /// indexed topics by position: use `null` for a position that can have any
  /// value. Without a filter the node sends every log on the chain.
  ///
  /// During a chain reorganization the node resends logs of the old chain
  /// with [EvmLog.removed] set to true.
  ///
  /// Uses `eth_subscribe("logs", filter)`.
  Stream<EvmLog> logs({String? address, List<String?>? topics}) {
    final filter = <String, Object?>{
      if (address != null) 'address': address,
      if (topics != null) 'topics': topics,
    };
    return _subscribe<EvmLog>(
      <Object?>['logs', if (filter.isNotEmpty) filter],
      (Object? payload) => EvmLog.fromJson(_asObject(payload)),
    );
  }

  /// Streams the ERC-20 `Transfer` events that send [tokenAddress] tokens to
  /// the address [to].
  ///
  /// The node filters the logs by contract and by recipient, so only the
  /// transfers you care about travel over the connection. Each event is an
  /// [Erc20TransferEvent]. During a chain reorganization a transfer can be
  /// resent with [Erc20TransferEvent.removed] set to true: undo whatever you
  /// did for it.
  ///
  /// [tokenAddress] and [to] accept any casing and may omit the `0x` prefix.
  /// Throws an [ArgumentError] if either is not a 20-byte hex address.
  ///
  /// A log from the contract that is not an ERC-20 transfer (for example,
  /// from an ERC-721 contract, whose `Transfer` has a fourth topic) is
  /// delivered as a [FormatException] error event, and the stream stays
  /// active.
  ///
  /// Only token transfers are covered. A native AVAX transfer emits no log;
  /// use [newAcceptedTransactions] for those.
  ///
  /// Uses `eth_subscribe("logs", filter)`.
  Stream<Erc20TransferEvent> watchIncomingErc20Transfers({
    required String tokenAddress,
    required String to,
  }) {
    final token = _checkedAddress(tokenAddress, 'tokenAddress');
    final recipient = _checkedAddress(to, 'to');
    final recipientTopic =
        '0x${'0' * 24}${recipient.substring(2).toLowerCase()}';
    return logs(
      address: token,
      topics: <String?>[
        ERC20Constants.transferEventTopic,
        null,
        recipientTopic,
      ],
    ).map(Erc20TransferEvent.fromLog);
  }

  /// Streams every transaction accepted on the chain, with full details.
  ///
  /// This is an Avalanche-specific subscription. It fires when a
  /// transaction is accepted, before the block is executed. The stream
  /// carries all transactions on the network, not only yours, so filter by
  /// [AcceptedTransaction.to] or [AcceptedTransaction.from] in your handler.
  ///
  /// Uses `eth_subscribe("newAcceptedTransactions", true)`.
  Stream<AcceptedTransaction> newAcceptedTransactions() {
    return _subscribe<AcceptedTransaction>(
      <Object?>['newAcceptedTransactions', true],
      (Object? payload) => AcceptedTransaction.fromJson(_asObject(payload)),
    );
  }

  /// Streams only the hashes of the transactions accepted on the chain.
  ///
  /// Much lighter than [newAcceptedTransactions], but a hash alone does not
  /// tell you whether a transaction involves your address.
  ///
  /// Uses `eth_subscribe("newAcceptedTransactions", false)`.
  Stream<String> newAcceptedTransactionHashes() {
    return _subscribe<String>(
      <Object?>['newAcceptedTransactions', false],
      (Object? payload) {
        if (payload is String) return payload;
        throw FormatException('Unexpected transaction hash payload: $payload');
      },
    );
  }

  Stream<T> _subscribe<T>(
    List<Object?> params,
    T Function(Object? payload) parse,
  ) {
    late final StreamController<T> controller;
    late final _Subscription record;

    record = _Subscription(
      params: params,
      onPayload: (Object? payload) {
        if (controller.isClosed) return;
        try {
          controller.add(parse(payload));
        } on Object catch (e) {
          controller.addError(e);
        }
      },
      onClosed: (AvalancheException? error) {
        if (controller.isClosed) return;
        if (error != null) controller.addError(error);
        unawaited(controller.close());
      },
    );
    controller = StreamController<T>(
      onListen: () => _start(record),
      onCancel: () => _cancel(record),
    );
    return controller.stream;
  }

  void _start(_Subscription record) {
    _all.add(record);
    // While reconnecting, the subscription is created once the connection is
    // restored.
    if (_reconnecting) return;
    unawaited(_sendSubscribe(record));
  }

  void _cancel(_Subscription record) {
    record.cancelled = true;
    _all.remove(record);
    final id = record.id;
    if (id != null) {
      _byId.remove(id);
      _unsubscribeQuietly(id);
    }
  }

  Future<void> _sendSubscribe(_Subscription record) async {
    record.requested = true;
    try {
      final result = await _request(
        'eth_subscribe',
        record.params,
        onResult: (Object? result) {
          // Runs synchronously while the response frame is handled, so the
          // notifications that follow it always find their handler.
          if (result is! String) return;
          if (record.cancelled) {
            _unsubscribeQuietly(result);
            return;
          }
          record.id = result;
          _byId[result] = record;
        },
      );
      if (record.id == null && !record.cancelled) {
        throw AvalancheException('Unexpected eth_subscribe result: $result');
      }
    } on AvalancheException catch (e) {
      // While reconnecting, the reconnection loop retries this subscription.
      if (record.cancelled || _reconnecting) return;
      _all.remove(record);
      record.onClosed(e);
    }
  }

  void _unsubscribeQuietly(String subscriptionId) {
    if (!isConnected) return;
    unawaited(
      _request('eth_unsubscribe', <Object?>[subscriptionId]).then<void>(
        (Object? _) {},
        onError: (Object _) {},
      ),
    );
  }

  // ---- JSON-RPC ----

  Future<Object?> _request(
    String method,
    List<Object?> params, {
    void Function(Object? result)? onResult,
  }) {
    final connection = _connection;
    if (connection == null) {
      return Future<Object?>.error(
        AvalancheException(
          'The C-Chain WebSocket is not connected. Call connect() first.',
        ),
      );
    }
    final id = _nextRequestId++;
    final pending = _PendingRequest(onResult);
    _pending[id] = pending;
    try {
      connection.send(
        jsonEncode(<String, Object?>{
          'jsonrpc': '2.0',
          'id': id,
          'method': method,
          'params': params,
        }),
      );
    } on Object catch (e) {
      _pending.remove(id);
      return Future<Object?>.error(
        AvalancheException('Could not send $method over the WebSocket: $e'),
      );
    }
    return pending.completer.future;
  }

  void _handleMessage(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return;
    }
    if (decoded is! Map<String, dynamic>) return;

    // Responses are matched by id: they can arrive in any order.
    final id = decoded['id'];
    if (id is int) {
      final pending = _pending.remove(id);
      if (pending == null) return;
      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        pending.completer.completeError(
          AvalancheException(
            'C-Chain WebSocket error: ${error['message']} '
            '(code: ${error['code']})',
          ),
        );
        return;
      }
      final result = decoded['result'];
      pending.onResult?.call(result);
      pending.completer.complete(result);
      return;
    }

    if (decoded['method'] == 'eth_subscription') {
      final params = decoded['params'];
      if (params is! Map<String, dynamic>) return;
      final subscription = params['subscription'];
      if (subscription is! String) return;
      _byId[subscription]?.onPayload(params['result']);
    }
  }

  // ---- Connection loss and reconnection ----

  void _handleConnectionLost(String reason) {
    if (_connection == null) return;
    _connection = null;
    unawaited(_messageSubscription?.cancel());
    _messageSubscription = null;
    _byId.clear();
    for (final record in _all) {
      record
        ..id = null
        ..requested = false;
    }

    final policy = reconnectPolicy;
    if (policy == null) {
      _failAll(AvalancheException(reason));
      _emitStatus(WebSocketStatus.disconnected);
      return;
    }
    _reconnecting = true;
    _emitStatus(WebSocketStatus.reconnecting);
    _failPending(AvalancheException(reason));
    unawaited(_reconnectLoop(policy, reason));
  }

  Future<void> _reconnectLoop(
    ReconnectPolicy policy,
    String firstReason,
  ) async {
    final generation = ++_generation;
    var lastReason = firstReason;
    for (var attempt = 1;; attempt++) {
      final maxAttempts = policy.maxAttempts;
      if (maxAttempts != null && attempt > maxAttempts) {
        _reconnecting = false;
        _failAll(
          AvalancheException(
            'Could not reconnect to the C-Chain WebSocket after '
            '$maxAttempts attempts. Last error: $lastReason',
          ),
        );
        _emitStatus(WebSocketStatus.disconnected);
        return;
      }

      await Future<void>.delayed(policy.delayForAttempt(attempt));
      if (generation != _generation) return;

      final WebSocketConnection connection;
      try {
        connection = await _openTransport();
      } on AvalancheException catch (e) {
        lastReason = '$e';
        if (generation != _generation) return;
        continue;
      }
      if (generation != _generation) {
        await _closeQuietly(connection);
        return;
      }

      _attach(connection);
      await _resubscribeAll(generation);
      return;
    }
  }

  Future<void> _resubscribeAll(int generation) async {
    final confirmations = <Future<void>>[];
    for (final record in _all.toList()) {
      if (!record.requested) confirmations.add(_sendSubscribe(record));
    }
    // No await between the loop above and this line: a subscription started
    // by the application cannot slip in unnoticed.
    _reconnecting = false;
    await Future.wait(confirmations);
    if (generation != _generation) return;
    _emitStatus(WebSocketStatus.reconnected);
  }

  /// Fails the pending requests and ends every subscription stream.
  ///
  /// A null [error] means the client closed the connection on purpose.
  void _failAll(AvalancheException? error) {
    final records = _all.toList();
    _all.clear();
    _byId.clear();
    for (final record in records) {
      record.onClosed(error);
    }
    _failPending(error);
  }

  void _failPending(AvalancheException? error) {
    final pending = _pending.values.toList();
    _pending.clear();
    for (final request in pending) {
      request.completer.completeError(
        error ?? AvalancheException('The WebSocket was closed by the client.'),
      );
    }
  }

  static Map<String, dynamic> _asObject(Object? payload) {
    if (payload is Map<String, dynamic>) return payload;
    throw FormatException('Unexpected notification payload: $payload');
  }

  /// Validates a 20-byte hex address and returns it with a `0x` prefix.
  ///
  /// The casing of the hex digits is kept as given.
  static String _checkedAddress(String value, String name) {
    if (!_addressPattern.hasMatch(value)) {
      throw ArgumentError.value(value, name, 'must be a 20-byte hex address');
    }
    final hex = value.startsWith('0x') || value.startsWith('0X')
        ? value.substring(2)
        : value;
    return '0x$hex';
  }
}

class _PendingRequest {
  _PendingRequest(this.onResult);

  final void Function(Object? result)? onResult;
  final Completer<Object?> completer = Completer<Object?>();
}

class _Subscription {
  _Subscription({
    required this.params,
    required this.onPayload,
    required this.onClosed,
  });

  final List<Object?> params;
  final void Function(Object? payload) onPayload;
  final void Function(AvalancheException? error) onClosed;

  /// The id the node gave to the active subscription, or null.
  String? id;

  /// True once an `eth_subscribe` was sent on the current connection.
  bool requested = false;

  /// True once the application cancelled the stream.
  bool cancelled = false;
}
