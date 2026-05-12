import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:cryptography/cryptography.dart';
import 'package:hiero_sdk_dart/src/hapi/services/basic_types.pb.dart'
    as basic_types;

import 'key.dart';

class PublicKey extends Key {
  final Object _publicKey;

  PublicKey(this._publicKey);

  factory PublicKey.fromBytesEd25519(Uint8List pub) {
    if (pub.length != 32) {
      throw ArgumentError(
        'Invalid Ed25519 public key must be 32 bytes, got ${pub.length}',
      );
    }
    try {
      final edPub = SimplePublicKey(pub, type: KeyPairType.ed25519);
      return PublicKey(edPub);
    } catch (e) {
      throw ArgumentError('Invalid Ed25519 public key: $e');
    }
  }

  factory PublicKey.fromBytes(Uint8List pub) {
    if (pub.length == 32) {
      return PublicKey.fromBytesEd25519(pub);
    }
    throw ArgumentError('Unsupported public key length: ${pub.length}');
  }

  factory PublicKey.fromStringEd25519(String hexStr) {
    try {
      Uint8List pub = Uint8List.fromList(hex.decode(hexStr));
      return PublicKey.fromBytesEd25519(pub);
    } catch (e) {
      throw ArgumentError('Invalid Ed25519 public key string: $e');
    }
  }

  factory PublicKey.fromString(String hexStr) {
    late final Uint8List data;
    try {
      data = Uint8List.fromList(hex.decode(hexStr));
    } catch (e) {
      throw ArgumentError(
        'Invalid hex-encoded public key string: $hexStr,  $e',
      );
    }
    if (data.length == 32) {
      return PublicKey.fromStringEd25519(hexStr);
    } else {
      throw ArgumentError(
        'Unsupported public key string length: ${data.length}, expected 32 for Ed25519',
      );
    }
  }

  factory PublicKey.fromProto(basic_types.Key proto) {
    if (proto.ed25519.isNotEmpty) {
      return PublicKey.fromBytesEd25519(Uint8List.fromList(proto.ed25519));
    }

    if (proto.eCDSASecp256k1.isNotEmpty) {
      throw UnimplementedError(
        'ECDSA Secp256K1 public key parsing not implemented yet',
      );
    }

    if (proto.hasContractID()) {
      throw ArgumentError(
        'Key protobuf contains contractID, which is not a PublicKey',
      );
    }

    throw ArgumentError('Unsupported public key type in protobuf');
  }

  basic_types.Key toProto() {
    Uint8List pubBytes = toBytesRaw();
    if (isEd25519) {
      return basic_types.Key(ed25519: pubBytes);
    }
    throw StateError('Unsupported public key type for protobuf conversion');
  }

  @override
  Future<basic_types.Key> toProtoKey() async {
    return toProto();
  }

  bool get isEd25519 =>
      _publicKey is SimplePublicKey && _publicKey.type == KeyPairType.ed25519;

  Uint8List toBytesRaw() {
    if (isEd25519) {
      return toBytesEd25519();
    }
    throw StateError('Unsupported public key type for byte conversion');
  }

  Uint8List toBytesEd25519() {
    if (!isEd25519) {
      throw StateError('PublicKey is not an Ed25519 key');
    }
    return Uint8List.fromList((_publicKey as SimplePublicKey).bytes);
  }

  String toStringRaw() {
    if (isEd25519) {
      return toStringEd25519();
    }
    throw StateError('Unsupported public key type for string conversion');
  }

  String toStringEd25519() {
    if (!isEd25519) {
      throw StateError('PublicKey is not an Ed25519 key');
    }
    return toBytesEd25519()
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  Future<void> verifyEd25519(Uint8List data, Uint8List signature) async {
    if (!isEd25519) {
      throw StateError('PublicKey is not an Ed25519 key');
    }

    final algo = Ed25519();
    final isValid = await algo.verify(
      data,
      signature: Signature(signature, publicKey: _publicKey as SimplePublicKey),
    );

    if (!isValid) {
      throw StateError('Ed25519 signature verification failed');
    }
  }

  @override
  String toString() {
    return 'PublicKey(${isEd25519 ? 'Ed 25519' : 'Unknown'})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PublicKey) return false;
    if (isEd25519 && other.isEd25519) {
      final bytes1 = (_publicKey as SimplePublicKey).bytes;
      final bytes2 = (other._publicKey as SimplePublicKey).bytes;
      if (bytes1.length != bytes2.length) return false;
      for (int i = 0; i < bytes1.length; i++) {
        if (bytes1[i] != bytes2[i]) return false;
      }
      return true;
    }
    return false;
  }

  @override
  int get hashCode {
    if (isEd25519) {
      int result = 17;
      for (final byte in (_publicKey as SimplePublicKey).bytes) {
        result = 31 * result + byte;
      }
      return result;
    }
    return _publicKey.hashCode;
  }
}
