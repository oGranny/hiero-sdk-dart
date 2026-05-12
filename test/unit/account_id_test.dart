import 'package:fixnum/fixnum.dart';
import 'package:hiero_sdk_dart/src/account/account_id.dart';
import 'package:hiero_sdk_dart/src/crypto/private_key.dart';
import 'package:hiero_sdk_dart/src/crypto/public_key.dart';
import 'package:hiero_sdk_dart/src/hapi/services/basic_types.pb.dart'
    as basic_types;
import 'package:test/test.dart';

void main() {
  group('AccountId unit tests', () {
    late PublicKey aliasKey;
    late PublicKey aliasKey2;

    setUp(() async {
      final priv1 = await PrivateKey.generateEd25519();
      aliasKey = await priv1.publicKey();
      final priv2 = await PrivateKey.generateEd25519();
      aliasKey2 = await priv2.publicKey();
    });

    test('testDefaultInitialization', () {
      final accountId = AccountId();
      expect(accountId.shard, 0);
      expect(accountId.realm, 0);
      expect(accountId.num, 0);
      expect(accountId.checksum, isNull);
    });

    test('testCustomInitialization', () {
      final accountId = AccountId(shard: 1, realm: 2, num: 3);
      expect(accountId.shard, 1);
      expect(accountId.realm, 2);
      expect(accountId.num, 3);
    });

    test('testInitializationWithAliasKey', () {
      final accountId = AccountId(aliasKey: aliasKey);
      expect(accountId.shard, 0);
      expect(accountId.realm, 0);
      expect(accountId.num, 0);
      expect(accountId.aliasKey, equals(aliasKey));
    });

    test('testStrRepresentation', () {
      final accountId = AccountId(num: 100);
      expect(accountId.toString(), '0.0.100');
    });

    test('testStrRepresentationWithAliasKey', () {
      final accountId = AccountId(aliasKey: aliasKey);
      final expected = '0.0.${aliasKey.toString()}';
      expect(accountId.toString(), expected);
    });

    test('testFromStringValid', () {
      final accountId = AccountId.fromString('0.0.100');
      expect(accountId.shard, 0);
      expect(accountId.realm, 0);
      expect(accountId.num, 100);
      expect(accountId.checksum, isNull);
    });

    test('testFromStringWithChecksum', () {
      final accountId = AccountId.fromString('0.0.100-abcde');
      expect(accountId.shard, 0);
      expect(accountId.realm, 0);
      expect(accountId.num, 100);
      expect(accountId.checksum, 'abcde');
    });

    test('testFromStringWithAlias', () {
      final aliasStr = aliasKey
          .toBytesRaw()
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      final accountIdStr = '0.0.$aliasStr';
      final accountId = AccountId.fromString(accountIdStr);

      expect(accountId.shard, 0);
      expect(accountId.realm, 0);
      expect(accountId.num, 0);
      expect(accountId.aliasKey, equals(aliasKey));
    });

    test('testFromStringInvalidFormat', () {
      final invalidIds = [
        '1.2',
        '1.2.3.4',
        'a.b.c',
        '',
        '1.a.3',
        '0.0.-1',
        'abc.def.ghi',
        '0.0.1 - abcde',
      ];

      for (final id in invalidIds) {
        expect(() => AccountId.fromString(id), throwsArgumentError);
      }
    });

    test('testToProto', () {
      final accountId = AccountId(num: 100);
      final proto = accountId.toProto();

      expect(proto, isA<basic_types.AccountID>());
      expect(proto.shardNum.toInt(), 0);
      expect(proto.realmNum.toInt(), 0);
      expect(proto.accountNum.toInt(), 100);
      expect(proto.alias, isEmpty);
    });

    test('testToProtoWithAliasKey', () {
      final accountId = AccountId(aliasKey: aliasKey);
      final proto = accountId.toProto();

      expect(proto.shardNum.toInt(), 0);
      expect(proto.realmNum.toInt(), 0);
      expect(proto.accountNum.toInt(), 0);
      expect(proto.alias, isNotEmpty);

      final keyProto = basic_types.Key.fromBuffer(proto.alias);
      expect(keyProto.ed25519, isNotEmpty);
    });

    test('testFromProto', () {
      final proto = basic_types.AccountID()
        ..shardNum = Int64(0)
        ..realmNum = Int64(0)
        ..accountNum = Int64(100);

      final accountId = AccountId.fromProto(proto);
      expect(accountId.shard, 0);
      expect(accountId.realm, 0);
      expect(accountId.num, 100);
    });

    test('testFromProtoWithAlias', () {
      final aliasBytes = aliasKey.toProto().writeToBuffer();
      final proto = basic_types.AccountID()
        ..shardNum = Int64(0)
        ..realmNum = Int64(0)
        ..accountNum = Int64(0)
        ..alias = aliasBytes;

      final accountId = AccountId.fromProto(proto);
      expect(accountId.shard, 0);
      expect(accountId.realm, 0);
      expect(accountId.num, 0);
      expect(accountId.aliasKey, equals(aliasKey));
    });

    test('testRoundtripProtoConversion', () {
      final original = AccountId(shard: 1, realm: 2, num: 3);
      final reconstructed = AccountId.fromProto(original.toProto());

      expect(reconstructed.shard, original.shard);
      expect(reconstructed.realm, original.realm);
      expect(reconstructed.num, original.num);
    });

    test('testRoundtripProtoConversionWithAlias', () {
      final original = AccountId(aliasKey: aliasKey);
      final reconstructed = AccountId.fromProto(original.toProto());

      expect(reconstructed.shard, original.shard);
      expect(reconstructed.realm, original.realm);
      expect(reconstructed.num, original.num);
      expect(reconstructed.aliasKey, equals(aliasKey));
    });

    test('testToBytesAndFromBytesRoundtrip', () {
      final original = AccountId(num: 100);
      final reconstructed = AccountId.fromBytes(original.toBytes);

      expect(reconstructed.shard, original.shard);
      expect(reconstructed.realm, original.realm);
      expect(reconstructed.num, original.num);
    });

    test('testToBytesAndFromBytesWithAliasKey', () {
      final original = AccountId(aliasKey: aliasKey);
      final reconstructed = AccountId.fromBytes(original.toBytes);

      expect(reconstructed.shard, original.shard);
      expect(reconstructed.realm, original.realm);
      expect(reconstructed.num, original.num);
      expect(reconstructed.aliasKey, equals(aliasKey));
    });

    test('testEquality', () {
      final a1 = AccountId(num: 100);
      final a2 = AccountId(num: 100);
      final a3 = AccountId(num: 101);

      expect(a1 == a2, isTrue);
      expect(a1 == a3, isFalse);
    });

    test('testEqualityWithAliasKey', () {
      final a1 = AccountId(aliasKey: aliasKey);
      final a2 = AccountId(aliasKey: aliasKey);
      final a3 = AccountId(aliasKey: aliasKey2);

      expect(a1 == a2, isTrue);
      expect(a1 == a3, isFalse);
    });

    test('testHash', () {
      final a1 = AccountId(num: 100);
      final a2 = AccountId(num: 100);
      final a3 = AccountId(num: 101);

      expect(a1.hashCode, a2.hashCode);
      expect(a1.hashCode, isNot(a3.hashCode));
    });
  });
}
