// ---- Hex quantities ----

/// Parses an Ethereum JSON-RPC hex quantity (for example `"0x3a74ab7"`)
/// into a [BigInt].
///
/// The `0x` prefix is optional. An empty string or a bare `0x` is zero.
/// Throws a [FormatException] if the digits are not valid hexadecimal.
BigInt hexToBigInt(String hex) {
  final clean =
      hex.startsWith('0x') || hex.startsWith('0X') ? hex.substring(2) : hex;
  if (clean.isEmpty) return BigInt.zero;
  return BigInt.parse(clean, radix: 16);
}

/// Parses a hex quantity into an [int].
///
/// Use it only for values that are guaranteed to fit in an `int`, such as
/// block numbers, indexes and nonces. Use [hexToBigInt] for balances, fees
/// and gas.
int hexToInt(String hex) => hexToBigInt(hex).toInt();
