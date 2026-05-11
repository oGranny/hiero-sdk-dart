import 'dart:convert';
import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:cryptography/cryptography.dart';
import 'package:hiero_sdk_dart/src/node.dart';
import 'package:test/test.dart';

void main() {
  group('HederaTrustManager unit tests', () {
    test('testTrustManagerInitWithCertHash', () {
      final certHash = utf8.encode('hiero123dart456');
      final trustManager = HederaTrustManager(certHash, true);
      expect(utf8.decode(trustManager.certHash!), 'hiero123dart456');
    });

    test('testTrustManagerInitWithUtf8HexString', () {
      final certHash = utf8.encode('hiero123dart456');
      final trustManager = HederaTrustManager(certHash, true);
      expect(utf8.decode(trustManager.certHash!), 'hiero123dart456');
    });

    test('testTrustManagerInitWithoutCertHashVerificationDisabled', () {
      final trustManager = HederaTrustManager(null, false);
      expect(trustManager.certHash, isNull);
    });

    test('testTrustManagerInitWithoutCertHashVerificationEnabled', () {
      expect(
        () => HederaTrustManager(null, true),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('no applicable address book was found'),
          ),
        ),
      );
    });

    test('testTrustManagerInitWithEmptyCertHashVerificationEnabled', () {
      expect(
        () => HederaTrustManager(Uint8List(0), true),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('no applicable address book was found'),
          ),
        ),
      );
    });

    test('testTrustManagerCheckServerTrustedMatchingHash', () async {
      final pemCert = utf8.encode(
        '-----BEGIN CERTIFICATE-----\nTEST_CERT\n-----END CERTIFICATE-----\n',
      );
      final hash = await Sha384().hash(pemCert);
      final certHashHex = hex.encode(hash.bytes).toLowerCase();

      final trustManager = HederaTrustManager(utf8.encode(certHashHex), true);
      expect(await trustManager.checkServerTrusted(pemCert), isTrue);
    });

    test('testTrustManagerCheckServerTrustedMismatchedHash', () async {
      final pemCert = utf8.encode(
        '-----BEGIN CERTIFICATE-----\nTEST_CERT\n-----END CERTIFICATE-----\n',
      );
      final wrongHash = utf8.encode('wrong_hash_value');

      final trustManager = HederaTrustManager(wrongHash, true);
      expect(
        () => trustManager.checkServerTrusted(pemCert),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains("Failed to confirm the server's certificate"),
          ),
        ),
      );
    });

    test('testTrustManagerCheckServerTrustedNoVerification', () async {
      final pemCert = utf8.encode(
        '-----BEGIN CERTIFICATE-----\nTEST_CERT\n-----END CERTIFICATE-----\n',
      );

      final trustManager = HederaTrustManager(null, false);
      expect(await trustManager.checkServerTrusted(pemCert), isTrue);
    });

    test('testTrustManagerNormalizeHashWith0xPrefix', () {
      final certHash = utf8.encode('0xhiero123');
      final trustManager = HederaTrustManager(certHash, true);
      expect(utf8.decode(trustManager.certHash!), 'hiero123');
    });

    test('testTrustManagerNormalizeHashLowercase', () {
      final certHash = utf8.encode('ABC123DEF456');
      final trustManager = HederaTrustManager(certHash, true);
      expect(utf8.decode(trustManager.certHash!), 'abc123def456');
    });

    test('testTrustManagerNormalizeHashUnicodeDecodeError', () {
      final certHash = Uint8List.fromList([0xFF, 0xFE, 0xFD]);
      final trustManager = HederaTrustManager(certHash, true);
      // Should fall back to hex encoding
      expect(utf8.decode(trustManager.certHash!), 'fffefd');
    });
  });
}
