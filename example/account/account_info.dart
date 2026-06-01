import 'package:hiero_sdk_dart/hiero_sdk_dart.dart';

/// Example: Account Info.
///
/// This example demonstrates how to manually construct an [AccountInfo] instance
/// and print its string representation.
Future<void> main() async {
  // Construct a complete AccountInfo instance manually (no network calls).
  final info = await buildMockAccountInfo();

  // Pretty-print key AccountInfo fields.
  printAccountInfo(info);
}

/// Create a mock [AccountId].
AccountId createMockAccountId() {
  return AccountId.fromString("0.0.1234");
}

/// Generate a random ED25519 public key for demonstration.
Future<PublicKey> createMockPublicKey() async {
  final privateKey = await PrivateKey.generateEd25519();
  return await privateKey.publicKey();
}

/// Return a mock account balance.
Hbar createMockBalance() {
  return Hbar(100);
}

/// Return a sample expiration timestamp (arbitrary future date).
TimeStamp createMockExpirationTime() {
  return TimeStamp(1736539200, 100);
}

/// Return a 90-day auto-renew period.
Duration createMockAutoRenewPeriod() {
  return Duration(7776000);
}

/// Construct a complete [AccountInfo] instance manually (no network calls).
Future<AccountInfo> buildMockAccountInfo() async {
  final info = AccountInfo();
  info.accountId = createMockAccountId();
  info.key = await createMockPublicKey();
  info.balance = createMockBalance();
  info.expirationTime = createMockExpirationTime();
  info.autoRenewPeriod = createMockAutoRenewPeriod();
  info.accountMemo = "Mock Account for Example";
  return info;
}

/// Pretty-print key [AccountInfo] fields.
void printAccountInfo(AccountInfo info) {
  print("📜 AccountInfo String Representation:");
  print(info);
}
