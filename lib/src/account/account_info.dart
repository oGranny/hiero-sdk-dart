import 'package:hiero_sdk_dart/src/account/account_id.dart';
import 'package:hiero_sdk_dart/src/crypto/key.dart';
import 'package:hiero_sdk_dart/src/hbar.dart';
import 'package:hiero_sdk_dart/src/timestamp.dart';
import 'package:hiero_sdk_dart/src/duration.dart';
import 'package:hiero_sdk_dart/src/hapi/services/crypto_get_info.pb.dart'
    as crypto_get_info_pb;

// TODO: complete implementation
class AccountInfo {
  AccountInfo();
  AccountId? accountId;
  String? contractAccountId;
  bool? deleted;
  Key? key;
  Hbar? balance;
  Hbar? proxyReceived;
  bool? receiverSignatureRequired;
  TimeStamp? expirationTime;
  Duration? autoRenewPeriod;
  // List<TokenRelationship>? tokenRelationships; // TODO
  String? accountMemo;
  int? ownedNfts;
  int? maxAutomaticTokenAssociations;
  // StakingInfo? stakingInfo; // TODO

  factory AccountInfo.fromProto(
    crypto_get_info_pb.CryptoGetInfoResponse_AccountInfo proto,
  ) {
    return AccountInfo()
      ..accountId = AccountId.fromProto(proto.accountID)
      ..contractAccountId = proto.contractAccountID
      ..deleted = proto.deleted
      ..proxyReceived = Hbar.fromTinybars(proto.proxyReceived.toInt())
      ..key = Key.fromProtoKey(proto.key)
      ..balance = Hbar.fromTinybars(proto.balance.toInt())
      ..receiverSignatureRequired = proto.receiverSigRequired
      ..expirationTime = TimeStamp.fromProto(proto.expirationTime)
      ..autoRenewPeriod = Duration.fromProto(proto.autoRenewPeriod)
      ..accountMemo = proto.memo
      ..ownedNfts = proto.ownedNfts.toInt()
      ..maxAutomaticTokenAssociations = proto.maxAutomaticTokenAssociations;
  }

  @override
  String toString() {
    return 'AccountInfo('
        'accountId: $accountId, '
        'contractAccountId: $contractAccountId, '
        'deleted: $deleted, '
        'key: $key, '
        'balance: $balance, '
        'proxyReceived: $proxyReceived, '
        'receiverSignatureRequired: $receiverSignatureRequired, '
        'expirationTime: $expirationTime, '
        'autoRenewPeriod: ${autoRenewPeriod?.seconds}s, '
        'accountMemo: $accountMemo, '
        'ownedNfts: $ownedNfts, '
        'maxAutomaticTokenAssociations: $maxAutomaticTokenAssociations'
        ')';
  }
}
