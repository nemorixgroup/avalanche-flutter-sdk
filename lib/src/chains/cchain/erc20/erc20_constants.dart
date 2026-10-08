// ---- ERC20Constants ----

/// Constants for ERC-20 token interactions on Avalanche C-Chain.
///
/// Function selectors are the first 4 bytes of keccak256 of the
/// function signature. Verified against the ERC-20 standard.
///
/// Sources:
/// - https://eips.ethereum.org/EIPS/eip-20
/// - https://developers.circle.com/stablecoins/usdc-contract-addresses
class ERC20Constants {
  ERC20Constants._();

  // ---- Function selectors ----
  // Computed as: keccak256("functionName(type1,type2,...)")[0:4]

  /// `transfer(address,uint256)` -> 0xa9059cbb
  static const List<int> selectorTransfer = [0xa9, 0x05, 0x9c, 0xbb];

  /// `balanceOf(address)` -> 0x70a08231
  static const List<int> selectorBalanceOf = [0x70, 0xa0, 0x82, 0x31];

  /// `approve(address,uint256)` -> 0x095ea7b3
  static const List<int> selectorApprove = [0x09, 0x5e, 0xa7, 0xb3];

  /// `allowance(address,address)` -> 0xdd62ed3e
  static const List<int> selectorAllowance = [0xdd, 0x62, 0xed, 0x3e];

  /// `transferFrom(address,address,uint256)` -> 0x23b872dd
  static const List<int> selectorTransferFrom = [0x23, 0xb8, 0x72, 0xdd];

  /// `decimals()` -> 0x313ce567
  static const List<int> selectorDecimals = [0x31, 0x3c, 0xe5, 0x67];

  /// `symbol()` -> 0x95d89b41
  static const List<int> selectorSymbol = [0x95, 0xd8, 0x9b, 0x41];

  // ---- USDC contract addresses (Circle official) ----
  // Source: https://developers.circle.com/stablecoins/usdc-contract-addresses

  /// USDC on Avalanche C-Chain Mainnet (chainId: 43114).
  static const String usdcMainnet =
      '0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E';

  /// USDC on Avalanche Fuji Testnet (chainId: 43113).
  /// Note: testnet tokens have no financial value.
  static const String usdcFuji = '0x5425890298aed601595a70AB815c96711a31Bc65';

  // ---- USDT contract addresses ----
  // Source: https://build.avax.network/academy/blockchain/x402-payment-infrastructure

  /// USDT on Avalanche C-Chain Mainnet (chainId: 43114).
  static const String usdtMainnet =
      '0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7';
}
