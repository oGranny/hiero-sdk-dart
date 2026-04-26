import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:hiero_sdk_dart/src/address_book/node_address.dart';
import 'package:hiero_sdk_dart/src/managed_node_address.dart';
import 'package:http/http.dart' as http;

import 'package:hiero_sdk_dart/src/account/account_id.dart';
import 'package:hiero_sdk_dart/src/node.dart';

class Network {
  static const Map<String, String> mirrorAddressDefault = {
    'mainnet': 'mainnet.mirrornode.hedera.com:443',
    "testnet": "testnet.mirrornode.hedera.com:443",
    "previewnet": "previewnet.mirrornode.hedera.com:443",
    "solo": "localhost:5600",
  };

  static const Map<String, String> mirrorNodeUrls = {
    "mainnet": "https://mainnet-public.mirrornode.hedera.com",
    "testnet": "https://testnet.mirrornode.hedera.com",
    "previewnet": "https://previewnet.mirrornode.hedera.com",
    "solo": "http://localhost:5551",
  };

  static Map<String, List<(String, AccountId)>> defaultNodes = {
    "mainnet": [
      ("35.237.200.180:50211", AccountId(shard: 0, realm: 0, num: 3)),
      ("35.186.191.247:50211", AccountId(shard: 0, realm: 0, num: 4)),
      ("35.192.2.25:50211", AccountId(shard: 0, realm: 0, num: 5)),
      ("35.199.161.108:50211", AccountId(shard: 0, realm: 0, num: 6)),
      ("35.203.82.240:50211", AccountId(shard: 0, realm: 0, num: 7)),
      ("35.236.5.219:50211", AccountId(shard: 0, realm: 0, num: 8)),
      ("35.197.192.225:50211", AccountId(shard: 0, realm: 0, num: 9)),
      ("35.242.233.154:50211", AccountId(shard: 0, realm: 0, num: 10)),
      ("35.240.118.96:50211", AccountId(shard: 0, realm: 0, num: 11)),
      ("35.204.86.32:50211", AccountId(shard: 0, realm: 0, num: 12)),
      ("35.234.132.107:50211", AccountId(shard: 0, realm: 0, num: 13)),
      ("35.236.2.27:50211", AccountId(shard: 0, realm: 0, num: 14)),
    ],
    "testnet": [
      ("0.testnet.hedera.com:50211", AccountId(shard: 0, realm: 0, num: 3)),
      ("1.testnet.hedera.com:50211", AccountId(shard: 0, realm: 0, num: 4)),
      ("2.testnet.hedera.com:50211", AccountId(shard: 0, realm: 0, num: 5)),
      ("3.testnet.hedera.com:50211", AccountId(shard: 0, realm: 0, num: 6)),
    ],
    "previewnet": [
      ("0.previewnet.hedera.com:50211", AccountId(shard: 0, realm: 0, num: 3)),
      ("1.previewnet.hedera.com:50211", AccountId(shard: 0, realm: 0, num: 4)),
      ("2.previewnet.hedera.com:50211", AccountId(shard: 0, realm: 0, num: 5)),
      ("3.previewnet.hedera.com:50211", AccountId(shard: 0, realm: 0, num: 6)),
    ],
    "solo": [("localhost:50211", AccountId(shard: 0, realm: 0, num: 3))],
    "localhost": [("localhost:50211", AccountId(shard: 0, realm: 0, num: 3))],
    "local": [("localhost:50211", AccountId(shard: 0, realm: 0, num: 3))],
  };

  static Map<String, Uint8List> ledgerIds = {
    "mainnet": Uint8List.fromList([0x00]),
    "testnet": Uint8List.fromList([0x01]),
    "previewnet": Uint8List.fromList([0x02]),
    "solo": Uint8List.fromList([0x03]),
  };

  String network;
  String mirrorAddress;
  Uint8List ledgerId;
  List<Node> nodes;
  List<String> hostedNetworks = ["mainnet", "testnet", "previewnet"];
  late bool transportSecurity;
  late bool verifyCertificates;
  Uint8List? rootCertificates;
  List<Node> healthyNodes = [];
  Duration nodeMinReadmitPeriod = Duration(seconds: 8);
  Duration nodeMaxReadmitPeriod = Duration(seconds: 3600);
  late DateTime earliestReadmitPeriod;
  int nodeIndex = 0;
  late Node currentNode;

  Network._forAsync({
    required this.network,
    required this.mirrorAddress,
    required this.ledgerId,
    required this.nodes,
  }) {
    transportSecurity = hostedNetworks.contains(this.network);
    verifyCertificates = true;
    earliestReadmitPeriod = DateTime.now().add(nodeMinReadmitPeriod);
  }

  Network({
    String? network,
    String? mirrorAddress,
    Uint8List? ledgerId,
    List<Node>? nodes,
  }) : network = network ?? 'testnet',
       mirrorAddress =
           mirrorAddress ?? mirrorAddressDefault[network ?? 'solo']!,
       ledgerId = ledgerId ?? ledgerIds[network ?? 'solo']!,
       nodes = nodes ?? [] {
    transportSecurity = hostedNetworks.contains(this.network);
    verifyCertificates = true;
    earliestReadmitPeriod = DateTime.now().add(nodeMinReadmitPeriod);

    final List<Node> initialNodes = resolveNodesSync(nodes);
    applyResolvedNodes(initialNodes);
    initializeCurrentNode();
  }

  static Future<Network> create({
    String? network,
    String? mirrorAddress,
    Uint8List? ledgerId,
    List<Node>? nodes,
  }) async {
    final Network instance = Network._forAsync(
      network: network ?? 'testnet',
      mirrorAddress: mirrorAddress ?? mirrorAddressDefault[network ?? 'solo']!,
      ledgerId: ledgerId ?? ledgerIds[network ?? 'solo']!,
      nodes: nodes ?? [],
    );

    await instance.setNetworkNodes(nodes);
    instance.initializeCurrentNode();
    return instance;
  }

  List<Node> resolveNodesSync(List<Node>? nodes) {
    if (nodes != null && nodes.isNotEmpty) {
      return nodes;
    }
    if (defaultNodes.containsKey(network) ||
        ["solo", "localhost", "local"].contains(network)) {
      return fetchNodesFromDefaultNodes();
    }

    throw ArgumentError(
      'No default nodes available for network $network. '
      'Use Network.create() to allow async node resolution.',
    );
  }

  void initializeCurrentNode() {
    if (healthyNodes.isEmpty) {
      throw ArgumentError('No healthy nodes available for network $network');
    }
    nodeIndex = Random.secure().nextInt(healthyNodes.length);
    currentNode = healthyNodes[nodeIndex];
  }

  void applyResolvedNodes(List<Node> finalNodes) {
    for (Node node in finalNodes) {
      node.applyTransportSecurity(transportSecurity);
      node.setVerifyCertificates(verifyCertificates);
      node.setRootCertificates(rootCertificates);
    }

    nodes = finalNodes;
    healthyNodes = [];
    for (Node node in nodes) {
      if (!node.isHealthy()) continue;
      healthyNodes.add(node);
    }

    if (healthyNodes.isEmpty) {
      throw ArgumentError('No healthy nodes available for network $network');
    }
  }

  Future<void> setNetworkNodes(List<Node>? nodes) async {
    List<Node> finalNodes = await resolveNodes(nodes);
    applyResolvedNodes(finalNodes);

    if (healthyNodes.isNotEmpty) {
      currentNode = healthyNodes[nodeIndex % healthyNodes.length];
    }
  }

  Future<List<Node>> resolveNodes(List<Node>? nodes) async {
    if (nodes != null && nodes.isNotEmpty) {
      return nodes;
    }
    if (["solo", "localhost", "local"].contains(network)) {
      print("local");
      return fetchNodesFromDefaultNodes();
    }
    List<Node> fetched = await fetchNodesFromMirrorNode();
    if (fetched.isNotEmpty) {
      return fetched;
    }

    if (defaultNodes.containsKey(network)) {
      return fetchNodesFromDefaultNodes();
    }

    throw ArgumentError('No nodes available for network $network');
  }

  Future<List<Node>> fetchNodesFromMirrorNode() async {
    String? baseUrl = mirrorNodeUrls[network];
    if (baseUrl == null) {
      print(
        'No mirror node URL configured for network $network, skipping fetch',
      );
      return [];
    }

    String url = '$baseUrl/api/v1/network/nodes?limit=100&order=desc';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<Node> nodes = [];
        for (var node in (data['nodes'] ?? [])) {
          try {
            if (node is! Map<String, dynamic>) {
              continue;
            }
            NodeAddress addressBook = NodeAddress.fromJson(node);
            if (addressBook.addresses.isEmpty) {
              continue;
            }

            final endpoint = addressBook.addresses.first;
            final String decodedAddress = utf8.decode(
              endpoint.getAddress(),
              allowMalformed: true,
            );
            final String host = endpoint.getDomainName().isNotEmpty
                ? endpoint.getDomainName()
                : decodedAddress;
            if (host.isEmpty) {
              continue;
            }

            AccountId accountId = addressBook.accountId!;
            final String address = '$host:${endpoint.getPort()}';

            nodes.add(
              Node(
                address: ManagedNodeAddress.fromString(address),
                accountId: accountId,
                addressBook: addressBook,
              ),
            );
          } catch (e) {
            print('Skipping invalid mirror node entry: $e');
            print('Node data: ${jsonEncode(node)}');
            continue;
          }
        }
        return nodes;
      } else {
        print(
          'Failed to fetch nodes from mirror node: ${response.statusCode} ${response.reasonPhrase}',
        );
        return [];
      }
    } catch (e) {
      print('Unexpected error fetching nodes: $e');
      // return [];
      throw ArgumentError('Failed to fetch nodes from mirror node: $e');
    }
  }

  List<Node> fetchNodesFromDefaultNodes() {
    List<Node> nodes = [];
    for (var (String address, AccountId accountId) in defaultNodes[network]!) {
      nodes.add(
        Node(
          address: ManagedNodeAddress.fromString(address),
          accountId: accountId,
        ),
      );
    }
    return nodes;
  }

  Node selectNode() {
    readmitNodes();
    if (healthyNodes.isEmpty) {
      throw ArgumentError('No healthy nodes available for network $network');
    }

    nodeIndex %= healthyNodes.length;
    nodeIndex = (nodeIndex + 1) % healthyNodes.length;
    currentNode = healthyNodes[nodeIndex];
    return currentNode;
  }

  Node? getNode(AccountId accountId) {
    readmitNodes();

    for (Node node in nodes) {
      if (node.accountId == accountId) {
        return node;
      }
    }
    return null;
  }

  String getMirrorAddress() {
    return mirrorAddress;
  }

  (String, int) parseMirrorAddress() {
    final parts = mirrorAddress.split(':');
    if (parts.length != 2) {
      throw FormatException('Invalid mirror address format: $mirrorAddress');
    }
    return (parts[0], int.parse(parts[1]));
  }

  (String, int) determineSchemeAndPort(String host, int port) {
    final bool isLocalhost = host == 'localhost' || host == '127.0.0.1';
    String scheme;
    int p;
    if (isLocalhost) {
      scheme = 'http';
      p = (port == 443) ? 8080 : port;
    } else {
      scheme = 'https';
      p = (port == 5600) ? 443 : port;
    }
    return (scheme, p);
  }

  String buildRestUrl(String scheme, String host, int port) {
    final bool isDefaultPort =
        (scheme == "https" && port == 443) || (scheme == "http" && port == 80);

    if (isDefaultPort) {
      return '$scheme://$host/api/v1';
    } else {
      return '$scheme://$host:$port/api/v1';
    }
  }

  String getMirrorRestUrl() {
    final String? baseUrl = mirrorNodeUrls[network];
    if (baseUrl != null) {
      return "$baseUrl/api/v1";
    }

    final (String host, int port) = parseMirrorAddress();
    final (String scheme, int p) = determineSchemeAndPort(host, port);
    return buildRestUrl(scheme, host, p);
  }

  void setTransportSecurity(bool enabled) {
    if (transportSecurity == enabled) {
      return;
    }
    for (Node node in nodes) {
      node.applyTransportSecurity(enabled);
    }
    transportSecurity = enabled;
  }

  bool isTransportSecurity() {
    return transportSecurity;
  }

  void setVerifyCertificates(bool verify) {
    if (verifyCertificates == verify) {
      return;
    }
    for (Node node in nodes) {
      node.setVerifyCertificates(verify);
    }
    verifyCertificates = verify;
  }

  void setTlsRootCertificates(Uint8List? rootCerts) {
    rootCertificates = rootCerts;
    for (Node node in nodes) {
      node.setRootCertificates(rootCerts);
    }
  }

  Uint8List? getTlsRootCertificates() {
    return rootCertificates;
  }

  bool isVerifyCertificates() {
    return verifyCertificates;
  }

  void increaseBackoff(Node node) {
    node.increaseBackoff();
    markNodeUnhealthy(node);
  }

  void markNodeUnhealthy(Node node) {
    if (healthyNodes.contains(node)) {
      healthyNodes.remove(node);
    }
  }

  void decreaseBackoff(Node node) {
    node.decreaseBackoff();
  }

  void readmitNodes() {
    DateTime now = DateTime.now();

    if (now.isBefore(earliestReadmitPeriod)) return;

    DateTime nextReadmit = DateTime.fromMillisecondsSinceEpoch(
      8640000000000000,
    ); // infinite time

    for (Node n in nodes) {
      if (healthyNodes.contains(n)) continue;
      if (now.isBefore(n.readmitTime) && nextReadmit.isAfter(n.readmitTime)) {
        nextReadmit = n.readmitTime;
        continue;
      }
      markNodeHealthy(n);
    }
    final Duration untilNext = nextReadmit.difference(now);
    final Duration boundedLow = untilNext < nodeMinReadmitPeriod
        ? nodeMinReadmitPeriod
        : untilNext;
    final Duration delay = boundedLow > nodeMaxReadmitPeriod
        ? nodeMaxReadmitPeriod
        : boundedLow;
    earliestReadmitPeriod = now.add(delay);
  }

  void markNodeHealthy(Node node) {
    if (!healthyNodes.contains(node)) {
      healthyNodes.add(node);
    }
  }
}
