import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:cryptography/cryptography.dart';
import 'package:hiero_sdk_dart/src/crypto/key.dart';
import 'package:hiero_sdk_dart/src/crypto/public_key.dart' as public_key;
import 'package:hiero_sdk_dart/src/hapi/services/basic_types.pb.dart'
    as basic_types;

class PrivateKey extends Key {
  final Object? _privateKey;

  PrivateKey(this._privateKey);

  static Future<PrivateKey> fromString(String keyStr) async {
    keyStr = keyStr.trim();
    if (keyStr.startsWith('0x')) {
      keyStr = keyStr.substring(2);
    }
    try {
      Uint8List keyBytes = Uint8List.fromList(hex.decode(keyStr));
      return await PrivateKey.fromBytes(keyBytes);
    } catch (e) {
      throw ArgumentError('Invalid private key string: $e');
    }
  }

  static Future<PrivateKey> fromStringEd25519(String keyStr) async {
    keyStr = keyStr.trim();
    if (keyStr.startsWith('0x')) {
      keyStr = keyStr.substring(2);
    }
    try {
      Uint8List keyBytes = Uint8List.fromList(hex.decode(keyStr));
      return await PrivateKey.fromBytesEd25519(keyBytes);
    } catch (e) {
      throw ArgumentError('Invalid Ed25519 private key string: $e');
    }
  }

  static Future<PrivateKey> generate(String keyType) async {
    return await generateEd25519();
  }

  static Future<PrivateKey> generateEd25519() async {
    final algo = Ed25519();
    final keyPair = await algo.newKeyPair();
    return PrivateKey(keyPair);
  }

  static Future<PrivateKey> fromBytes(Uint8List keyBytes) async {
    if (keyBytes.length == 32) {
      SimpleKeyPair? keyPair = await tryLoadEd25519(keyBytes);
      if (keyPair != null) {
        return PrivateKey(keyPair);
      }
    }
    throw ArgumentError('Unsupported private key length: ${keyBytes.length}');
  }

  static Future<SimpleKeyPair?> tryLoadEd25519(Uint8List keyBytes) async {
    try {
      return await Ed25519().newKeyPairFromSeed(keyBytes);
    } catch (e) {
      print('Invalid Ed25519 private key: $e');
      return null;
    }
  }

  static Future<PrivateKey> fromBytesEd25519(Uint8List seed) async {
    if (seed.length != 32) {
      throw ArgumentError(
        'Invalid Ed25519 private key must be 32 bytes, got ${seed.length}',
      );
    }
    try {
      final keyPair = await Ed25519().newKeyPairFromSeed(seed);
      return PrivateKey(keyPair);
    } catch (e) {
      throw ArgumentError('Invalid Ed25519 private key: $e');
    }
  }

  Future<Uint8List> sign(Uint8List bytes) async {
    if (isEd25519) {
      final algo = Ed25519();
      final signature = await algo.sign(
        bytes,
        keyPair: _privateKey as SimpleKeyPair,
      );
      return Uint8List.fromList(signature.bytes);
    }
    throw ArgumentError('Unsupported private key type for signing');
  }

  Future<public_key.PublicKey> publicKey() async {
    if (isEd25519) {
      final keyPair = _privateKey as SimpleKeyPair;
      final publicKey = await keyPair.extractPublicKey();
      return public_key.PublicKey(publicKey);
    }
    throw ArgumentError(
      'Unsupported private key type for extracting public key',
    );
  }

  Future<Uint8List> toBytesRaw() async {
    if (isEd25519) {
      return await toBytesEd25519();
    }
    throw ArgumentError('Unsupported private key type for byte extraction');
  }

  Future<Uint8List> toBytesEd25519() async {
    if (isEd25519) {
      final bytes = await (_privateKey as SimpleKeyPair)
          .extractPrivateKeyBytes();
      return Uint8List.fromList(bytes);
    }
    throw ArgumentError('Unsupported private key type for byte extraction');
  }

  Future<String> toStringRaw() async {
    if (isEd25519) {
      return hex.encode(await toBytesRaw());
    }
    throw ArgumentError('Unsupported private key type for string conversion');
  }

  Future<String> toStringEd25519Raw() async {
    if (isEd25519) {
      final bytes = await (_privateKey as SimpleKeyPair)
          .extractPrivateKeyBytes();
      return hex.encode(bytes);
    }
    throw ArgumentError('Unsupported private key type for string conversion');
  }

  bool get isEd25519 => _privateKey is SimpleKeyPair;

  @override
  Future<basic_types.Key> toProtoKey() async {
    final pubKey = await publicKey();
    return await pubKey.toProtoKey();
  }
}
