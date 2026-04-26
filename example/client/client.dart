import 'package:dart_dotenv/dart_dotenv.dart';
import 'package:hiero_sdk_dart/src/account/account_id.dart';
import 'package:hiero_sdk_dart/src/client/client.dart';
import 'package:hiero_sdk_dart/src/client/network.dart';
import 'package:hiero_sdk_dart/src/crypto/private_key.dart';

DotEnv _dotEnv = DotEnv(filePath: '.env');
Map<String, dynamic> _env = _dotEnv.getDotEnv();

Future<Network> setupNetwork() async {
  final networkName = (_env['NETWORK'] ?? 'testnet').toLowerCase();
  print('Step 1: Create the network configuration');
  final network = await Network.create(network: networkName);

  print('  - Connected to: ${network.network}');
  print('  - Nodes available: ${network.nodes.length}');

  return network;
}

Client setupClient(Network network) {
  print('\nStep 2: Create the client with the network');
  final client = Client(network: network);

  print('  - Client initialized with network: ${client.network.network}');
  return client;
}

Future<void> setupOperator(Client client) async {
  print('\nStep 3: Configure operator credentials');

  final operatorIdStr = _env['OPERATOR_ID'];
  final operatorKeyStr = _env['OPERATOR_KEY'];

  if (operatorIdStr == null || operatorKeyStr == null) {
    print('  - OPERATOR_ID or OPERATOR_KEY missing in environment.');
    return;
  }

  final operatorId = AccountId.fromString(operatorIdStr);
  final operatorKey = await PrivateKey.fromString(operatorKeyStr);

  client.setOperator(operatorId, operatorKey);
  print('  - Operator set: ${operatorId.toString()}');
}

void displayClientConfiguration(Client client) {
  print('\n=== Client Configuration ===');
  print('Client is ready to use!');
  print('Max retry attempts: ${client.maxAttempts}');

  final nodes = client.getNodeAccountIds();
  print('Total Nodes: ${nodes.length}');
}

void displayAvailableNodes(Client client) {
  print('\n=== Available Nodes (Sample) ===');
  final nodes = client.getNodeAccountIds();

  for (var i = 0; i < nodes.length && i < 5; i++) {
    print('  - Node: ${nodes[i].toString()}');
  }

  if (nodes.length > 5) {
    print('  ... and ${nodes.length - 5} more.');
  }
}

Future<void> demonstrateManualSetup() async {
  print('\n--- [ Method 1: Manual Setup ] ---');
  final network = await setupNetwork();
  final client = setupClient(network);

  try {
    await setupOperator(client);
    displayClientConfiguration(client);
    displayAvailableNodes(client);
  } finally {
    await client.close();
  }
}

Future<void> demonstrateFastSetup() async {
  print('\n--- [ Method 2: Fast Setup (fromEnv) ] ---');
  print('Initializing client from environment variables...');

  try {
    final client = await Client.fromEnv();
    try {
      final operator = client.operatorAccountId;
      if (operator != null) {
        print('Success! Connected as operator: ${operator.toString()}');
      } else {
        print('Success! Client initialized without operator.');
      }
    } finally {
      await client.close();
    }
  } catch (e) {
    print('Failed: $e');
  }
}

Future<void> main() async {
  await demonstrateManualSetup();

  await demonstrateFastSetup();
}
