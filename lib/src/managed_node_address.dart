class ManagedNodeAddress {
  static const int portNodePl = 50211;
  static const int portNodeTLS = 50212;
  static const Set<int> tlsPorts = {portNodeTLS};
  static const Set<int> plainPorts = {portNodePl};

  static RegExp hostPortPattern = RegExp(r'^(\S+):(\d+)$');

  String address;
  int port;

  ManagedNodeAddress(this.address, this.port);

  factory ManagedNodeAddress.fromString(String s) {
    var match = hostPortPattern.firstMatch(s);
    if (match == null) {
      throw FormatException('Invalid node address format: $s');
    }
    var address = match.group(1)!;
    var port = int.parse(match.group(2)!);
    return ManagedNodeAddress(address, port);
  }

  bool isTransportSecurity() {
    return tlsPorts.contains(port);
  }

  ManagedNodeAddress toSecure() {
    if (isTransportSecurity()) {
      return this;
    }
    return ManagedNodeAddress(address, portNodeTLS);
  }

  ManagedNodeAddress toInsecure() {
    if (!isTransportSecurity()) {
      return this;
    }
    return ManagedNodeAddress(address, portNodePl);
  }

  String getHost() {
    return address;
  }

  int getPort() {
    return port;
  }

  @override
  String toString() {
    return '$address:$port';
  }
}
