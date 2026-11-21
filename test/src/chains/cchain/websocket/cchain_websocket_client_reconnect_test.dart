// ignore_for_file: cancel_subscriptions, lines_longer_than_80_chars

import 'dart:async';
import 'dart:convert';

import 'package:avalanche_flutter_sdk/src/chains/cchain/erc20/erc20_constants.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/websocket/cchain_websocket_client.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/websocket/models/evm_log.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/websocket/models/new_head.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/websocket/reconnect_policy.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/websocket/websocket_connection.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/websocket/websocket_status.dart';
import 'package:avalanche_flutter_sdk/src/client/network_config.dart';
import 'package:avalanche_flutter_sdk/src/exceptions/avalanche_exception.dart';
import 'package:flutter_test/flutter_test.dart';

// ---- Fixtures captured from live Fuji frames ----

final String receiverTopic =
    '0x${'0' * 24}0feb475783e004621b9463aae30f33665485fafa';

// The live 1 USDC Transfer (block 0x3a74aba).
Map<String, dynamic> liveLog() => <String, dynamic>{
      'address': '0x5425890298aed601595a70ab815c96711a31bc65',
      'topics': <String>[
        ERC20Constants.transferEventTopic,
        '0x${'0' * 24}e9d70ee1dfced40152ea3f030d0a3918f2ee81a8',
        receiverTopic,
      ],
      'data': '0x${'f4240'.padLeft(64, '0')}',
      'blockNumber': '0x3a74aba',
      'transactionHash':
          '0xb72785e8b1d08e94a5a45c72043f64e6d5e12f7a03ec7335f7832cead080bc2a',
      'transactionIndex': '0x0',
      'blockHash':
          '0xf6e514178ae31683fceda8a065b118f67c1bdfd37fb025a921f9034bcd1310a6',
      'logIndex': '0x0',
      'removed': false,
    };

// Subset of the live newHeads result for block 0x3a74ab7.
Map<String, dynamic> headJson() => <String, dynamic>{
      'parentHash':
          '0x2758ee95e64cdc0002b14bc259a82be9a03fa140fb5f806a1746dc5001b4a1ed',
      'miner': '0x0100000000000000000000000000000000000000',
      'number': '0x3a74ab7',
      'gasLimit': '0x1e84800',
      'gasUsed': '0x16e360',
      'timestamp': '0x6afdec24',
      'baseFeePerGas': '0xa',
      'hash':
          '0x810731966bd5b550c8737c0cb1ede617c591ab93e5bac48d84a84d605f5f1232',
    };

// ---- Policies (real timers, tiny delays) ----

const ReconnectPolicy fastPolicy = ReconnectPolicy(
  initialDelay: Duration(milliseconds: 1),
  maxDelay: Duration(milliseconds: 4),
);

const ReconnectPolicy mediumPolicy = ReconnectPolicy(
  initialDelay: Duration(milliseconds: 50),
  maxDelay: Duration(milliseconds: 50),
);

const ReconnectPolicy slowPolicy = ReconnectPolicy(
  initialDelay: Duration(milliseconds: 100),
  maxDelay: Duration(milliseconds: 100),
);

// ---- Test helpers ----

/// Lets pending microtasks and zero-delay timers run.
Future<void> pump() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Polls [condition] until it is true, failing after [timeout].
Future<void> eventually(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('The condition was not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

/// A scripted transport: the test plays the role of the node.
class _FakeConnection implements WebSocketConnection {
  final StreamController<String> _incoming = StreamController<String>();
  final List<String> sent = <String>[];

  @override
  Stream<String> get messages => _incoming.stream;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  void send(String message) => sent.add(message);

  @override
  Future<void> close() async {
    if (!_incoming.isClosed) unawaited(_incoming.close());
  }

  Map<String, dynamic> request(int index) =>
      jsonDecode(sent[index]) as Map<String, dynamic>;

  int requestId(int index) => request(index)['id']! as int;

  void respond(int id, Object? result) => _incoming.add(
        jsonEncode(<String, Object?>{
          'jsonrpc': '2.0',
          'id': id,
          'result': result,
        }),
      );

  void respondError(int id, int code, String message) => _incoming.add(
        jsonEncode(<String, Object?>{
          'jsonrpc': '2.0',
          'id': id,
          'error': <String, Object?>{'code': code, 'message': message},
        }),
      );

  void notify(String subscription, Object? result) => _incoming.add(
        jsonEncode(<String, Object?>{
          'jsonrpc': '2.0',
          'method': 'eth_subscription',
          'params': <String, Object?>{
            'subscription': subscription,
            'result': result,
          },
        }),
      );

  void serverClose() => unawaited(_incoming.close());
}

/// Hands out the scripted steps, one per connection attempt.
///
/// A step is a [WebSocketConnection] to return or an [Exception] to throw.
/// The last step repeats if the client asks for more attempts.
class _Script {
  _Script(this.steps);

  final List<Object> steps;
  final List<DateTime> times = <DateTime>[];

  int get calls => times.length;

  Future<WebSocketConnection> connector(
    Uri uri, {
    Duration? pingInterval,
    Duration? connectTimeout,
  }) async {
    final index = times.length;
    times.add(DateTime.now());
    final step = steps[index < steps.length ? index : steps.length - 1];
    if (step is Exception) throw step;
    return step as WebSocketConnection;
  }
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

CChainWebSocketClient _makeClient(_Script script, {ReconnectPolicy? policy}) =>
    CChainWebSocketClient(
      network: NetworkConfig.fuji,
      reconnectPolicy: policy,
      connector: script.connector,
    );

/// Collects every status the client reports.
List<WebSocketStatus> track(CChainWebSocketClient client) {
  final statuses = <WebSocketStatus>[];
  client.status.listen(statuses.add);
  return statuses;
}

int count(List<WebSocketStatus> statuses, WebSocketStatus value) =>
    statuses.where((s) => s == value).length;

void main() {
  const connected = WebSocketStatus.connected;
  const reconnecting = WebSocketStatus.reconnecting;
  const reconnected = WebSocketStatus.reconnected;
  const disconnected = WebSocketStatus.disconnected;

  // ---- ReconnectPolicy ----

  group('ReconnectPolicy', () {
    test('defaults: 1 s initial delay, 30 s cap, unlimited attempts', () {
      const policy = ReconnectPolicy();
      expect(policy.initialDelay, equals(const Duration(seconds: 1)));
      expect(policy.maxDelay, equals(const Duration(seconds: 30)));
      expect(policy.maxAttempts, isNull);
    });

    test('the default delay doubles until it reaches the cap', () {
      const policy = ReconnectPolicy();
      final seconds = <int>[
        for (var attempt = 1; attempt <= 7; attempt++)
          policy.delayForAttempt(attempt).inSeconds,
      ];
      expect(seconds, equals(<int>[1, 2, 4, 8, 16, 30, 30]));
    });

    test('a custom policy doubles from its own initial delay', () {
      const policy = ReconnectPolicy(
        initialDelay: Duration(milliseconds: 100),
        maxDelay: Duration(seconds: 1),
      );
      final millis = <int>[
        for (var attempt = 1; attempt <= 5; attempt++)
          policy.delayForAttempt(attempt).inMilliseconds,
      ];
      expect(millis, equals(<int>[100, 200, 400, 800, 1000]));
    });

    test('an initial delay above the cap is capped from the first attempt', () {
      const policy = ReconnectPolicy(
        initialDelay: Duration(seconds: 10),
        maxDelay: Duration(seconds: 5),
      );
      expect(policy.delayForAttempt(1), equals(const Duration(seconds: 5)));
      expect(policy.delayForAttempt(2), equals(const Duration(seconds: 5)));
    });

    test('a very large attempt number returns the cap', () {
      const policy = ReconnectPolicy();
      expect(
        policy.delayForAttempt(1000),
        equals(const Duration(seconds: 30)),
      );
    });
  });

  // ---- Status ----

  group('CChainWebSocketClient - status', () {
    test('connect() reports connected', () async {
      final client = _makeClient(_Script(<Object>[_FakeConnection()]));
      final statuses = track(client);
      await client.connect();
      await pump();
      expect(statuses, equals(<WebSocketStatus>[connected]));
    });

    test('connecting twice reports connected once', () async {
      final client = _makeClient(_Script(<Object>[_FakeConnection()]));
      final statuses = track(client);
      await client.connect();
      await client.connect();
      await pump();
      expect(statuses, equals(<WebSocketStatus>[connected]));
    });

    test('losing the connection without a policy reports disconnected',
        () async {
      final first = _FakeConnection();
      final client = _makeClient(_Script(<Object>[first]));
      final statuses = track(client);
      await client.connect();

      first.serverClose();
      await pump();

      expect(statuses, equals(<WebSocketStatus>[connected, disconnected]));
      expect(client.isConnected, isFalse);
      expect(client.isReconnecting, isFalse);
    });

    test('close() reports disconnected', () async {
      final client = _makeClient(_Script(<Object>[_FakeConnection()]));
      final statuses = track(client);
      await client.connect();
      await client.close();
      await pump();
      expect(statuses, equals(<WebSocketStatus>[connected, disconnected]));
    });

    test('close() when not connected reports nothing', () async {
      final client = _makeClient(_Script(<Object>[_FakeConnection()]));
      final statuses = track(client);
      await client.close();
      await pump();
      expect(statuses, isEmpty);
    });

    test('a failed connect() reports nothing', () async {
      final client = _makeClient(_Script(<Object>[Exception('down')]));
      final statuses = track(client);
      await expectLater(client.connect(), throwsA(isA<AvalancheException>()));
      await pump();
      expect(statuses, isEmpty);
      expect(client.isConnected, isFalse);
    });

    test('status is a broadcast stream: every listener gets the events',
        () async {
      final client = _makeClient(_Script(<Object>[_FakeConnection()]));
      final first = <WebSocketStatus>[];
      final second = <WebSocketStatus>[];
      client.status.listen(first.add);
      client.status.listen(second.add);
      await client.connect();
      await pump();
      expect(first, equals(<WebSocketStatus>[connected]));
      expect(second, equals(<WebSocketStatus>[connected]));
    });
  });

  // ---- Reconnection ----

  group('CChainWebSocketClient - reconnection', () {
    test(
        'reconnects, re-subscribes with the same filter and keeps the '
        'stream open', () async {
      final first = _FakeConnection();
      final second = _FakeConnection();
      final client = _makeClient(
        _Script(<Object>[first, second]),
        policy: fastPolicy,
      );
      final statuses = track(client);
      await client.connect();

      final logs = _Collected<EvmLog>(
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
      first.respond(first.requestId(0), 'A');
      await pump();
      first.notify('A', liveLog());
      await pump();
      expect(logs.events.length, equals(1));

      first.serverClose();
      await eventually(() => second.sent.length == 1);

      // The same eth_subscribe request goes out on the new connection.
      expect(second.request(0)['method'], equals('eth_subscribe'));
      expect(second.request(0)['params'], equals(first.request(0)['params']));
      // Reconnected is only reported once the node confirms the subscription.
      expect(statuses, isNot(contains(reconnected)));
      expect(logs.errors, isEmpty);
      expect(logs.done, isFalse);

      second.respond(second.requestId(0), 'B');
      await eventually(() => statuses.contains(reconnected));
      expect(
        statuses,
        equals(<WebSocketStatus>[connected, reconnecting, reconnected]),
      );
      expect(client.isConnected, isTrue);
      expect(client.isReconnecting, isFalse);

      // The new subscription id delivers; the old one is no longer known.
      second.notify('B', liveLog());
      await pump();
      expect(logs.events.length, equals(2));
      second.notify('A', liveLog());
      await pump();
      expect(logs.events.length, equals(2));
      expect(logs.errors, isEmpty);

      await client.close();
    });

    test('retries with growing delays until it reconnects', () async {
      final first = _FakeConnection();
      final second = _FakeConnection();
      final script = _Script(
        <Object>[first, Exception('down'), Exception('down'), second],
      );
      final client = _makeClient(
        script,
        policy: const ReconnectPolicy(
          initialDelay: Duration(milliseconds: 20),
          maxDelay: Duration(milliseconds: 80),
        ),
      );
      final statuses = track(client);
      await client.connect();

      final lostAt = DateTime.now();
      first.serverClose();
      await eventually(() => statuses.contains(reconnected));

      expect(script.calls, equals(4));
      final times = script.times;
      // Delays of 20, 40 and 80 ms; only lower bounds are checked, with
      // some margin for timer rounding.
      expect(
        times[1].difference(lostAt).inMilliseconds,
        greaterThanOrEqualTo(15),
      );
      expect(
        times[2].difference(times[1]).inMilliseconds,
        greaterThanOrEqualTo(30),
      );
      expect(
        times[3].difference(times[2]).inMilliseconds,
        greaterThanOrEqualTo(60),
      );
      expect(
        statuses,
        equals(<WebSocketStatus>[connected, reconnecting, reconnected]),
      );
      expect(client.isConnected, isTrue);

      await client.close();
    });

    test('gives up after maxAttempts and ends the streams with an error',
        () async {
      final first = _FakeConnection();
      final script = _Script(<Object>[first, Exception('down')]);
      final client = _makeClient(
        script,
        policy: const ReconnectPolicy(
          initialDelay: Duration(milliseconds: 1),
          maxDelay: Duration(milliseconds: 4),
          maxAttempts: 2,
        ),
      );
      final statuses = track(client);
      await client.connect();
      final heads = _Collected<NewHead>(client.newHeads());
      await pump();
      first.respond(first.requestId(0), 'H');
      await pump();

      first.serverClose();
      await eventually(() => heads.done);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(heads.errors.length, equals(1));
      expect(heads.errors.single, isA<AvalancheException>());
      // The first connection plus exactly two failed attempts.
      expect(script.calls, equals(3));
      expect(client.isReconnecting, isFalse);
      expect(client.isConnected, isFalse);
      expect(
        statuses,
        equals(<WebSocketStatus>[connected, reconnecting, disconnected]),
      );
    });

    test('close() during a reconnection stops the retries', () async {
      final first = _FakeConnection();
      final script = _Script(<Object>[first, _FakeConnection()]);
      final client = _makeClient(script, policy: slowPolicy);
      final statuses = track(client);
      await client.connect();
      final heads = _Collected<NewHead>(client.newHeads());
      await pump();
      first.respond(first.requestId(0), 'H');
      await pump();

      first.serverClose();
      await pump();
      await client.close();
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(script.calls, equals(1));
      expect(heads.errors, isEmpty);
      expect(heads.done, isTrue);
      expect(client.isReconnecting, isFalse);
      expect(client.isConnected, isFalse);
      expect(
        statuses,
        equals(<WebSocketStatus>[connected, reconnecting, disconnected]),
      );
    });

    test('a stream cancelled while reconnecting is not re-subscribed',
        () async {
      final first = _FakeConnection();
      final second = _FakeConnection();
      final client = _makeClient(
        _Script(<Object>[first, second]),
        policy: mediumPolicy,
      );
      final statuses = track(client);
      await client.connect();
      final heads = _Collected<NewHead>(client.newHeads());
      await pump();
      first.respond(first.requestId(0), 'H');
      await pump();

      first.serverClose();
      await pump();
      await heads.subscription.cancel();

      await eventually(() => statuses.contains(reconnected));
      expect(second.sent, isEmpty);

      await client.close();
    });

    test(
        'a stream created while reconnecting is subscribed once the '
        'connection is restored', () async {
      final first = _FakeConnection();
      final second = _FakeConnection();
      final script = _Script(<Object>[first, second]);
      final client = _makeClient(script, policy: mediumPolicy);
      final statuses = track(client);
      await client.connect();

      first.serverClose();
      await pump();
      final heads = _Collected<NewHead>(client.newHeads());
      await pump();
      expect(script.calls, equals(1));

      await eventually(() => second.sent.length == 1);
      expect(second.request(0)['params'], equals(<Object?>['newHeads']));
      second.respond(second.requestId(0), 'H');
      await eventually(() => statuses.contains(reconnected));

      second.notify('H', headJson());
      await pump();
      expect(heads.events.length, equals(1));

      await client.close();
    });

    test('connect() while reconnecting throws an AvalancheException', () async {
      final first = _FakeConnection();
      final client = _makeClient(
        _Script(<Object>[first, _FakeConnection()]),
        policy: slowPolicy,
      );
      await client.connect();

      first.serverClose();
      await pump();
      expect(client.isReconnecting, isTrue);
      await expectLater(client.connect(), throwsA(isA<AvalancheException>()));

      await client.close();
    });

    test('two consecutive connection losses reconnect twice', () async {
      final first = _FakeConnection();
      final second = _FakeConnection();
      final third = _FakeConnection();
      final client = _makeClient(
        _Script(<Object>[first, second, third]),
        policy: fastPolicy,
      );
      final statuses = track(client);
      await client.connect();
      final heads = _Collected<NewHead>(client.newHeads());
      await pump();
      first.respond(first.requestId(0), 'H1');
      await pump();

      first.serverClose();
      await eventually(() => second.sent.length == 1);
      second.respond(second.requestId(0), 'H2');
      await eventually(() => count(statuses, reconnected) == 1);
      second.notify('H2', headJson());
      await pump();
      expect(heads.events.length, equals(1));

      second.serverClose();
      await eventually(() => third.sent.length == 1);
      third.respond(third.requestId(0), 'H3');
      await eventually(() => count(statuses, reconnected) == 2);
      third.notify('H3', headJson());
      await pump();

      expect(heads.events.length, equals(2));
      expect(heads.errors, isEmpty);
      expect(
        statuses,
        equals(<WebSocketStatus>[
          connected,
          reconnecting,
          reconnected,
          reconnecting,
          reconnected,
        ]),
      );

      await client.close();
    });

    test(
        'a subscription rejected after reconnecting ends its stream; the '
        'others continue', () async {
      final first = _FakeConnection();
      final second = _FakeConnection();
      final client = _makeClient(
        _Script(<Object>[first, second]),
        policy: fastPolicy,
      );
      final statuses = track(client);
      await client.connect();
      final heads = _Collected<NewHead>(client.newHeads());
      final logs = _Collected<EvmLog>(client.logs());
      await pump();
      first.respond(first.requestId(0), 'H');
      first.respond(first.requestId(1), 'L');
      await pump();

      first.serverClose();
      await eventually(() => second.sent.length == 2);
      expect(second.request(0)['params'], equals(<Object?>['newHeads']));
      expect(second.request(1)['params'], equals(<Object?>['logs']));

      second.respond(second.requestId(0), 'H2');
      second.respondError(second.requestId(1), -32000, 'denied');
      await eventually(() => statuses.contains(reconnected));

      expect(heads.errors, isEmpty);
      expect(heads.done, isFalse);
      expect(logs.errors.length, equals(1));
      expect(logs.errors.single, isA<AvalancheException>());
      expect(logs.done, isTrue);

      second.notify('H2', headJson());
      await pump();
      expect(heads.events.length, equals(1));

      await client.close();
    });

    test(
        'cancelling after a reconnection unsubscribes with the new id and '
        'does not wait for the node', () async {
      final first = _FakeConnection();
      final second = _FakeConnection();
      final client = _makeClient(
        _Script(<Object>[first, second]),
        policy: fastPolicy,
      );
      final statuses = track(client);
      await client.connect();
      final heads = _Collected<NewHead>(client.newHeads());
      await pump();
      first.respond(first.requestId(0), 'A');
      await pump();

      first.serverClose();
      await eventually(() => second.sent.length == 1);
      second.respond(second.requestId(0), 'B');
      await eventually(() => statuses.contains(reconnected));

      await heads.subscription.cancel().timeout(const Duration(seconds: 1));

      expect(second.sent.length, equals(2));
      expect(second.request(1)['method'], equals('eth_unsubscribe'));
      expect(second.request(1)['params'], equals(<Object?>['B']));

      await client.close();
    });

    test('reports reconnecting while it retries', () async {
      final first = _FakeConnection();
      final client = _makeClient(
        _Script(<Object>[first, _FakeConnection()]),
        policy: slowPolicy,
      );
      final statuses = track(client);
      await client.connect();

      first.serverClose();
      await pump();

      expect(client.isReconnecting, isTrue);
      expect(client.isConnected, isFalse);
      expect(
        statuses,
        equals(<WebSocketStatus>[connected, reconnecting]),
      );

      await client.close();
      expect(client.isReconnecting, isFalse);
    });
  });

  // ---- Cancellation ----

  group('CChainWebSocketClient - cancellation', () {
    test('cancel() completes without waiting for the node', () async {
      final first = _FakeConnection();
      final client = _makeClient(_Script(<Object>[first]));
      await client.connect();
      final heads = _Collected<NewHead>(client.newHeads());
      await pump();
      first.respond(first.requestId(0), 'H');
      await pump();

      // The node never answers the eth_unsubscribe, and cancel() still ends.
      await heads.subscription.cancel().timeout(const Duration(seconds: 1));

      expect(first.sent.length, equals(2));
      expect(first.request(1)['method'], equals('eth_unsubscribe'));
      expect(first.request(1)['params'], equals(<Object?>['H']));

      await client.close();
    });

    test('a failed eth_unsubscribe does not raise an error', () async {
      final first = _FakeConnection();
      final client = _makeClient(_Script(<Object>[first]));
      await client.connect();
      final heads = _Collected<NewHead>(client.newHeads());
      await pump();
      first.respond(first.requestId(0), 'H');
      await pump();

      await heads.subscription.cancel();
      first.respondError(first.requestId(1), -32000, 'nope');
      await pump();

      // The test would fail with an unhandled error if it leaked.
      expect(first.request(1)['method'], equals('eth_unsubscribe'));

      await client.close();
    });

    test('cancelling after the connection was lost sends nothing', () async {
      final first = _FakeConnection();
      final client = _makeClient(_Script(<Object>[first]));
      await client.connect();
      final heads = _Collected<NewHead>(client.newHeads());
      await pump();
      first.respond(first.requestId(0), 'H');
      await pump();

      first.serverClose();
      await pump();
      expect(heads.errors.length, equals(1));
      expect(heads.done, isTrue);

      await heads.subscription.cancel();
      expect(first.sent.length, equals(1));
    });

    test('cancelling one stream leaves the others running', () async {
      final first = _FakeConnection();
      final client = _makeClient(_Script(<Object>[first]));
      await client.connect();
      final one = _Collected<NewHead>(client.newHeads());
      final other = _Collected<NewHead>(client.newHeads());
      await pump();
      first.respond(first.requestId(0), 'A');
      first.respond(first.requestId(1), 'B');
      await pump();

      await one.subscription.cancel();
      expect(first.sent.length, equals(3));
      expect(first.request(2)['params'], equals(<Object?>['A']));

      first
        ..notify('B', headJson())
        ..notify('A', headJson());
      await pump();
      expect(other.events.length, equals(1));
      expect(one.events, isEmpty);

      await client.close();
    });
  });

  // ---- close() and connect() ----

  group('CChainWebSocketClient - close and connect', () {
    test('close() twice is harmless', () async {
      final client = _makeClient(_Script(<Object>[_FakeConnection()]));
      final statuses = track(client);
      await client.connect();
      await client.close();
      await client.close();
      await pump();
      expect(statuses, equals(<WebSocketStatus>[connected, disconnected]));
    });

    test('connect() works again after the policy gave up', () async {
      final first = _FakeConnection();
      final second = _FakeConnection();
      final client = _makeClient(
        _Script(<Object>[first, Exception('down'), Exception('down'), second]),
        policy: const ReconnectPolicy(
          initialDelay: Duration(milliseconds: 1),
          maxDelay: Duration(milliseconds: 4),
          maxAttempts: 2,
        ),
      );
      final statuses = track(client);
      await client.connect();

      first.serverClose();
      await eventually(() => statuses.contains(disconnected));
      expect(client.isConnected, isFalse);

      await client.connect();
      await pump();
      expect(client.isConnected, isTrue);
      expect(
        statuses,
        equals(<WebSocketStatus>[
          connected,
          reconnecting,
          disconnected,
          connected,
        ]),
      );

      await client.close();
    });
  });
}
