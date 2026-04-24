import 'dart:convert';
import 'dart:io';
import 'dart:math' show min, max;
import 'dart:typed_data';

import 'package:convert/convert.dart' hide IdentityCodec;
import 'package:cryptography/cryptography.dart';
import 'package:grpc/grpc.dart';
import 'package:hiero_sdk_dart/src/account/account_id.dart';
import 'package:hiero_sdk_dart/src/address_book/node_address.dart';
import 'package:hiero_sdk_dart/src/channels.dart';
import 'package:hiero_sdk_dart/src/managed_node_address.dart';

const int certFetchTimeoutSeconds = 10;

class HederaTrustManager {
  Uint8List? certHash;
  bool verifyCertificates;

  HederaTrustManager(Uint8List? certHash, this.verifyCertificates)
    : certHash = _normalizeCertHash(certHash, verifyCertificates);

  static Uint8List? _normalizeCertHash(
    Uint8List? certHash,
    bool verifyCertificates,
  ) {
    if (certHash == null || certHash.isEmpty) {
      if (verifyCertificates) {
        throw ArgumentError(
          'Transport security and certificate verification are enabled, '
          'but no applicable address book was found',
        );
      }
      return null;
    }

    try {
      var value = utf8.decode(certHash).trim().toLowerCase();
      if (value.startsWith('0x')) {
        value = value.substring(2);
      }
      return utf8.encode(value);
    } on FormatException {
      return utf8.encode(
        certHash
            .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
            .join()
            .toLowerCase(),
      );
    }
  }

  Future<bool> checkServerTrusted(Uint8List? pemCert) async {
    if (certHash == null || certHash!.isEmpty) {
      return true;
    }
    Hash cerHash = await Sha384().hash(pemCert!);
    Uint8List cerHashBytes = Uint8List.fromList(cerHash.bytes);
    String actualHash = hex.encode(cerHashBytes).toLowerCase();

    if (actualHash != hex.encode(certHash as List<int>).toLowerCase()) {
      throw ArgumentError(
        "Failed to confirm the server's certificate from a known address book. "
        "Expected hash: ${hex.encode(certHash as List<int>).toLowerCase()}, received hash: $actualHash",
      );
    }
    return true;
  }
}

class Node {
  ManagedNodeAddress address;
  final AccountId accountId;
  final NodeAddress? addressBook;

  Channel? channel;
  bool verifyCertificates = true;
  Uint8List? rootCertificates;
  Uint8List? nodePemCert;

  double minBackoff = 8; // seconds
  double maxBackoff = 3600; // seconds
  double currentBackoff = 8; // seconds
  DateTime readmitTime = DateTime.now();
  int badGrpcResponseCount = 0;

  Node({required this.address, required this.accountId, this.addressBook});

  void close() {
    if (channel != null) {
      channel!.channel.shutdown();
      channel = null;
    }
  }

  Future<Channel> getChannel() async {
    if (channel != null) {
      return channel!;
    }
    if (address.isTransportSecurity()) {
      if (rootCertificates != null) {
        nodePemCert = rootCertificates;
      } else {
        nodePemCert = await fetchServerCertificatePem();
      }
      if (nodePemCert == null) {
        throw ArgumentError('No certificates available');
      }
      if (verifyCertificates) {
        await validateTlsCertWithTrustManager();
      }

      final credentials = ChannelCredentials.secure(certificates: nodePemCert);
      final channel_ = ClientChannel(
        address.getHost(),
        port: address.getPort(),
        options: ChannelOptions(
          credentials: credentials,
          codecRegistry: CodecRegistry(codecs: [GzipCodec(), IdentityCodec()]),
          connectTimeout: Duration(seconds: 100000),
          idleTimeout: Duration(seconds: 100000),
          keepAlive: ClientKeepAliveOptions(timeout: Duration(seconds: 10000)),
        ),
      );
      channel = Channel(channel_);
    } else {
      final channel_ = ClientChannel(
        address.getHost(),
        port: address.getPort(),
        options: ChannelOptions(),
      );
      channel = Channel(channel_);
    }
    return channel!;
  }

  Future<Uint8List?> fetchServerCertificatePem() async {
    if (addressBook == null) {
      return null;
    }

    String host = address.getHost();
    int port = address.getPort();

    final SecurityContext context = SecurityContext(withTrustedRoots: true);
    final SecureSocket socket = await SecureSocket.connect(
      host,
      port,
      context: context,
      timeout: Duration(seconds: certFetchTimeoutSeconds),
    );

    try {
      final cert = socket.peerCertificate;
      if (cert == null) {
        return null;
      }

      final pemCert = cert.pem;
      return Uint8List.fromList(utf8.encode(pemCert));
    } catch (e) {
      print("Error fetching server certificate: $e");
      throw ArgumentError('Error fetching server certificate: $e');
    } finally {
      socket.destroy();
    }
  }

  Future<void> validateTlsCertWithTrustManager() async {
    if (!address.isTransportSecurity() || verifyCertificates) {
      return;
    }
    Uint8List? certHash;
    if (addressBook != null && addressBook!.certHash != null) {
      certHash = addressBook!.certHash;
    }
    if (certHash == null || certHash.isEmpty) return;
    HederaTrustManager trustManager = HederaTrustManager(
      certHash,
      verifyCertificates,
    );
    await trustManager.checkServerTrusted(nodePemCert);
  }

  void applyTransportSecurity(bool enabled) {
    if ((enabled && address.isTransportSecurity()) ||
        (!enabled && !address.isTransportSecurity())) {
      return;
    }

    close();

    if (enabled) {
      address = address.toSecure();
    } else {
      address = address.toInsecure();
    }
  }

  void setRootCertificates(Uint8List? rootCertificates) {
    this.rootCertificates = rootCertificates;
    if (address.isTransportSecurity()) {
      close();
    }
  }

  void setVerifyCertificates(bool verify) {
    if (verifyCertificates == verify) {
      return;
    }
    verifyCertificates = verify;
    if (verify && channel != null && address.isTransportSecurity()) {
      close();
    }
  }

  static String normalizeCertHash(Uint8List? certHash) {
    try {
      String decoded = utf8.decode(certHash!).trim().toLowerCase();
      if (decoded.startsWith('0x')) {
        decoded = decoded.substring(2);
      }

      return decoded;
    } on FormatException catch (_) {
      return certHash!
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join()
          .toLowerCase();
    } catch (e) {
      throw ArgumentError('Invalid cert hash format: $e');
    }
  }

  bool isHealthy() {
    return DateTime.now().isAfter(readmitTime);
  }

  void increaseBackoff() {
    badGrpcResponseCount++;
    currentBackoff = min(currentBackoff * 2, maxBackoff);
    readmitTime = DateTime.now().add(Duration(seconds: currentBackoff.toInt()));
  }

  void decreaseBackoff() {
    currentBackoff = max(currentBackoff / 2, minBackoff);
  }
}
