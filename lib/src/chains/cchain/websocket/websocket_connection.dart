import 'dart:convert';

import 'package:web_socket_channel/io.dart';

// ---- WebSocketConnection ----

/// A minimal text-message WebSocket connection.
///
/// `CChainWebSocketClient` talks to the node through this interface, so the
/// transport can be replaced, for example by a fake in tests.
abstract interface class WebSocketConnection {
  /// The text messages received from the server.
  ///
  /// The stream is single-subscription. It completes when the connection is
  /// closed and emits an error if the transport fails.
  Stream<String> get messages;

  /// Sends a text [message] to the server.
  void send(String message);

  /// The close code reported once the connection is closed, if any.
  int? get closeCode;

  /// The close reason reported once the connection is closed, if any.
  String? get closeReason;

  /// Closes the connection.
  Future<void> close();
}

/// Opens a [WebSocketConnection] to [uri].
///
/// [pingInterval] is the heartbeat interval: if a ping is not answered with
/// a pong within that interval, the connection is closed. [connectTimeout]
/// bounds the time spent opening the connection.
typedef WebSocketConnector = Future<WebSocketConnection> Function(
  Uri uri, {
  Duration? pingInterval,
  Duration? connectTimeout,
});

/// The default [WebSocketConnector], built on `package:web_socket_channel`.
Future<WebSocketConnection> defaultWebSocketConnector(
  Uri uri, {
  Duration? pingInterval,
  Duration? connectTimeout,
}) async {
  final channel = IOWebSocketChannel.connect(
    uri,
    pingInterval: pingInterval,
    connectTimeout: connectTimeout,
  );
  await channel.ready;
  return _ChannelConnection(channel);
}

class _ChannelConnection implements WebSocketConnection {
  _ChannelConnection(this._channel) : messages = _channel.stream.map(_asText);

  final IOWebSocketChannel _channel;

  @override
  final Stream<String> messages;

  @override
  void send(String message) => _channel.sink.add(message);

  @override
  int? get closeCode => _channel.closeCode;

  @override
  String? get closeReason => _channel.closeReason;

  @override
  Future<void> close() => _channel.sink.close();

  static String _asText(Object? message) =>
      message is String ? message : utf8.decode(message! as List<int>);
}
