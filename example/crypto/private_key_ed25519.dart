import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:hiero_sdk_dart/src/crypto/private_key.dart';

Future<void> exampleGenerateEd25519() async {
  print('=== Ed25519: Generate & Sign ===');

  final privKey = await PrivateKey.generate('ed25519');
  final privateHex = await privKey.toStringEd25519Raw();
  print('Generated Ed25519 PrivateKey (hex) = $privateHex');

  final pubKey = await privKey.publicKey();
  print('Derived public key = ${pubKey.toStringEd25519()}');

  final data = Uint8List.fromList('hello ed25519!'.codeUnits);
  final signature = await privKey.sign(data);
  print('Signature (hex) = ${hex.encode(signature)}');

  try {
    pubKey.verifyEd25519(data, signature);
    print('Signature is VALID (Ed25519)!');
  } catch (_) {
    print('Signature is INVALID (Ed25519)!');
  }

  print('');
}

Future<void> exampleLoadEd25519Raw() async {
  print('=== Ed25519: Load from Raw ===');

  final rawSeedHex = List.filled(32, '01').join();
  final rawSeed = Uint8List.fromList(hex.decode(rawSeedHex));

  final privKey = await PrivateKey.fromBytesEd25519(rawSeed);
  final privateHex = await privKey.toStringEd25519Raw();
  print('Loaded Ed25519 PrivateKey from raw seed = $privateHex');

  final pubKey = await privKey.publicKey();
  final data = Uint8List.fromList('Ed25519 from raw'.codeUnits);
  final signature = await privKey.sign(data);

  try {
    pubKey.verifyEd25519(data, signature);
    print('Signature valid with Ed25519 from raw seed!');
  } catch (_) {
    print('Signature invalid?!');
  }

  print('');
}

Future<void> exampleLoadEd25519FromHex() async {
  print('=== Ed25519: Load from Hex ===');

  final edHex = List.filled(16, 'a1').join() + List.filled(16, 'b2').join();

  final privKey = await PrivateKey.fromStringEd25519(edHex);
  final privateHex = await privKey.toStringEd25519Raw();
  print('Loaded Ed25519 PrivateKey from hex = $privateHex');

  final pubKey = await privKey.publicKey();
  final data = Uint8List.fromList('Test data'.codeUnits);
  final signature = await privKey.sign(data);

  try {
    pubKey.verifyEd25519(data, signature);
    print('Ed25519 signature valid with hex-loaded key!');
  } catch (_) {
    print('Signature invalid?!');
  }

  print('');
}

Future<void> main() async {
  await exampleGenerateEd25519();
  await exampleLoadEd25519Raw();
  await exampleLoadEd25519FromHex();
}
