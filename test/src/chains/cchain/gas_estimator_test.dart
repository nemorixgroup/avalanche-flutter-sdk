import 'package:avalanche_flutter_sdk/src/chains/cchain/cchain_client.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/gas_estimator.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/models/gas_price_option.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/models/gas_price_options.dart';
import 'package:avalanche_flutter_sdk/src/client/network_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'gas_estimator_test.mocks.dart';

@GenerateMocks([CChainClient])
void main() {
  late MockCChainClient mockClient;
  late GasEstimator estimator;

  // Official example from build.avax.network/docs/rpcs/c-chain
  final testOptions = GasPriceOptions(
    slow: GasPriceOption(
      maxPriorityFeePerGas: BigInt.parse('25000000000'),
      maxFeePerGas: BigInt.parse('30000000000'),
    ),
    normal: GasPriceOption(
      maxPriorityFeePerGas: BigInt.parse('10000000000'),
      maxFeePerGas: BigInt.parse('20000000000'),
    ),
    fast: GasPriceOption(
      maxPriorityFeePerGas: BigInt.parse('5000000000'),
      maxFeePerGas: BigInt.parse('15000000000'),
    ),
  );

  setUp(() {
    provideDummy(BigInt.zero);
    mockClient = MockCChainClient();
    when(mockClient.network).thenReturn(NetworkConfig.fuji);
    estimator = GasEstimator(mockClient);
  });

  // ---- GasPriceOption ----

  group('GasPriceOption', () {
    test('effectiveFee = min(maxFeePerGas, baseFee + maxPriorityFeePerGas)',
        () {
      // Per Avalanche docs: min(gasFeeCap, baseFee + gasTipCap)
      // Source: build.avax.network/docs/rpcs/other/guides/txn-fees
      final option = GasPriceOption(
        maxPriorityFeePerGas: BigInt.from(10000000000),
        maxFeePerGas: BigInt.from(20000000000),
      );
      final baseFee = BigInt.from(8000000000);

      // baseFee + tip = 8 + 10 = 18 Gwei < maxFeePerGas 20 Gwei
      // -> effective = 18 Gwei
      expect(
        option.effectiveFee(baseFee),
        equals(BigInt.from(18000000000)),
      );
    });

    test('effectiveFee is capped at maxFeePerGas when baseFee is high', () {
      final option = GasPriceOption(
        maxPriorityFeePerGas: BigInt.from(10000000000),
        maxFeePerGas: BigInt.from(20000000000),
      );
      final highBaseFee = BigInt.from(15000000000);

      // baseFee + tip = 15 + 10 = 25 Gwei > maxFeePerGas 20 Gwei
      // -> effective = 20 Gwei (capped)
      expect(
        option.effectiveFee(highBaseFee),
        equals(BigInt.from(20000000000)),
      );
    });

    test('avaxTransferGasLimit is 21000', () {
      expect(GasEstimator.avaxTransferGasLimit, equals(21000));
    });
  });

  // ---- GasEstimator.getPriceOptions ----

  group('GasEstimator.getPriceOptions', () {
    test('delegates to CChainClient.suggestPriceOptions', () async {
      when(mockClient.suggestPriceOptions())
          .thenAnswer((_) async => testOptions);

      final result = await estimator.getPriceOptions();
      expect(result.slow.maxFeePerGas, equals(testOptions.slow.maxFeePerGas));
      expect(
        result.normal.maxFeePerGas,
        equals(testOptions.normal.maxFeePerGas),
      );
      expect(result.fast.maxFeePerGas, equals(testOptions.fast.maxFeePerGas));
    });
  });

  // ---- GasEstimator.getOption ----

  group('GasEstimator.getOption', () {
    setUp(() {
      when(mockClient.suggestPriceOptions())
          .thenAnswer((_) async => testOptions);
    });

    test('returns slow option for GasSpeed.slow', () async {
      final option = await estimator.getOption(GasSpeed.slow);
      expect(option.maxFeePerGas, equals(testOptions.slow.maxFeePerGas));
    });

    test('returns normal option for GasSpeed.normal', () async {
      final option = await estimator.getOption(GasSpeed.normal);
      expect(option.maxFeePerGas, equals(testOptions.normal.maxFeePerGas));
    });

    test('returns fast option for GasSpeed.fast', () async {
      final option = await estimator.getOption(GasSpeed.fast);
      expect(option.maxFeePerGas, equals(testOptions.fast.maxFeePerGas));
    });
  });

  // ---- GasEstimator.getBaseFee ----

  group('GasEstimator.getBaseFee', () {
    test('delegates to CChainClient.getBaseFee', () async {
      final baseFee = BigInt.parse('225000000000');
      when(mockClient.getBaseFee()).thenAnswer((_) async => baseFee);

      final result = await estimator.getBaseFee();
      expect(result, equals(baseFee));
    });
  });

  // ---- GasEstimator.estimateTransferFee ----

  group('GasEstimator.estimateTransferFee', () {
    test('returns maxFeePerGas * 21000 for normal speed', () async {
      when(mockClient.suggestPriceOptions())
          .thenAnswer((_) async => testOptions);

      final fee = await estimator.estimateTransferFee();
      // normal.maxFeePerGas = 20 Gwei * 21000 = 420,000 Gwei
      expect(
        fee,
        equals(
          testOptions.normal.maxFeePerGas *
              BigInt.from(GasEstimator.avaxTransferGasLimit),
        ),
      );
    });

    test('uses fast option when GasSpeed.fast specified', () async {
      when(mockClient.suggestPriceOptions())
          .thenAnswer((_) async => testOptions);

      final fee = await estimator.estimateTransferFee(speed: GasSpeed.fast);
      expect(
        fee,
        equals(
          testOptions.fast.maxFeePerGas *
              BigInt.from(GasEstimator.avaxTransferGasLimit),
        ),
      );
    });
  });
}
