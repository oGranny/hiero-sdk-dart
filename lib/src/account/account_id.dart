import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:hiero_sdk_dart/src/client/client.dart';
import 'package:hiero_sdk_dart/src/crypto/public_key.dart';
import 'package:hiero_sdk_dart/src/utils/entity_id_helper.dart' as utils;
import 'package:hiero_sdk_dart/src/hapi/services/basic_types.pb.dart'
    as basic_types;

final RegExp aliasRegex = RegExp(
  r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.((?:[0-9a-fA-F][0-9a-fA-F])+)$',
);

class AccountId {
  final int _shard;
  final int _realm;
  final int _num;
  PublicKey? aliasKey;
  String? _checksum;

  AccountId({int? shard, int? realm, int? num, this.aliasKey, String? checksum})
    : _shard = shard ?? 0,
      _realm = realm ?? 0,
      _num = num ?? 0,
      _checksum = checksum;

  factory AccountId.fromString(String accountIdStr) {
    try {
      final (String shard, String realm, String num, String? checksum) = utils
          .parseFromString(accountIdStr);
      AccountId accountId = AccountId(
        shard: int.parse(shard),
        realm: int.parse(realm),
        num: int.parse(num),
        checksum: checksum,
      );
      return accountId;
    } catch (e) {
      final aliasMatch = aliasRegex.firstMatch(accountIdStr);
      if (aliasMatch != null) {
        final shard = int.parse(aliasMatch.group(1)!);
        final realm = int.parse(aliasMatch.group(2)!);
        final alias = aliasMatch.group(3)!;
        final aliasBytes = Uint8List.fromList(hex.decode(alias));
        final aliasKey = PublicKey.fromBytes(aliasBytes);
        return AccountId(
          shard: shard,
          realm: realm,
          num: 0,
          aliasKey: aliasKey,
        );
      }
      throw ArgumentError(
        'Invalid account ID string: $accountIdStr',
        "Supported formats: "
            "'shard.realm.num', "
            "'shard.realm.num-checksum', "
            "'shard.realm.<hex-alias>', "
            "or a 20-byte EVM address.",
      );
    }
  }

  factory AccountId.fromBytes(Uint8List bytes) {
    return AccountId.fromProto(basic_types.AccountID.fromBuffer(bytes));
  }

  factory AccountId.fromProto(basic_types.AccountID accountIdProto) {
    AccountId res = AccountId(
      shard: accountIdProto.shardNum.toInt(),
      realm: accountIdProto.realmNum.toInt(),
      num: accountIdProto.accountNum.toInt(),
    );
    List<int> alias = accountIdProto.alias;
    if (alias.isNotEmpty) {
      final keyProto = basic_types.Key()..mergeFromBuffer(alias);
      if (keyProto.ed25519.isNotEmpty) {
        res.aliasKey = PublicKey.fromProto(keyProto);
      }
    }
    return res;
  }

  basic_types.AccountID toProto() {
    basic_types.AccountID accountIdProto = basic_types.AccountID(
      shardNum: fixnum.Int64(_shard),
      realmNum: fixnum.Int64(_realm),
      accountNum: fixnum.Int64(_num),
    );
    if (aliasKey != null) {
      Uint8List key = aliasKey!.toProto().writeToBuffer();
      accountIdProto.alias = key;
    }
    return accountIdProto;
  }

  int get shard => _shard;
  int get realm => _realm;
  int get num => _num;

  String? get checksum => _checksum;
  Uint8List get toBytes => toProto().writeToBuffer();

  @override
  String toString() {
    if (aliasKey != null) return '$_shard.$_realm.${aliasKey.toString()}';
    return '$_shard.$_realm.$_num';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AccountId) return false;
    return _shard == other._shard &&
        _realm == other._realm &&
        _num == other._num &&
        aliasKey == other.aliasKey;
  }

  @override
  int get hashCode => Object.hash(_shard, _realm, _num, aliasKey);

  void validateChecksum(Client client) {
    if (_checksum == null) {
      throw StateError('Checksum is not set for account ID: $this');
    }
    utils.validateChecksum(_shard, _realm, _num, _checksum!, client);
  }
}
