import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart' hide PublicKey;

// dart run tool/print_curve_order.dart
// prints the secp256k1 curve order n and n - 1 in hex
// this is used to validate the private key import boundary values
// in the private_key_test.dart file
void main() {
  final domain = ECDomainParameters('secp256k1');
  final n = domain.n;
  final hex = n.toRadixString(16);
  debugPrint('n (hex)        = $hex');
  debugPrint('n (hex length) = ${hex.length}');
  debugPrint('n - 1 (hex)    = ${(n - BigInt.one).toRadixString(16)}');
}
