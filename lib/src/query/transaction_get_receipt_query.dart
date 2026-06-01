import 'package:hiero_sdk_dart/src/channels.dart';
import 'package:hiero_sdk_dart/src/client/client.dart';
import 'package:hiero_sdk_dart/src/exceptions.dart';
import 'package:hiero_sdk_dart/src/excecutable.dart';
import 'package:hiero_sdk_dart/src/query/query.dart';
import 'package:hiero_sdk_dart/src/response_code.dart';
import 'package:hiero_sdk_dart/src/transaction/transaction_id.dart';
import 'package:hiero_sdk_dart/src/transaction/transaction_receipt.dart';

import 'package:hiero_sdk_dart/src/hapi/services/query.pb.dart' as query_pb;
import 'package:hiero_sdk_dart/src/hapi/services/response.pb.dart'
    as response_pb;
import 'package:hiero_sdk_dart/src/hapi/services/query_header.pb.dart'
    as query_header_pb;
import 'package:hiero_sdk_dart/src/hapi/services/transaction_get_receipt.pb.dart'
    as transaction_get_receipt_pb;
import 'package:hiero_sdk_dart/src/hapi/services/transaction_receipt.pb.dart'
    as transaction_receipt_pb;

class TransactionGetReceiptQuery extends Query {
  TransactionId? transactionId;
  bool includeChildren = false;
  bool includeDuplicates = false;
  bool validateStatus = false;
  bool _frozen;

  TransactionGetReceiptQuery({
    this.transactionId,
    this.includeChildren = false,
    this.includeDuplicates = false,
    this.validateStatus = false,
  }) : _frozen = false;

  void requireNotFrozen() {
    if (_frozen) {
      throw StateError("Query is frozen and cannot be modified.");
    }
  }

  TransactionGetReceiptQuery setTransactionId(TransactionId transactionId) {
    requireNotFrozen();
    this.transactionId = transactionId;
    return this;
  }

  TransactionGetReceiptQuery setIncludeChildren(bool includeChildren) {
    requireNotFrozen();
    this.includeChildren = includeChildren;
    return this;
  }

  TransactionGetReceiptQuery setIncludeDuplicates(bool includeDuplicates) {
    requireNotFrozen();
    this.includeDuplicates = includeDuplicates;
    return this;
  }

  TransactionGetReceiptQuery setValidateStatus(bool validateStatus) {
    requireNotFrozen();
    this.validateStatus = validateStatus;
    return this;
  }

  @override
  Future<query_pb.Query> makeRequest() async {
    if (transactionId == null) {
      throw StateError("Transaction ID must be set before making the request.");
    }

    final queryHeader = query_header_pb.QueryHeader();
    queryHeader.responseType = query_header_pb.ResponseType.ANSWER_ONLY;

    final transactionGetReceipt =
        transaction_get_receipt_pb.TransactionGetReceiptQuery();
    transactionGetReceipt.header = queryHeader;
    transactionGetReceipt.transactionID = transactionId!.toProto();
    transactionGetReceipt.includeChildReceipts = includeChildren;
    transactionGetReceipt.includeDuplicates = includeDuplicates;

    final query = query_pb.Query();
    query.transactionGetReceipt = transactionGetReceipt;

    return query;
  }

  @override
  Method getMethod(Channel channel) {
    return Method(query: channel.crypto!.getTransactionReceipts);
  }

  @override
  Object getQueryResponse(Object response) {
    return (response as response_pb.Response).transactionGetReceipt;
  }

  @override
  bool isPaymentRequired() {
    return false;
  }

  @override
  ExecutionState shouldRetry(Object response) {
    final resp = (response as response_pb.Response).transactionGetReceipt;
    final status = resp.header.nodeTransactionPrecheckCode.value;

    final retryableStatuses = {
      ResponseCode.UNKNOWN,
      ResponseCode.BUSY,
      ResponseCode.RECEIPT_NOT_FOUND,
      ResponseCode.RECORD_NOT_FOUND,
      ResponseCode.PLATFORM_NOT_ACTIVE,
    };

    if (status == ResponseCode.OK) {
    } else if (retryableStatuses.contains(status)) {
      return ExecutionState.retry;
    } else {
      return ExecutionState.error;
    }

    final receiptStatus = resp.receipt.status.value;

    if (retryableStatuses.contains(receiptStatus) ||
        receiptStatus == ResponseCode.OK) {
      return ExecutionState.retry;
    }
    if (receiptStatus == ResponseCode.SUCCESS) {
      return ExecutionState.finished;
    }
    if (validateStatus) {
      return ExecutionState.error;
    }
    return ExecutionState.finished;
  }

  @override
  Exception mapStatusError(Object response) {
    final resp = (response as response_pb.Response).transactionGetReceipt;
    final status = resp.header.nodeTransactionPrecheckCode.value;

    final retryableStatuses = {
      ResponseCode.PLATFORM_TRANSACTION_NOT_CREATED,
      ResponseCode.BUSY,
      ResponseCode.UNKNOWN,
      ResponseCode.OK,
    };

    if (!retryableStatuses.contains(status)) {
      return PrecheckError(statusOrCode: status);
    }

    final receiptStatus = resp.receipt.status.value;

    return ReceiptStatusError(
      receiptStatus,
      transactionId,
      TransactionReceipt(resp.receipt, transactionId),
      null,
    );
  }

  List<TransactionReceipt> mapRecieptList(
    List<transaction_receipt_pb.TransactionReceipt> reciepts, {
    bool includeParentTx = false,
  }) {
    final txid = includeParentTx ? transactionId : null;
    return [
      for (final recieptProto in reciepts)
        TransactionReceipt.fromProto(recieptProto, txid),
    ];
  }

  TransactionGetReceiptQuery freeze() {
    _frozen = true;
    return this;
  }

  Future<TransactionReceipt> execute(Client client, {num? timeout}) async {
    await beforeExecute(client);
    final dynamic response = await execute_(
      client,
      timeout?.toDouble() ?? 120.0,
    );
    final parent = TransactionReceipt.fromProto(
      response.transactionGetReceipt.receipt,
      transactionId,
    );

    List<TransactionReceipt> children;

    if (includeChildren) {
      children = mapRecieptList(
        response.transactionGetReceipt.childTransactionReceipts,
        includeParentTx: false,
      );
      parent.children = children;
    }

    if (includeDuplicates) {
      parent.duplicates = mapRecieptList(
        response.transactionGetReceipt.duplicateTransactionReceipts,
        includeParentTx: true,
      );
    }
    return parent;
  }
}
