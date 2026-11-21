// ignore_for_file: cancel_subscriptions, lines_longer_than_80_chars

import 'dart:async';
import 'dart:convert';

import 'package:avalanche_flutter_sdk/src/chains/cchain/erc20/erc20_constants.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/websocket/cchain_websocket_client.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/websocket/models/accepted_transaction.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/websocket/models/evm_log.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/websocket/models/new_head.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/websocket/websocket_connection.dart';
import 'package:avalanche_flutter_sdk/src/client/network_config.dart';
import 'package:avalanche_flutter_sdk/src/exceptions/avalanche_exception.dart';
import 'package:flutter_test/flutter_test.dart';

// ---- Fixtures captured from live Fuji frames ----

// Subscription ids returned by the Fuji node in the smoke test.
const headsId = '0xfae52078103840cc7e3991c49e80cd60';
const logsId = '0x550d00a4a16638e8f321ad841a7ed87c';
const acceptedId = '0x91bdbb8ddd341587c810321b7dd2ca3d';

const receiverTopic =
    '0x0000000000000000000000000feb475783e004621b9463aae30f33665485fafa';

// A transaction hash from a live fullTx=false frame.
const acceptedHash =
    '0x8c7d27fdf4f2881ecd5d79c9004f542956aea8bf4596ebdac0ee638e6012e9da';

// newHeads result (subset of the live header for block 0x3a74ab7).
Map<String, dynamic> headJson() => <String, dynamic>{
      'parentHash':
          '0x2758ee95e64cdc0002b14bc259a82be9a03fa140fb5f806a1746dc5001b4a1ed',
      'miner': '0x0100000000000000000000000000000000000000',
      'number': '0x3a74ab7',
      'gasLimit': '0x1e84800',
      'gasUsed': '0x16e360',
      'timestamp': '0x6afdec24',
      'baseFeePerGas': '0xa',
      'timestampMilliseconds': '0x1a1efe2703c',
      'hash':
          '0x810731966bd5b550c8737c0cb1ede617c591ab93e5bac48d84a84d605f5f1232',
    };

// logs result: the live 1 USDC Transfer (block 0x3a74aba).
Map<String, dynamic> logJson() => <String, dynamic>{
      'address': '0x5425890298aed601595a70ab815c96711a31bc65',
      'topics': <String>[
        '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef',
        '0x000000000000000000000000e9d70ee1dfced40152ea3f030d0a3918f2ee81a8',
        receiverTopic,
      ],
      'data':
          '0x00000000000000000000000000000000000000000000000000000000000f4240',
      'blockNumber': '0x3a74aba',
      'transactionHash':
          '0xb72785e8b1d08e94a5a45c72043f64e6d5e12f7a03ec7335f7832cead080bc2a',
      'transactionIndex': '0x0',
      'blockHash':
          '0xf6e514178ae31683fceda8a065b118f67c1bdfd37fb025a921f9034bcd1310a6',
      'logIndex': '0x0',
      'removed': false,
    };

// newAcceptedTransactions result: the live legacy contract creation
// ("to" is null). The calldata was shortened.
Map<String, dynamic> creationJson() => <String, dynamic>{
      'blockHash':
          '0x810731966bd5b550c8737c0cb1ede617c591ab93e5bac48d84a84d605f5f1232',
      'blockNumber': '0x3a74ab7',
      'from': '0x4406f0d6115ba233cb413356dc8c91a60a921bc5',
      'gas': '0x16e360',
      'gasPrice': '0x5d21dba00',
      'hash':
          '0x919767b5f5ed6e548da1e219c2c7b826f4b07701b6c016f5ce61da50e57c9b67',
      'input': '0x6080604052',
      'nonce': '0x17',
      'to': null,
      'transactionIndex': '0x0',
      'value': '0x0',
      'type': '0x0',
      'chainId': '0xa869',
      'v': '0x150f5',
      'r': '0x7bc302a83926e7a99542db1238ab80dcf42f111dca0b34c1314b61d3eb0965b9',
      's': '0x235dc5be49f0ae210a82aeeca97fda9e6a81d2cf34a86c74658d9bf8438e2466',
    };

// ---- Test helpers ----

/// Lets pending microtasks and timers run.
Future<void> pump() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// A scripted transport: the test plays the role of the node.
class _FakeConnection implements WebSocketConnection {
  final StreamController<String> _incoming = StreamController<String>();
  final List<String> sent = <String>[];
  bool closed = false;
  int? _closeCode;
  String? _closeReason;

  @override
  Stream<String> get messages => _incoming.stream;

  @override
  int? get closeCode => _closeCode;

  @override
  String? get closeReason => _closeReason;

  @override
  void send(String message) => sent.add(message);

  @override
  Future<void> close() async {
    closed = true;
    if (!_incoming.isClosed) unawaited(_incoming.close());
  }

  /// The JSON-RPC request the client sent at [index].
  Map<String, dynamic> request(int index) =>
      jsonDecode(sent[index]) as Map<String, dynamic>;

  /// A successful JSON-RPC response.
  void respond(int id, Object? result) => _push(<String, Object?>{
        'jsonrpc': '2.0',
        'id': id,
        'result': result,
      });

  /// A JSON-RPC error response.
  void respondError(int id, int code, String message) =>
      _push(<String, Object?>{
        'jsonrpc': '2.0',
        'id': id,
        'error': <String, Object?>{'code': code, 'message': message},
      });

  /// An `eth_subscription` notification.
  void notify(String subscription, Object? result) => _push(<String, Object?>{
        'jsonrpc': '2.0',
        'method': 'eth_subscription',
        'params': <String, Object?>{
          'subscription': subscription,
          'result': result,
        },
      });

  /// A raw text frame, valid JSON or not.
  void receiveRaw(String raw) => _incoming.add(raw);

  /// The server closes the connection.
  void serverClose({int? code, String? reason}) {
    _closeCode = code;
    _closeReason = reason;
    unawaited(_incoming.close());
  }

  /// The transport reports an error.
  void fail(Object error) => _incoming.addError(error);

  void _push(Map<String, Object?> frame) => _incoming.add(jsonEncode(frame));
}

/// Records everything a stream emits.
class _Collected<T> {
  _Collected(Stream<T> stream) {
    subscription = stream.listen(
      events.add,
      onError: errors.add,
      onDone: () => done = true,
    );
  }

  final List<T> events = <T>[];
  final List<Object> errors = <Object>[];
  bool done = false;
  late final StreamSubscription<T> subscription;
}

void main() {
  late _FakeConnection fake;
  late CChainWebSocketClient client;
  var connectCalls = 0;
  Uri? lastUri;
  Duration? lastPing;
  Duration? lastTimeout;

  Future<WebSocketConnection> connector(
    Uri uri, {
    Duration? pingInterval,
    Duration? connectTimeout,
  }) async {
    connectCalls++;
    lastUri = uri;
    lastPing = pingInterval;
    lastTimeout = connectTimeout;
    return fake;
  }

  setUp(() {
    fake = _FakeConnection();
    connectCalls = 0;
    lastUri = null;
    lastPing = null;
    lastTimeout = null;
    client = CChainWebSocketClient(
      network: NetworkConfig.fuji,
      connector: connector,
    );
  });

  // ---- Connection ----

  group('CChainWebSocketClient - connection', () {
    test('opens the Fuji WebSocket with the default heartbeat', () async {
      await client.connect();
      expect(
        lastUri.toString(),
        equals('wss://api.avax-test.network/ext/bc/C/ws'),
      );
      expect(lastPing, equals(const Duration(seconds: 20)));
      expect(lastTimeout, equals(const Duration(seconds: 15)));
      expect(client.isConnected, isTrue);
    });

    test('forwards a custom ping interval and connect timeout', () async {
      final custom = CChainWebSocketClient(
        network: NetworkConfig.mainnet,
        pingInterval: const Duration(seconds: 5),
        connectTimeout: const Duration(seconds: 3),
        connector: connector,
      );
      await custom.connect();
      expect(
        lastUri.toString(),
        equals('wss://api.avax.network/ext/bc/C/ws'),
      );
      expect(lastPing, equals(const Duration(seconds: 5)));
      expect(lastTimeout, equals(const Duration(seconds: 3)));
    });

    test('connecting twice opens a single connection', () async {
      await client.connect();
      await client.connect();
      expect(connectCalls, equals(1));
    });

    test('concurrent connect calls share one connection attempt', () async {
      await Future.wait(<Future<void>>[client.connect(), client.connect()]);
      expect(connectCalls, equals(1));
    });

    test('throws an AvalancheException when the transport fails', () async {
      Future<WebSocketConnection> failingConnector(
        Uri uri, {
        Duration? pingInterval,
        Duration? connectTimeout,
      }) async =>
          throw Exception('down');

      final failing = CChainWebSocketClient(
        network: NetworkConfig.fuji,
        connector: failingConnector,
      );
      await expectLater(failing.connect(), throwsA(isA<AvalancheException>()));
      expect(failing.isConnected, isFalse);
    });

    test('can connect again after a failed attempt', () async {
      var attempts = 0;
      Future<WebSocketConnection> flakyConnector(
        Uri uri, {
        Duration? pingInterval,
        Duration? connectTimeout,
      }) async {
        attempts++;
        if (attempts == 1) throw Exception('down');
        return fake;
      }

      final flaky = CChainWebSocketClient(
        network: NetworkConfig.fuji,
        connector: flakyConnector,
      );
      await expectLater(flaky.connect(), throwsA(isA<AvalancheException>()));
      await flaky.connect();
      expect(flaky.isConnected, isTrue);
    });

    test('close() closes the transport', () async {
      await client.connect();
      await client.close();
      expect(fake.closed, isTrue);
      expect(client.isConnected, isFalse);
    });

    test('close() does nothing when not connected', () async {
      await client.close();
      expect(fake.closed, isFalse);
      expect(client.isConnected, isFalse);
    });

    test('subscribing before connect() reports an error and completes',
        () async {
      final heads = _Collected<NewHead>(client.newHeads());
      await pump();
      expect(heads.errors.length, equals(1));
      expect(heads.errors.single, isA<AvalancheException>());
      expect(heads.done, isTrue);
      expect(fake.sent, isEmpty);
    });
  });

  // ---- Subscription requests ----

  group('CChainWebSocketClient - subscription requests', () {
    setUp(() async {
      await client.connect();
    });

    test('is lazy: nothing is sent until the stream is listened to', () async {
      final stream = client.newHeads();
      await pump();
      expect(fake.sent, isEmpty);
      _Collected<NewHead>(stream);
      await pump();
      expect(fake.sent.length, equals(1));
    });

    test('newHeads sends eth_subscribe with ["newHeads"]', () async {
      _Collected<NewHead>(client.newHeads());
      await pump();
      final request = fake.request(0);
      expect(request['jsonrpc'], equals('2.0'));
      expect(request['id'], equals(1));
      expect(request['method'], equals('eth_subscribe'));
      expect(request['params'], equals(<Object?>['newHeads']));
    });

    test('logs sends the address and topics filter, keeping null wildcards',
        () async {
      _Collected<EvmLog>(
        client.logs(
          address: ERC20Constants.usdcFuji,
          topics: <String?>[
            ERC20Constants.transferEventTopic,
            null,
            receiverTopic,
          ],
        ),
      );
      await pump();
      expect(
        fake.request(0)['params'],
        equals(<Object?>[
          'logs',
          <String, Object?>{
            'address': ERC20Constants.usdcFuji,
            'topics': <Object?>[
              ERC20Constants.transferEventTopic,
              null,
              receiverTopic,
            ],
          },
        ]),
      );
    });

    test('logs without a filter sends only ["logs"]', () async {
      _Collected<EvmLog>(client.logs());
      await pump();
      expect(fake.request(0)['params'], equals(<Object?>['logs']));
    });

    test('newAcceptedTransactions sends fullTx true', () async {
      _Collected<AcceptedTransaction>(client.newAcceptedTransactions());
      await pump();
      expect(
        fake.request(0)['params'],
        equals(<Object?>['newAcceptedTransactions', true]),
      );
    });

    test('newAcceptedTransactionHashes sends fullTx false', () async {
      _Collected<String>(client.newAcceptedTransactionHashes());
      await pump();
      expect(
        fake.request(0)['params'],
        equals(<Object?>['newAcceptedTransactions', false]),
      );
    });

    test('request ids increase with every request', () async {
      _Collected<NewHead>(client.newHeads());
      _Collected<EvmLog>(client.logs());
      await pump();
      expect(fake.sent.length, equals(2));
      expect(fake.request(0)['id'], equals(1));
      expect(fake.request(1)['id'], equals(2));
    });
  });

  // ---- Delivery ----

  group('CChainWebSocketClient - delivery', () {
    setUp(() async {
      await client.connect();
    });

    test('newHeads delivers parsed NewHead objects', () async {
      final heads = _Collected<NewHead>(client.newHeads());
      await pump();
      fake.respond(1, headsId);
      await pump();
      fake.notify(headsId, headJson());
      await pump();
      expect(heads.events.length, equals(1));
      expect(heads.events.single.number, equals(0x3a74ab7));
      expect(heads.events.single.baseFeePerGas, equals(BigInt.from(10)));
    });

    test('logs delivers parsed EvmLog objects', () async {
      final logs = _Collected<EvmLog>(
        client.logs(address: ERC20Constants.usdcFuji),
      );
      await pump();
      fake.respond(1, logsId);
      await pump();
      fake.notify(logsId, logJson());
      await pump();
      final log = logs.events.single;
      expect(log.topic0, equals(ERC20Constants.transferEventTopic));
      expect(log.removed, isFalse);
      expect(log.blockNumber, equals(0x3a74aba));
      expect(
        BigInt.parse(log.data.substring(2), radix: 16),
        equals(BigInt.from(1000000)),
      );
    });

    test('newAcceptedTransactions delivers a contract creation (to is null)',
        () async {
      final txs = _Collected<AcceptedTransaction>(
        client.newAcceptedTransactions(),
      );
      await pump();
      fake.respond(1, acceptedId);
      await pump();
      fake.notify(acceptedId, creationJson());
      await pump();
      final tx = txs.events.single;
      expect(tx.isContractCreation, isTrue);
      expect(tx.type, equals(0));
      expect(tx.blockNumber, equals(0x3a74ab7));
    });

    test('newAcceptedTransactionHashes delivers the hash string', () async {
      final hashes = _Collected<String>(client.newAcceptedTransactionHashes());
      await pump();
      fake.respond(1, acceptedId);
      await pump();
      fake.notify(acceptedId, acceptedHash);
      await pump();
      expect(hashes.events, equals(<String>[acceptedHash]));
    });

    test('a notification right behind the response is not lost', () async {
      final heads = _Collected<NewHead>(client.newHeads());
      await pump();
      fake
        ..respond(1, headsId)
        ..notify(headsId, headJson());
      await pump();
      expect(heads.events.length, equals(1));
    });

    test('responses that arrive out of order reach the right stream', () async {
      final heads = _Collected<NewHead>(client.newHeads());
      final logs = _Collected<EvmLog>(client.logs());
      await pump();
      // The node answered the logs request (id 2) before newHeads (id 1).
      fake
        ..respond(2, logsId)
        ..respond(1, headsId);
      await pump();
      fake
        ..notify(headsId, headJson())
        ..notify(logsId, logJson());
      await pump();
      expect(heads.events.length, equals(1));
      expect(logs.events.length, equals(1));
      expect(heads.errors, isEmpty);
      expect(logs.errors, isEmpty);
    });

    test('notifications are routed by subscription id', () async {
      final first = _Collected<NewHead>(client.newHeads());
      final second = _Collected<NewHead>(client.newHeads());
      await pump();
      fake
        ..respond(1, '0xaaa')
        ..respond(2, '0xbbb');
      await pump();
      fake.notify('0xaaa', headJson());
      await pump();
      expect(first.events.length, equals(1));
      expect(second.events, isEmpty);
    });

    test('a notification for an unknown subscription is ignored', () async {
      final heads = _Collected<NewHead>(client.newHeads());
      await pump();
      fake.respond(1, headsId);
      await pump();
      fake.notify('0xdead', headJson());
      await pump();
      expect(heads.events, isEmpty);
      expect(heads.errors, isEmpty);
    });
  });

  // ---- Cancellation ----

  group('CChainWebSocketClient - cancellation', () {
    setUp(() async {
      await client.connect();
    });

    test('cancelling sends eth_unsubscribe with the subscription id', () async {
      final heads = _Collected<NewHead>(client.newHeads());
      await pump();
      fake.respond(1, headsId);
      await pump();

      final cancelled = heads.subscription.cancel();
      await pump();
      expect(fake.sent.length, equals(2));
      final unsubscribe = fake.request(1);
      expect(unsubscribe['method'], equals('eth_unsubscribe'));
      expect(unsubscribe['params'], equals(<Object?>[headsId]));

      // cancel() completes once the node acknowledges the unsubscribe.
      fake.respond(2, true);
      await cancelled;
    });

    test('cancelling before the node confirms unsubscribes afterwards',
        () async {
      final heads = _Collected<NewHead>(client.newHeads());
      await pump();
      await heads.subscription.cancel();

      fake.respond(1, headsId);
      await pump();
      expect(fake.sent.length, equals(2));
      final unsubscribe = fake.request(1);
      expect(unsubscribe['method'], equals('eth_unsubscribe'));
      expect(unsubscribe['params'], equals(<Object?>[headsId]));
    });
  });

  // ---- Errors ----

  group('CChainWebSocketClient - errors', () {
    setUp(() async {
      await client.connect();
    });

    test('a rejected eth_subscribe ends the stream with an error', () async {
      final heads = _Collected<NewHead>(client.newHeads());
      await pump();
      fake.respondError(
        1,
        -32601,
        'the method eth_subscribe does not exist/is not available',
      );
      await pump();
      expect(heads.errors.length, equals(1));
      expect(heads.errors.single, isA<AvalancheException>());
      expect(heads.done, isTrue);
    });

    test('a malformed payload is an error event and the stream stays active',
        () async {
      final heads = _Collected<NewHead>(client.newHeads());
      await pump();
      fake.respond(1, headsId);
      await pump();

      fake.notify(headsId, <String, Object?>{});
      await pump();
      expect(heads.errors.length, equals(1));
      expect(heads.errors.single, isA<TypeError>());
      expect(heads.done, isFalse);

      fake.notify(headsId, headJson());
      await pump();
      expect(heads.events.length, equals(1));
    });

    test('a frame that is not JSON is ignored', () async {
      final heads = _Collected<NewHead>(client.newHeads());
      await pump();
      fake.respond(1, headsId);
      await pump();

      fake.receiveRaw('this is not json');
      await pump();
      fake.notify(headsId, headJson());
      await pump();
      expect(heads.errors, isEmpty);
      expect(heads.events.length, equals(1));
    });

    test('a JSON frame that is not an object is ignored', () async {
      final heads = _Collected<NewHead>(client.newHeads());
      await pump();
      fake.respond(1, headsId);
      await pump();

      fake.receiveRaw('[1, 2, 3]');
      await pump();
      fake.notify(headsId, headJson());
      await pump();
      expect(heads.errors, isEmpty);
      expect(heads.events.length, equals(1));
    });
  });

  // ---- Connection loss ----

  group('CChainWebSocketClient - connection loss', () {
    setUp(() async {
      await client.connect();
    });

    test('the server closing the connection ends every stream with an error',
        () async {
      final heads = _Collected<NewHead>(client.newHeads());
      final logs = _Collected<EvmLog>(client.logs());
      await pump();
      fake
        ..respond(1, headsId)
        ..respond(2, logsId);
      await pump();

      fake.serverClose(code: 1006, reason: 'gone');
      await pump();

      expect(heads.errors.length, equals(1));
      expect(heads.errors.single, isA<AvalancheException>());
      expect(heads.done, isTrue);
      expect(logs.errors.length, equals(1));
      expect(logs.done, isTrue);
      expect(client.isConnected, isFalse);
    });

    test('a transport error ends the streams with an AvalancheException',
        () async {
      final heads = _Collected<NewHead>(client.newHeads());
      await pump();
      fake.respond(1, headsId);
      await pump();

      fake.fail(Exception('boom'));
      await pump();

      expect(heads.errors.length, equals(1));
      expect(heads.errors.single, isA<AvalancheException>());
      expect(heads.done, isTrue);
      expect(client.isConnected, isFalse);
    });

    test(
        'a request still waiting for its response fails when the connection '
        'is lost', () async {
      final heads = _Collected<NewHead>(client.newHeads());
      await pump();

      fake.serverClose(code: 1006);
      await pump();

      expect(heads.errors.length, equals(1));
      expect(heads.errors.single, isA<AvalancheException>());
      expect(heads.done, isTrue);
    });

    test('close() completes the streams without an error', () async {
      final heads = _Collected<NewHead>(client.newHeads());
      final logs = _Collected<EvmLog>(client.logs());
      await pump();
      fake
        ..respond(1, headsId)
        ..respond(2, logsId);
      await pump();

      await client.close();
      await pump();

      expect(heads.errors, isEmpty);
      expect(heads.done, isTrue);
      expect(logs.errors, isEmpty);
      expect(logs.done, isTrue);
      expect(client.isConnected, isFalse);
      expect(fake.closed, isTrue);
    });

    test('the client can connect again after close()', () async {
      final first = _FakeConnection();
      final second = _FakeConnection();
      final connections = <_FakeConnection>[first, second];
      var next = 0;
      Future<WebSocketConnection> sequenceConnector(
        Uri uri, {
        Duration? pingInterval,
        Duration? connectTimeout,
      }) async =>
          connections[next++];

      final reconnecting = CChainWebSocketClient(
        network: NetworkConfig.fuji,
        connector: sequenceConnector,
      );
      await reconnecting.connect();
      await reconnecting.close();
      expect(first.closed, isTrue);

      await reconnecting.connect();
      expect(reconnecting.isConnected, isTrue);

      _Collected<NewHead>(reconnecting.newHeads());
      await pump();
      expect(second.sent.length, equals(1));
      expect(first.sent, isEmpty);
    });
  });
}
