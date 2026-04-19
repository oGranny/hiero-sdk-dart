import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:hiero_sdk_dart/src/crypto/public_key.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

void exampleLoadEd25519PublicKey() {
  String hexStr =
      '8baa5f735dbf40f275283bed504cb752b1ce58a7118476d28f528ecd265c5f58';
  Uint8List rawPub = Uint8List.fromList(hex.decode(hexStr));
  final pubk_obj = PublicKey.fromBytesEd25519(rawPub);
  print('Loaded Ed25519 public key: $pubk_obj');

  final backToHex = pubk_obj.toStringEd25519();
  print('Converted back to hexadecimal: $backToHex');
}

void exampleLoadEd25519PublicKeyFromHex() {
  String hexStr =
      '09fe6e485c1fb4e24c80b591fc79103c28006d549428a0d3ccb2a88412f2bda8';
  final pubk_obj = PublicKey.fromStringEd25519(hexStr);
  print('Loaded Ed25519 public key from hex string: $pubk_obj');
}

void exampleVerifyEd25519Signature() {
  final keyPair = ed.generateKey();

  final privateKey = keyPair.privateKey;
  final publicKey = keyPair.publicKey;

  final pubk_obj = PublicKey.fromBytes(Uint8List.fromList(publicKey.bytes));

  final data = Uint8List.fromList('Hello, World!'.codeUnits);
  final signature = ed.sign(privateKey, data);

  try {
    pubk_obj.verifyEd25519(data, signature);
    print('ED25519 Signature is valid!');
  } catch (e) {
    print('ED25519 Signature is invalid!, $e');
  }
}

void main() {
  exampleLoadEd25519PublicKey();
  print("------------------------------------");
  exampleLoadEd25519PublicKeyFromHex();
  print("------------------------------------");
  exampleVerifyEd25519Signature();
}
