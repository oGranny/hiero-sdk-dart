import 'dart:io';
import 'dart:typed_data';

import 'package:dart_dotenv/dart_dotenv.dart';
import 'package:decimal/decimal.dart';
import 'package:grpc/grpc.dart';
import 'package:hiero_sdk_dart/src/account/account_id.dart';
import 'package:hiero_sdk_dart/src/client/network.dart';
import 'package:hiero_sdk_dart/src/crypto/private_key.dart';
import 'package:hiero_sdk_dart/src/hapi/mirror/consensus_service.pbgrpc.dart'
    as mirror_consensus_grpc;
import 'package:hiero_sdk_dart/src/hbar.dart';
import 'package:hiero_sdk_dart/src/transaction/transaction_id.dart';

final Hbar defaultMaxQueryPayment = Hbar(1);

const double defaultGrpcDeadline = 10;
const double defaultRequestTimeout = 120;
const double defaultMaxBackoff = 8;
const double defaultMinBackoff = 0.25;

enum NetworkName { mainnet, testnet, previewnet }

class Operator {
  final AccountId accountId;
  final PrivateKey privateKey;

  const Operator(this.accountId, this.privateKey);
}

class Client {
  AccountId? operatorAccountId;
  PrivateKey? operatorPrivateKey;

  final Network network;
  ClientChannel? mirrorChannel;
  mirror_consensus_grpc.ConsensusServiceClient? mirrorStub;

  int maxAttempts = 10;
  Hbar defaultMaxQueryPaymentAmount = defaultMaxQueryPayment;

  double _minBackoff = defaultMinBackoff;
  double _maxBackoff = defaultMaxBackoff;
  double _grpcDeadline = defaultGrpcDeadline;
  double _requestTimeout = defaultRequestTimeout;

  Client({Network? network}) : network = network ?? Network() {
    _initMirrorStub();
  }

  static Future<Client> fromEnv({NetworkName? network}) async {
    final dotEnv = DotEnv();
    final env = dotEnv.getDotEnv();

    final networkName = (network?.name ?? env['NETWORK'] ?? "testnet")
        .toLowerCase();

    if (!NetworkName.values.any((value) => value.name == networkName)) {
      throw ArgumentError('Invalid network name: $networkName');
    }

    final client = Client(network: await Network.create(network: networkName));

    final operatorIdStr =
        Platform.environment['OPERATOR_ID'] ?? env['OPERATOR_ID'];
    final operatorKeyStr =
        Platform.environment['OPERATOR_KEY'] ?? env['OPERATOR_KEY'];

    if (operatorIdStr == null || operatorIdStr.isEmpty) {
      throw ArgumentError(
        'OPERATOR_ID environment variable is required for Client.fromEnv()',
      );
    }
    if (operatorKeyStr == null || operatorKeyStr.isEmpty) {
      throw ArgumentError(
        'OPERATOR_KEY environment variable is required for Client.fromEnv()',
      );
    }
    final AccountId operatorId = AccountId.fromString(operatorIdStr);
    final PrivateKey operatorKey = await PrivateKey.fromString(operatorKeyStr);
    client.setOperator(operatorId, operatorKey);

    return client;
  }

  static Client forTestnet() =>
      Client(network: Network(network: NetworkName.testnet.name));

  static Client forMainnet() =>
      Client(network: Network(network: NetworkName.mainnet.name));

  static Client forPreviewnet() =>
      Client(network: Network(network: NetworkName.previewnet.name));

  void _initMirrorStub() {
    final mirrorAddress = network.getMirrorAddress();
    final (host, port) = _parseHostPort(mirrorAddress);

    final isSecure =
        mirrorAddress.endsWith(':50212') || mirrorAddress.endsWith(':443');

    mirrorChannel = ClientChannel(
      host,
      port: port,
      options: ChannelOptions(
        credentials: isSecure
            ? const ChannelCredentials.secure()
            : const ChannelCredentials.insecure(),
      ),
    );

    mirrorStub = mirror_consensus_grpc.ConsensusServiceClient(mirrorChannel!);
  }

  (String, int) _parseHostPort(String mirrorAddress) {
    final sep = mirrorAddress.lastIndexOf(':');
    if (sep == -1) {
      return (mirrorAddress, 443);
    }
    final host = mirrorAddress.substring(0, sep);
    final port = int.tryParse(mirrorAddress.substring(sep + 1)) ?? 443;
    return (host, port);
  }

  void setOperator(AccountId accountId, PrivateKey privateKey) {
    operatorAccountId = accountId;
    operatorPrivateKey = privateKey;
  }

  Operator? get operator {
    if (operatorAccountId != null && operatorPrivateKey != null) {
      return Operator(operatorAccountId!, operatorPrivateKey!);
    }
    return null;
  }

  TransactionId generateTransactionId() {
    if (operatorAccountId == null) {
      throw ArgumentError(
        'Operator account ID must be set to generate transaction ID.',
      );
    }
    return TransactionId.generate(operatorAccountId!);
  }

  List<AccountId> getNodeAccountIds() {
    if (network.nodes.isEmpty) {
      throw ArgumentError('No nodes available in the network configuration.');
    }
    return network.nodes.map((node) => node.accountId).toList();
  }

  Future<void> close() async {
    if (mirrorChannel != null) {
      await mirrorChannel!.shutdown();
      mirrorChannel = null;
    }
    mirrorStub = null;
  }

  Client setTransportSecurity(bool enabled) {
    network.setTransportSecurity(enabled);
    return this;
  }

  bool isTransportSecurity() => network.isTransportSecurity();

  Client setVerifyCertificates(bool verify) {
    network.setVerifyCertificates(verify);
    return this;
  }

  bool isVerifyCertificates() => network.isVerifyCertificates();

  Client setTlsRootCertificates(Uint8List? rootCertificates) {
    network.setTlsRootCertificates(rootCertificates);
    return this;
  }

  Uint8List? getTlsRootCertificates() => network.getTlsRootCertificates();

  Client setDefaultMaxQueryPayment(Object maxQueryPayment) {
    if (maxQueryPayment is bool ||
        (maxQueryPayment is! int &&
            maxQueryPayment is! double &&
            maxQueryPayment is! Decimal &&
            maxQueryPayment is! Hbar)) {
      throw ArgumentError(
        'maxQueryPayment must be int, double, Decimal, or Hbar, got ${maxQueryPayment.runtimeType}',
      );
    }

    final value = maxQueryPayment is Hbar
        ? maxQueryPayment
        : Hbar(maxQueryPayment);
    if (value < Hbar(0)) {
      throw ArgumentError('maxQueryPayment must be non-negative');
    }

    defaultMaxQueryPaymentAmount = value;
    return this;
  }

  Client setMaxAttempts(int maxAttempts) {
    if (maxAttempts <= 0) {
      throw ArgumentError('maxAttempts must be greater than 0');
    }
    this.maxAttempts = maxAttempts;
    return this;
  }

  Client setGrpcDeadline(num grpcDeadline) {
    if (grpcDeadline is bool) {
      throw ArgumentError('grpcDeadline must be int or double');
    }
    if (!grpcDeadline.isFinite || grpcDeadline <= 0) {
      throw ArgumentError('grpcDeadline must be a finite value greater than 0');
    }

    if (grpcDeadline > _requestTimeout) {
      stderr.writeln(
        'Warning: grpcDeadline should be smaller than requestTimeout. This configuration may cause operations to fail unexpectedly.',
      );
    }

    _grpcDeadline = grpcDeadline.toDouble();
    return this;
  }

  Client setRequestTimeout(num requestTimeout) {
    if (requestTimeout is bool) {
      throw ArgumentError('requestTimeout must be int or double');
    }
    if (!requestTimeout.isFinite || requestTimeout <= 0) {
      throw ArgumentError(
        'requestTimeout must be a finite value greater than 0',
      );
    }

    if (requestTimeout < _grpcDeadline) {
      stderr.writeln(
        'Warning: requestTimeout should be larger than grpcDeadline. This configuration may cause operations to fail unexpectedly.',
      );
    }

    _requestTimeout = requestTimeout.toDouble();
    return this;
  }

  Client setMinBackoff(num minBackoff) {
    if (minBackoff is bool) {
      throw ArgumentError('minBackoff must be int or double');
    }
    if (!minBackoff.isFinite || minBackoff < 0) {
      throw ArgumentError('minBackoff must be a finite value >= 0');
    }
    if (minBackoff > _maxBackoff) {
      throw ArgumentError('minBackoff cannot exceed maxBackoff');
    }

    _minBackoff = minBackoff.toDouble();
    return this;
  }

  Client setMaxBackoff(num maxBackoff) {
    if (maxBackoff is bool) {
      throw ArgumentError('maxBackoff must be int or double');
    }
    if (!maxBackoff.isFinite || maxBackoff < 0) {
      throw ArgumentError('maxBackoff must be a finite value >= 0');
    }
    if (maxBackoff < _minBackoff) {
      throw ArgumentError('maxBackoff cannot be less than minBackoff');
    }

    _maxBackoff = maxBackoff.toDouble();
    return this;
  }

  Future<Client> updateNetwork() async {
    await network.setNetworkNodes(null);
    return this;
  }
}
