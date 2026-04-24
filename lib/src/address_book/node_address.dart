import 'dart:typed_data';

import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:hiero_sdk_dart/src/account/account_id.dart';
import 'package:hiero_sdk_dart/src/address_book/endpoint.dart';
import 'package:hiero_sdk_dart/src/hapi/services/basic_types.pb.dart'
    as basic_types;

typedef NodeDict = ({
  String publicKey,
  String nodeAccountId,
  int nodeId,
  String nodeCertHash,
  List<EndpointDict> serviceEndpoints,
  String description,
});

class NodeAddress {
  final String? _publicKey;
  final AccountId? _accountId;
  final int _nodeId;
  final Uint8List? _certHash;
  final List<Endpoint> _addresses;
  final String? _description;

  NodeAddress({
    required String? publicKey,
    required AccountId? accountId,
    required int nodeId,
    required Uint8List? certHash,
    required List<Endpoint> addresses,
    required String? description,
  }) : _publicKey = publicKey,
       _accountId = accountId,
       _nodeId = nodeId,
       _certHash = certHash,
       _addresses = addresses,
       _description = description;

  factory NodeAddress.fromProto(basic_types.NodeAddress nodeAddressProto) {
    List<Endpoint> addresses = <Endpoint>[];
    for (final endpointProto in nodeAddressProto.serviceEndpoint) {
      addresses.add(Endpoint.fromProto(endpointProto));
    }

    AccountId accountId = AccountId.fromProto(nodeAddressProto.nodeAccountId);

    return NodeAddress(
      publicKey: nodeAddressProto.rSAPubKey,
      accountId: accountId,
      nodeId: nodeAddressProto.nodeId.toInt(),
      certHash: Uint8List.fromList(nodeAddressProto.nodeCertHash),
      addresses: addresses,
      description: nodeAddressProto.description,
    );
  }

  basic_types.NodeAddress toProto() {
    basic_types.NodeAddress nodeAddressProto = basic_types.NodeAddress(
      rSAPubKey: _publicKey,
      nodeId: fixnum.Int64(_nodeId),
      nodeCertHash: _certHash,
      description: _description,
    );

    if (_accountId != null) {
      nodeAddressProto.nodeAccountId = _accountId.toProto();
    }

    for (final endpoint in _addresses) {
      nodeAddressProto.serviceEndpoint.add(endpoint.toProto());
    }
    return nodeAddressProto;
  }

  @override
  String toString() {
    final addressesStr = _addresses.map((address) => address.toString()).join();
    final certHashStr =
        _certHash
            ?.map((byte) => byte.toRadixString(16).padLeft(2, '0'))
            .join() ??
        '';
    final nodeIdStr = _nodeId.toString();
    final accountIdStr = _accountId?.toString() ?? '';

    return 'NodeAccountId: $accountIdStr $addressesStr\n'
        'CertHash: $certHashStr\n'
        'NodeId: $nodeIdStr\n'
        'PubKey: ${_publicKey ?? ''}';
  }

  factory NodeAddress.fromDict(NodeDict node) {
    List<EndpointDict> serviceEndpoints = node.serviceEndpoints;
    String publicKey = node.publicKey;
    AccountId accountId = AccountId.fromString(node.nodeAccountId);
    int nodeId = node.nodeId;
    Uint8List certHash = Uint8List.fromList(node.nodeCertHash.codeUnits);
    String description = node.description;

    List<Endpoint> endpoints = [];
    for (final endpointDict in serviceEndpoints) {
      endpoints.add(Endpoint.fromDict(endpointDict));
    }

    return NodeAddress(
      publicKey: publicKey,
      accountId: accountId,
      nodeId: nodeId,
      certHash: certHash,
      addresses: endpoints,
      description: description,
    );
  }
}
