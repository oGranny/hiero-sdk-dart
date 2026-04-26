import 'dart:math';

import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:hiero_sdk_dart/src/account/account_id.dart';
import 'package:hiero_sdk_dart/src/hapi/services/basic_types.pb.dart'
    as basic_types;
import 'package:hiero_sdk_dart/src/hapi/services/timestamp.pb.dart'
    as timestamp;

class TransactionId {
  AccountId? _accountId;
  timestamp.Timestamp? _timestamp;
  bool _scheduled;

  TransactionId({
    AccountId? accountId,
    timestamp.Timestamp? timestamp,
    bool scheduled = false,
  }) : _accountId = accountId,
       _timestamp = timestamp,
       _scheduled = scheduled;

  factory TransactionId.generate(AccountId accountId) {
    final List<int> values = [5, 6, 7, 8];
    final int cutoffSeconds = values[Random.secure().nextInt(values.length)];
    final double adjustedTime =
        DateTime.now().millisecondsSinceEpoch / 1000 - cutoffSeconds;
    final int seconds = adjustedTime.floor();
    final int nanos = ((adjustedTime - seconds) * 1e9).floor();
    final timestamp.Timestamp validStart = timestamp.Timestamp(
      seconds: fixnum.Int64(seconds),
      nanos: nanos,
    );
    return TransactionId(
      accountId: accountId,
      timestamp: validStart,
      scheduled: false,
    );
  }

  factory TransactionId.fromString(String transactionIdStr) {
    try {
      bool scheduled = false;
      if (transactionIdStr.contains("?")) {
        final chunks = transactionIdStr.split("?");
        transactionIdStr = chunks[0];
        final String suffix = chunks[1];
        if (suffix != "scheduled") {
          throw ArgumentError(
            'Invalid transaction ID suffix: $suffix, expected "scheduled"',
          );
        }
        scheduled = true;
      }
      if (transactionIdStr.contains("@")) {
        throw ArgumentError('Invalid transaction ID format: $transactionIdStr');
      }
      final (
        String accountIdStr,
        String timestampStr,
      ) = transactionIdStr.split("@").length == 2
          ? (transactionIdStr.split("@")[0], transactionIdStr.split("@")[1])
          : throw ArgumentError(
              'Invalid transaction ID format: $transactionIdStr',
            );
      final accountId = AccountId.fromString(accountIdStr);
      if (timestampStr.contains(".")) {
        throw ArgumentError(
          'Invalid transaction ID format: $transactionIdStr, timestamp should not contain a dot',
        );
      }
      final seconds = int.parse(timestampStr);
      final timestamp.Timestamp validStart = timestamp.Timestamp(
        seconds: fixnum.Int64(seconds),
        nanos: 0,
      );

      return TransactionId(
        accountId: accountId,
        timestamp: validStart,
        scheduled: scheduled,
      );
    } catch (e) {
      throw ArgumentError('Invalid transaction ID string: $transactionIdStr');
    }
  }

  @override
  String toString() {
    return "$_accountId@${_timestamp?.seconds}.${_timestamp?.nanos}${_scheduled ? '?scheduled' : ''}";
  }

  basic_types.TransactionID toProto() {
    final basic_types.TransactionID transactionIdProto =
        basic_types.TransactionID();
    if (_accountId != null) {
      transactionIdProto.accountID = _accountId!.toProto();
    }
    if (_timestamp != null) {
      transactionIdProto.transactionValidStart = _timestamp!;
    }
    if (_scheduled) {
      transactionIdProto.scheduled = true;
    }
    return transactionIdProto;
  }

  factory TransactionId.fromProto(
    basic_types.TransactionID transactionIdProto,
  ) {
    AccountId? accountId = AccountId.fromProto(transactionIdProto.accountID);
    timestamp.Timestamp? timestamp_ = transactionIdProto.transactionValidStart;
    bool scheduled = transactionIdProto.scheduled;
    return TransactionId(
      accountId: accountId,
      timestamp: timestamp_,
      scheduled: scheduled,
    );
  }
}
