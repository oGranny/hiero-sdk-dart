import 'dart:typed_data';

import 'package:hiero_sdk_dart/src/client/client.dart';

const int _multiplier = 1000003;
const int _p3 = 26 * 26 * 26;
const int _p5 = 26 * 26 * 26 * 26 * 26;

final RegExp idRegex = RegExp(
  r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-([a-z]{5}))?$',
);

(String, String, String, String?) parseFromString(String address) {
  final matches = idRegex.firstMatch(address);
  if (matches == null) {
    throw ArgumentError('Invalid address format');
  }
  return (
    matches.group(1) ?? '',
    matches.group(2) ?? '',
    matches.group(3) ?? '',
    matches.group(4),
  );
}

String generateChecksum(Uint8List ledgerId, String address) {
  final d = <int>[];
  for (final ch in address.split('')) {
    if (ch == '.') {
      d.add(10);
    } else {
      d.add(int.parse(ch));
    }
  }

  var sd0 = 0;
  var sd1 = 0;
  var sd = 0;

  for (var i = 0; i < d.length; i++) {
    sd = (sd * 31 + d[i]) % _p3;
    if (i.isEven) {
      sd0 = (sd0 + d[i]) % 11;
    } else {
      sd1 = (sd1 + d[i]) % 11;
    }
  }

  var sh = 0;
  final h = <int>[...ledgerId, 0, 0, 0, 0, 0, 0];
  for (var i = 0; i < h.length; i++) {
    sh = (sh * 31 + h[i]) % _p5;
  }

  var cp =
      ((((address.length % 5) * 11 + sd0) * 11 + sd1) * _p3 + sd + sh) % _p5;
  cp = (cp * _multiplier) % _p5;

  final letters = <String>[];
  for (var i = 0; i < 5; i++) {
    letters.add(String.fromCharCode('a'.codeUnitAt(0) + (cp % 26)));
    cp ~/= 26;
  }

  return letters.reversed.join();
}

void validateChecksum(
  int shard,
  int realm,
  int num,
  String? checksum,
  Client client,
) {
  if (checksum == null) return;

  Uint8List ledgerId = client.network.ledgerId;
  if (ledgerId.isEmpty) {
    throw ArgumentError('Ledger ID is required for checksum validation');
  }

  String address = formatToString(shard, realm, num);
  String expectedChecksum = generateChecksum(ledgerId, address);
  if (checksum != expectedChecksum) {
    throw ArgumentError(
      'Checksum mismatch: expected $expectedChecksum, got $checksum',
    );
  }
}

String formatToString(int shard, int realm, int num) {
  return '$shard.$realm.$num';
}

String formatToStringWithChecksum(
  int shard,
  int realm,
  int num,
  Client client,
) {
  Uint8List ledgerId = client.network.ledgerId;
  if (ledgerId.isEmpty) {
    throw ArgumentError('Ledger ID is required for checksum generation');
  }
  String baseString = formatToString(shard, realm, num);
  String checksum = generateChecksum(ledgerId, baseString);
  return '$baseString-$checksum';
}
