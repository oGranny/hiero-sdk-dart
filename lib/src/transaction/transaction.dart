import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:fixnum/fixnum.dart';
import 'package:hiero_sdk_dart/src/account/account_id.dart';
import 'package:hiero_sdk_dart/src/client/client.dart';
import 'package:hiero_sdk_dart/src/crypto/key.dart';
import 'package:hiero_sdk_dart/src/crypto/private_key.dart';
import 'package:hiero_sdk_dart/src/crypto/public_key.dart';
import 'package:hiero_sdk_dart/src/excecutable.dart';
import 'package:hiero_sdk_dart/src/hapi/services/duration.pb.dart' as proto;
import 'package:hiero_sdk_dart/src/hbar.dart';
import 'package:hiero_sdk_dart/src/node.dart';
import 'package:hiero_sdk_dart/src/response_code.dart';
import 'package:hiero_sdk_dart/src/transaction/transaction_id.dart';
import 'package:hiero_sdk_dart/src/exceptions.dart';

import 'package:hiero_sdk_dart/src/hapi/services/basic_types.pb.dart'
    as basic_types;
import 'package:hiero_sdk_dart/src/hapi/services/transaction_response.pb.dart'
    as transaction_response;
import 'package:hiero_sdk_dart/src/hapi/services/transaction.pb.dart'
    as transaction_pb;
import 'package:hiero_sdk_dart/src/hapi/services/transaction_contents.pb.dart'
    as transaction_contents;
import 'package:hiero_sdk_dart/src/transaction/transaction_response.dart';

abstract class Transaction extends Executable {
  TransactionId? transactionId;
  int? transactionFee;
  int transactionValidDuration = 120;
  bool generateRecord = false;
  String memo = '';
  List<dynamic> customFeeLimits =
      []; // TODO: add custom fee limit implementation

  Map<AccountId, Uint8List> transactionBodyBytes = {};
  Map<Uint8List, basic_types.SignatureMap> signatureMap = {};

  Hbar defaultTransactionFee = Hbar(0.02);

  AccountId? operatorAccountId;

  Transaction() : super();

  Key? batchKey;

  @override
  Future<Object> makeRequest() async {
    return toProto();
  }

  @override
  Object mapResponse(Object response, Object nodeId, Object protoRequest) {
    if (protoRequest is! transaction_pb.Transaction) {
      throw StateError(
        "expected Transaction but got ${protoRequest.runtimeType}",
      );
    }

    final hashBytes = protoRequest.signedTransactionBytes.isNotEmpty
        ? protoRequest.signedTransactionBytes
        : protoRequest.bodyBytes;

    final txHash = sha384.convert(hashBytes).bytes;
    TransactionResponse transactionResponse = TransactionResponse();
    transactionResponse.transactionId = transactionId!;
    transactionResponse.nodeId = nodeId as AccountId;
    transactionResponse.hash = Uint8List.fromList(txHash);
    return transactionResponse;
  }

  @override
  ExecutionState shouldRetry(Object response) {
    if (response is! transaction_response.TransactionResponse) {
      throw StateError(
        "expected TransactionResponse but got ${response.runtimeType}",
      );
    }

    final status = response.nodeTransactionPrecheckCode;
    final statusCode = status.value;

    final retryableStatuses = {
      ResponseCode.PLATFORM_TRANSACTION_NOT_CREATED,
      ResponseCode.PLATFORM_NOT_ACTIVE,
      ResponseCode.BUSY,
      ResponseCode.INVALID_NODE_ACCOUNT,
    };

    if (retryableStatuses.contains(statusCode)) {
      return ExecutionState.retry;
    }

    if (statusCode == ResponseCode.TRANSACTION_EXPIRED) {
      return ExecutionState.expired;
    }

    if (statusCode == ResponseCode.OK) {
      return ExecutionState.finished;
    }

    return ExecutionState.error;
  }

  @override
  PrecheckError mapStatusError(Object response) {
    final errorCode = (response as transaction_response.TransactionResponse)
        .nodeTransactionPrecheckCode
        .value;
    return PrecheckError(
      statusOrCode: errorCode,
      transactionId: transactionId!,
    );
  }

  Future<Transaction> sign(PrivateKey privateKey) async {
    requireFrozen();
    final publicKeyBytes = (await privateKey.publicKey()).toBytesRaw();

    for (final bodyBytes in transactionBodyBytes.values) {
      final Uint8List signature = await privateKey.sign(bodyBytes);

      final sigPair = basic_types.SignaturePair(
        pubKeyPrefix: publicKeyBytes,
        ed25519: signature,
      );

      basic_types.SignatureMap sigmap = _getOrCreateSignatureMap(bodyBytes);

      bool alreadySigned = false;
      for (final sig in sigmap.sigPair) {
        if (_listEquals(sig.pubKeyPrefix, publicKeyBytes)) {
          alreadySigned = true;
          break;
        }
      }

      if (!alreadySigned) {
        sigmap.sigPair.add(sigPair);
      }
    }
    return this;
  }

  basic_types.SignatureMap _getOrCreateSignatureMap(Uint8List bodyBytes) {
    for (final entry in signatureMap.entries) {
      if (_listEquals(entry.key, bodyBytes)) {
        return entry.value;
      }
    }
    final newSigMap = basic_types.SignatureMap();
    signatureMap[bodyBytes] = newSigMap;
    return newSigMap;
  }

  basic_types.SignatureMap? _getSignatureMap(Uint8List bodyBytes) {
    for (final entry in signatureMap.entries) {
      if (_listEquals(entry.key, bodyBytes)) {
        return entry.value;
      }
    }
    return null;
  }

  bool isSignedBy(PublicKey publicKey) {
    final publicKeyBytes = publicKey.toBytesRaw();
    for (final sigmap in signatureMap.values) {
      bool found = false;
      for (final sig in sigmap.sigPair) {
        if (_listEquals(sig.pubKeyPrefix, publicKeyBytes)) {
          found = true;
          break;
        }
      }
      if (found) return true;
    }
    return false;
  }

  bool _listEquals(List<int>? a, List<int>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  transaction_pb.Transaction toProto() {
    requireFrozen();
    final bodyBytes = transactionBodyBytes[nodeAccountId];
    if (bodyBytes == null) {
      throw StateError("Transaction is not frozen for node $nodeAccountId.");
    }

    final sigMap = _getSignatureMap(bodyBytes) ?? basic_types.SignatureMap();

    final signedTransaction = transaction_contents.SignedTransaction()
      ..bodyBytes = bodyBytes
      ..sigMap = sigMap;

    return transaction_pb.Transaction()
      ..signedTransactionBytes = signedTransaction.writeToBuffer();
  }

  Future<Transaction> freeze() async {
    if (transactionBodyBytes.isNotEmpty) {
      return this;
    }
    if (transactionId == null) {
      throw StateError(
        'Transaction ID must be set before freezing the transaction.',
      );
    }

    if (nodeAccountId == null && nodeAccountIds.isEmpty) {
      throw StateError(
        'Node account ID must be set before freezing the transaction.',
      );
    }

    if (nodeAccountId != null) {
      setNodeAccountId(nodeAccountId!);
      transactionBodyBytes[nodeAccountId!] = (await buildTransactionBody())
          .writeToBuffer();
      return this;
    }

    for (final nodeId in nodeAccountIds) {
      nodeAccountId = nodeId;
      transactionBodyBytes[nodeId] = (await buildTransactionBody())
          .writeToBuffer();
    }
    return this;
  }

  Future<Transaction> freezeWith(Client client) async {
    if (transactionBodyBytes.isNotEmpty) {
      return this;
    }

    transactionId ??= client.generateTransactionId();

    if (batchKey != null) {
      nodeAccountId = AccountId();
      transactionBodyBytes[nodeAccountId!] = (await buildTransactionBody())
          .writeToBuffer();
      return this;
    }

    if (nodeAccountId != null) {
      setNodeAccountId(nodeAccountId!);
      transactionBodyBytes[nodeAccountId!] = (await buildTransactionBody())
          .writeToBuffer();
      return this;
    }

    if (nodeAccountIds.isNotEmpty) {
      for (final nodeId in nodeAccountIds) {
        nodeAccountId = nodeId;
        transactionBodyBytes[nodeId] = (await buildTransactionBody())
            .writeToBuffer();
      }
    } else {
      for (final Node node in client.network.nodes) {
        nodeAccountId = node.accountId;
        transactionBodyBytes[nodeAccountId!] = (await buildTransactionBody())
            .writeToBuffer();
      }
    }

    return this;
  }

  Future<Object> execute(
    Client client, {
    num? timeout,
    bool waitForReceipt = true,
    bool validateStatus = false,
  }) async {
    if (transactionBodyBytes.isEmpty) {
      await freezeWith(client);
    }
    operatorAccountId ??= client.operatorAccountId;
    if (!isSignedBy(await (client.operatorPrivateKey!.publicKey()))) {
      await sign(client.operatorPrivateKey!);
    }

    final response = await execute_(client, timeout?.toDouble() ?? 30.0);
    (response as TransactionResponse).validateStatus = true;
    response.transaction = this;
    response.transactionId = transactionId!;

    if (waitForReceipt) {
      return await response.getReceipt(
        client,
        timeout: timeout,
        validateStatus: validateStatus,
      );
    }
    return response;
  }

  void requireFrozen() {
    if (transactionBodyBytes.isEmpty) {
      throw Exception('Transaction is not frozen');
    }
  }

  void requireNotFrozen() {
    if (transactionBodyBytes.isNotEmpty) {
      throw Exception('Transaction is already frozen');
    }
  }

  Future<transaction_pb.TransactionBody> buildTransactionBody();

  transaction_pb.TransactionBody buildBaseTransactionBody() {
    if (transactionId == null) {
      if (operatorAccountId == null) {
        throw StateError("Operator account ID is not set.");
      }
      transactionId = TransactionId.generate(operatorAccountId!);
    }

    final selectedNode =
        nodeAccountId ?? (nodeAccountIds.isNotEmpty ? nodeAccountIds[0] : null);
    if (selectedNode == null) {
      throw StateError("Node account ID is not set.");
    }

    final body = transaction_pb.TransactionBody();
    body.transactionID = transactionId!.toProto();
    body.nodeAccountID = selectedNode.toProto();

    final fee = transactionFee ?? defaultTransactionFee.toTinybars().toInt();
    body.transactionFee = Int64(fee);

    // Assuming Duration message is available for this
    body.transactionValidDuration = proto.Duration(
      seconds: Int64(transactionValidDuration),
    );
    body.generateRecord = generateRecord;
    body.memo = memo;

    //TODO: Custom fee limits and batch key logic

    return body;
  }

  Transaction setTransactionMemo(String memo) {
    requireNotFrozen();
    this.memo = memo;
    return this;
  }
}
