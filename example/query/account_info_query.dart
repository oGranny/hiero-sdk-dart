import 'dart:io';

import 'package:hiero_sdk_dart/hiero_sdk_dart.dart';

Future<Client> setupClient() async {
  try {
    final client = await Client.fromEnv();
    print("Client set up with operator id ${client.operatorAccountId}");
    return client;
  } catch (e) {
    print("Error setting up client: $e");
    exit(1);
  }
}

Future<(AccountId, PrivateKey)> createTestAccount(
  Client client,
  PrivateKey operatorKey,
) async {
  final newAccountPrivateKey = await PrivateKey.generateEd25519();
  final newAccountPublicKey = await newAccountPrivateKey.publicKey();

  print("\nCreating test account...");
  final response = await AccountCreateTransaction()
    ..setKey(newAccountPublicKey)
    ..setInitialBalance(Hbar(10))
    ..setAccountMemo("Test account memo");
  await response.freezeWith(client);
  await response.sign(operatorKey);

  final receipt = await response.execute(client, timeout: 20);
  if ((receipt as TransactionReceipt).status.value != ResponseCode.SUCCESS) {
    throw Exception("Transaction failed with status: ${receipt.status}");
  }

  if (receipt.status.value != ResponseCode.SUCCESS) {
    final statusName = ResponseCode(receipt.status.value).name;
    print("Account creation failed with status: $statusName");
    exit(1);
  }

  final newAccountId = receipt.accountId;
  print("Test account created with ID: $newAccountId");

  return (newAccountId, newAccountPrivateKey);
}

void displayAccountInfo(AccountInfo info) {
  print("");
  print("==============================");
  print("Account Information:");
  print("Account ID: ${info.accountId}");
  print("Contract Account ID: ${info.contractAccountId}");
  print("Account Balance: ${info.balance}");
  print("Account Memo: '${info.accountMemo}'");
  print("Is Deleted: ${info.deleted}");
  print("Receiver Signature Required: ${info.receiverSignatureRequired}");
  print("Owned NFTs: ${info.ownedNfts}");
  print("Public Key: ${info.key}");
  print("Expiration Time: ${info.expirationTime}");
  print("Auto Renew Period: ${info.autoRenewPeriod?.seconds}s");
  print("Proxy Received: ${info.proxyReceived}");
}

Future<void> main() async {
  final client = await setupClient();
  final operatorId = client.operatorAccountId;
  final operatorKey = client.operatorPrivateKey;

  if (operatorId == null || operatorKey == null) {
    print("Error: Client operator is not set. Please check your .env file.");
    exit(1);
  }

  final (newAccountId, _) = await createTestAccount(client, operatorKey);

  try {
    print("\nQuerying account info for: $newAccountId");
    final info = await AccountInfoQuery(newAccountId).execute(client);
    print("\nAccount info query completed successfully!");
    displayAccountInfo(info);
  } catch (e) {
    print("Error querying account info: $e");
    exit(1);
  }
}
