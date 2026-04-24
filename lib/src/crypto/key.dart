import 'dart:typed_data';

import 'package:hiero_sdk_dart/src/crypto/public_key.dart';
import 'package:hiero_sdk_dart/src/hapi/services/basic_types.pb.dart'
    as basic_types;

abstract class Key {
  const Key();

  factory Key.fromProtoKey(basic_types.Key proto) {
    final keyType = proto.whichKey();
    switch (keyType) {
      case basic_types.Key_Key.ed25519:
        return PublicKey.fromBytesEd25519(Uint8List.fromList(proto.ed25519));
      default:
        throw ArgumentError('Unsupported key type: $keyType');
    }
  }

  factory Key.fromBytes(Uint8List bytes) {
    basic_types.Key key = basic_types.Key();
    key.mergeFromBuffer(bytes);
    return Key.fromProtoKey(key);
  }

  Future<Uint8List> toBytes() async {
    basic_types.Key protoKey = await toProtoKey();
    return protoKey.writeToBuffer();
  }

  Future<basic_types.Key> toProtoKey();
}
