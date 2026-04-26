import 'dart:convert';
import 'dart:typed_data';
import 'package:hiero_sdk_dart/src/hapi/services/basic_types.pb.dart'
    as basic_types;

typedef EndpointDict = ({String ipAddressV4, int port, String domainName});

class Endpoint {
  Uint8List _address;
  int _port;
  String _domainName;

  Endpoint({
    required Uint8List address,
    required int port,
    required String domainName,
  }) : _address = address,
       _port = port,
       _domainName = domainName;

  Endpoint setAddress(Uint8List address) {
    _address = address;
    return this;
  }

  Uint8List getAddress() {
    return _address;
  }

  Endpoint setPort(int port) {
    _port = port;
    return this;
  }

  int getPort() {
    return _port;
  }

  Endpoint setDomainName(String domainName) {
    _domainName = domainName;
    return this;
  }

  String getDomainName() {
    return _domainName;
  }

  factory Endpoint.fromProto(basic_types.ServiceEndpoint serviceEndpoint) {
    int port = serviceEndpoint.port;
    if (port == 0 || port == 50111) port = 50211;
    return Endpoint(
      address: Uint8List.fromList(serviceEndpoint.ipAddressV4),
      port: port,
      domainName: serviceEndpoint.domainName,
    );
  }

  basic_types.ServiceEndpoint toProto() {
    return basic_types.ServiceEndpoint(
      ipAddressV4: _address,
      port: _port,
      domainName: _domainName,
    );
  }

  factory Endpoint.fromDict(EndpointDict dict) {
    if (dict.ipAddressV4.isEmpty ||
        dict.domainName.isEmpty ||
        dict.port.isNaN) {
      throw ArgumentError(
        "JSON data must contain 'ip_address_v4', 'port', and 'domain_name' keys.",
      );
    }
    return Endpoint(
      address: Uint8List.fromList(utf8.encode(dict.ipAddressV4)),
      port: dict.port,
      domainName: dict.domainName,
    );
  }

  factory Endpoint.fromJson(Map<String, dynamic> json) {
    final String ipAddressV4 =
        (json['ip_address_v4'] ?? json['ipAddressV4'] ?? '').toString();
    final String domainName = (json['domain_name'] ?? json['domainName'] ?? '')
        .toString();

    final dynamic rawPort = json['port'];
    final int port = rawPort is int
        ? rawPort
        : int.tryParse(rawPort?.toString() ?? '') ?? 0;

    if (port <= 0 || (ipAddressV4.isEmpty && domainName.isEmpty)) {
      throw ArgumentError(
        "JSON data must contain at least one address field and a valid 'port'.",
      );
    }

    final String resolvedAddress = ipAddressV4.isNotEmpty
        ? ipAddressV4
        : domainName;

    return Endpoint(
      address: Uint8List.fromList(utf8.encode(resolvedAddress)),
      port: port,
      domainName: domainName,
    );
  }

  @override
  String toString() {
    return "${utf8.decode(_address, allowMalformed: true)}:{$_port}";
  }
}
