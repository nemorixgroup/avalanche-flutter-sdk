// ignore_for_file: cancel_subscriptions, lines_longer_than_80_chars

import 'dart:async';
import 'dart:convert';

import 'package:avalanche_flutter_sdk/src/chains/cchain/erc20/erc20_constants.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/websocket/cchain_websocket_client.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/websocket/models/erc20_transfer_event.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/websocket/websocket_connection.dart';
import 'package:avalanche_flutter_sdk/src/client/network_config.dart';
import 'package:avalanche_flutter_sdk/src/exceptions/avalanche_exception.dart';
import 'package:flutter_test/flutter_test.dart';

// Subscription id returned by the Fuji node for the logs subscription in the
// smoke test.
const logsId = '0x550d00a4a16638e8f321ad841a7ed87c';

const receiver = '0x0fEB475783E004621b9463Aae30F33665485FafA';

/// The recipient as a 32-byte topic: lowercase and left-padded with zeros.
final String receiverTopic =
    '0x${'0' * 24}0feb475783e004621b9463aae30f33665485fafa';

String amountData(String hex) => '0x${hex.padLeft(64, '0')}';

String addressTopic(String address40) => '0x${'0' * 24}$address40';

// The live 1 USDC Transfer captured on Fuji (block 0x3a74aba).
Map<String, dynamic> liveLog() => <String, dynamic>{
      'address': '0x5425890298aed601595a70ab815c96711a31bc65',
      'topics': <String>[
        ERC20Constants.transferEventTopic,
        addressTopic('e9d70ee1dfced40152ea3f030d0a3918f2ee81a8'),
        addressTopic('0feb475783e004621b9463aae30f33665485fafa'),
      ],
      'data': amountData('f4240'),
      'blockNumber': '0x3a74aba',
      'transactionHash':
          '0xb72785e8b1d08e94a5a45c72043f64e6d5e12f7a03ec7335f7832cead080bc2a',
      'transactionIndex': '0x0',
      'blockHash':
          '0xf6e514178ae31683fceda8a065b118f67c1bdfd37fb025a921f9034bcd1310a6',
      'logIndex': '0x0',
      'removed': false,
    };

Future<void> pump() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
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

  void respond(int id, Object? result) => _incoming.add(
        jsonEncode(<String, Object?>{
          'jsonrpc': '2.0',
          'id': id,
          'result': result,
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

  Future<WebSocketConnection> connector(
    Uri uri, {
    Duration? pingInterval,
    Duration? connectTimeout,
  }) async =>
      fake;

  setUp(() async {
    fake = _FakeConnection();
    client = CChainWebSocketClient(
      network: NetworkConfig.fuji,
      connector: connector,
    );
    await client.connect();
  });

  group('watchIncomingErc20Transfers - request', () {
    test('subscribes to the token logs filtered by the recipient', () async {
      _Collected<Erc20TransferEvent>(
        client.watchIncomingErc20Transfers(
          tokenAddress: ERC20Constants.usdcFuji,
          to: receiver,
        ),
      );
      await pump();
      final request = fake.request(0);
      expect(request['method'], equals('eth_subscribe'));
      expect(
        request['params'],
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

    test('adds the 0x prefix and lowercases the recipient topic', () async {
      _Collected<Erc20TransferEvent>(
        client.watchIncomingErc20Transfers(
          tokenAddress: '5425890298aed601595a70AB815c96711a31Bc65',
          to: '0FEB475783E004621B9463AAE30F33665485FAFA',
        ),
      );
      await pump();
      final params = fake.request(0)['params'] as List<dynamic>;
      final filter = params[1] as Map<String, dynamic>;
      expect(filter['address'], equals(ERC20Constants.usdcFuji));
      expect((filter['topics'] as List<dynamic>)[2], equals(receiverTopic));
    });

    test('is lazy: nothing is sent until the stream is listened to', () async {
      final stream = client.watchIncomingErc20Transfers(
        tokenAddress: ERC20Constants.usdcFuji,
        to: receiver,
      );
      await pump();
      expect(fake.sent, isEmpty);
      _Collected<Erc20TransferEvent>(stream);
      await pump();
      expect(fake.sent.length, equals(1));
    });
  });

  group('watchIncomingErc20Transfers - validation', () {
    test('throws an ArgumentError for an invalid token address', () async {
      expect(
        () => client.watchIncomingErc20Transfers(
          tokenAddress: '0x1234',
          to: receiver,
        ),
        throwsArgumentError,
      );
      await pump();
      expect(fake.sent, isEmpty);
    });

    test('throws an ArgumentError for a recipient of the wrong length', () {
      expect(
        () => client.watchIncomingErc20Transfers(
          tokenAddress: ERC20Constants.usdcFuji,
          to: '0x1234',
        ),
        throwsArgumentError,
      );
    });

    test('throws an ArgumentError for a recipient with non-hex characters', () {
      expect(
        () => client.watchIncomingErc20Transfers(
          tokenAddress: ERC20Constants.usdcFuji,
          to: '0x${'zz' * 20}',
        ),
        throwsArgumentError,
      );
    });
  });

  group('watchIncomingErc20Transfers - delivery', () {
    test('delivers the live log as an Erc20TransferEvent', () async {
      final transfers = _Collected<Erc20TransferEvent>(
        client.watchIncomingErc20Transfers(
          tokenAddress: ERC20Constants.usdcFuji,
          to: receiver,
        ),
      );
      await pump();
      fake.respond(1, logsId);
      await pump();
      fake.notify(logsId, liveLog());
      await pump();

      final event = transfers.events.single;
      expect(event.token, equals('0x5425890298aed601595a70ab815c96711a31bc65'));
      expect(event.to, equals('0x0feb475783e004621b9463aae30f33665485fafa'));
      expect(event.value, equals(BigInt.from(1000000)));
      expect(event.valueInTokens(6), closeTo(1.0, 1e-9));
      expect(event.removed, isFalse);
    });

    test(
        'a log that is not an ERC-20 transfer is an error and the stream '
        'stays active', () async {
      final transfers = _Collected<Erc20TransferEvent>(
        client.watchIncomingErc20Transfers(
          tokenAddress: ERC20Constants.usdcFuji,
          to: receiver,
        ),
      );
      await pump();
      fake.respond(1, logsId);
      await pump();

      // An ERC-721 style Transfer: the same topic 0 with a fourth topic.
      final nft = liveLog();
      nft['topics'] = <String>[
        ...(nft['topics'] as List<dynamic>).cast<String>(),
        '0x${'0' * 63}1',
      ];
      nft['data'] = '0x';
      fake.notify(logsId, nft);
      await pump();
      expect(transfers.errors.length, equals(1));
      expect(transfers.errors.single, isA<FormatException>());
      expect(transfers.done, isFalse);

      fake.notify(logsId, liveLog());
      await pump();
      expect(transfers.events.length, equals(1));
    });

    test('delivers a reorganized transfer with removed: true', () async {
      final transfers = _Collected<Erc20TransferEvent>(
        client.watchIncomingErc20Transfers(
          tokenAddress: ERC20Constants.usdcFuji,
          to: receiver,
        ),
      );
      await pump();
      fake.respond(1, logsId);
      await pump();
      fake.notify(logsId, liveLog()..['removed'] = true);
      await pump();
      expect(transfers.events.single.removed, isTrue);
    });
  });

  group('watchIncomingErc20Transfers - lifecycle', () {
    test('cancelling sends eth_unsubscribe with the subscription id', () async {
      final transfers = _Collected<Erc20TransferEvent>(
        client.watchIncomingErc20Transfers(
          tokenAddress: ERC20Constants.usdcFuji,
          to: receiver,
        ),
      );
      await pump();
      fake.respond(1, logsId);
      await pump();

      final cancelled = transfers.subscription.cancel();
      await pump();
      final unsubscribe = fake.request(1);
      expect(unsubscribe['method'], equals('eth_unsubscribe'));
      expect(unsubscribe['params'], equals(<Object?>[logsId]));

      fake.respond(2, true);
      await cancelled;
    });

    test('a lost connection ends the stream with an AvalancheException',
        () async {
      final transfers = _Collected<Erc20TransferEvent>(
        client.watchIncomingErc20Transfers(
          tokenAddress: ERC20Constants.usdcFuji,
          to: receiver,
        ),
      );
      await pump();
      fake.respond(1, logsId);
      await pump();

      fake.serverClose();
      await pump();
      expect(transfers.errors.length, equals(1));
      expect(transfers.errors.single, isA<AvalancheException>());
      expect(transfers.done, isTrue);
    });
  });
}
