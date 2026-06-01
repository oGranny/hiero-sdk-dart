import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:hiero_sdk_dart/src/account/account_id.dart';
import 'package:hiero_sdk_dart/src/channels.dart';
import 'package:hiero_sdk_dart/src/client/client.dart';
import 'package:hiero_sdk_dart/src/crypto/private_key.dart';
import 'package:hiero_sdk_dart/src/excecutable.dart';
import 'package:hiero_sdk_dart/src/exceptions.dart';
import 'package:hiero_sdk_dart/src/hbar.dart';

import 'package:hiero_sdk_dart/src/hapi/services/basic_types.pb.dart'
    as basic_types;
import 'package:hiero_sdk_dart/src/hapi/services/query.pb.dart' as query_pb;
import 'package:hiero_sdk_dart/src/hapi/services/query_header.pb.dart'
    as query_header_pb;
import 'package:hiero_sdk_dart/src/hapi/services/transaction.pb.dart'
    as transaction_pb;
import 'package:hiero_sdk_dart/src/hapi/services/duration.pb.dart'
    as duration_pb;
import 'package:hiero_sdk_dart/src/hapi/services/crypto_transfer.pb.dart'
    as crypto_transfer_pb;
import 'package:hiero_sdk_dart/src/hapi/services/transaction_contents.pb.dart'
    as transaction_contents_pb;
import 'package:hiero_sdk_dart/src/response_code.dart';
import 'package:hiero_sdk_dart/src/transaction/transaction_id.dart';

abstract class Query extends Executable {
  int timestamp;
  Operator? operator;
  int nodeIndex;
  Hbar? paymentAmount;
  Hbar? maxQueryPayment;

  Query() : timestamp = DateTime.now().millisecondsSinceEpoch, nodeIndex = 0;

  Object getQueryResponse(Object response);

  Query setQueryPayment(Hbar payment) {
    paymentAmount = payment;
    return this;
  }

  Query setMaxQueryPayment(Object maxPayment) {
    if (maxPayment is! Hbar && maxPayment is! num) {
      throw ArgumentError('maxPayment must be of type Hbar or num');
    }
    maxQueryPayment = (maxPayment is Hbar)
        ? maxPayment
        : Hbar.fromTinybars(maxPayment as int);
    return this;
  }

  Future<void> beforeExecute(Client client) async {
    operator ??= client.operator;
    if (paymentAmount == null && isPaymentRequired()) {
      paymentAmount = await getCost(client);
      final maxPayment = maxQueryPayment ?? client.defaultMaxQueryPaymentAmount;

      if (paymentAmount! > maxPayment) {
        throw Exception(
          'Estimated query cost of \$paymentAmount exceeds the maximum allowed of \$maxPayment. '
          'Please set a higher maxQueryPayment or provide an explicit payment amount.',
        );
      }
    }
  }

  Future<query_header_pb.QueryHeader> makeRequestHeader() async {
    query_header_pb.QueryHeader header = query_header_pb.QueryHeader();
    header.responseType = query_header_pb.ResponseType.ANSWER_ONLY;
    if (!isPaymentRequired()) return header;
    if (paymentAmount == null) {
      header.responseType = query_header_pb.ResponseType.COST_ANSWER;
      return header;
    }

    if (operator != null && nodeAccountId != null && paymentAmount != null) {
      transaction_pb.Transaction paymentTx = await buildQueryPaymentTransaction(
        operator!.accountId,
        operator!.privateKey,
        nodeAccountId!,
        paymentAmount!,
      );

      header.payment = paymentTx;
    }

    return header;
  }

  Future<transaction_pb.Transaction> buildQueryPaymentTransaction(
    AccountId payerAccountId,
    PrivateKey payerPrivateKey,
    AccountId nodeAccountId,
    Hbar amount,
  ) async {
    final List<basic_types.AccountAmount> accountAmounts = [
      basic_types.AccountAmount(
        accountID: nodeAccountId.toProto(),
        amount: Int64(amount.toTinybars()),
      ),
      basic_types.AccountAmount(
        accountID: payerAccountId.toProto(),
        amount: Int64(-amount.toTinybars()),
      ),
    ];

    TransactionId transactionId = TransactionId.generate(payerAccountId);

    transaction_pb.TransactionBody transactionBody =
        transaction_pb.TransactionBody(
          transactionID: transactionId.toProto(),
          nodeAccountID: nodeAccountId.toProto(),
          transactionFee: Int64(Hbar(1).toTinybars()),
          transactionValidDuration: duration_pb.Duration(seconds: Int64(120)),
          cryptoTransfer: crypto_transfer_pb.CryptoTransferTransactionBody(
            transfers: basic_types.TransferList(accountAmounts: accountAmounts),
          ),
        );
    Uint8List bodyBytes = transactionBody.writeToBuffer();

    Uint8List signature = await payerPrivateKey.sign(bodyBytes);
    Uint8List publicKeyBytes = (await payerPrivateKey.publicKey()).toBytesRaw();
    basic_types.SignaturePair sigpair;
    if (payerPrivateKey.isEd25519) {
      sigpair = basic_types.SignaturePair(
        pubKeyPrefix: publicKeyBytes,
        ed25519: signature,
      );
    } else {
      //TODO
      throw UnimplementedError("ECDSA not supported yet");
    }

    basic_types.SignatureMap signsignatureMap = basic_types.SignatureMap(
      sigPair: [sigpair],
    );

    transaction_contents_pb.SignedTransaction signedsignedTransaction =
        transaction_contents_pb.SignedTransaction(
          bodyBytes: bodyBytes,
          sigMap: signsignatureMap,
        );

    return transaction_pb.Transaction(
      signedTransactionBytes: signedsignedTransaction.writeToBuffer(),
    );
  }

  Future<Hbar> getCost(Client client) async {
    if (!isPaymentRequired()) {
      return Hbar.zero;
    }

    if (paymentAmount != null) {
      return paymentAmount!;
    }

    if (client.operator == null) {
      throw StateError('Client and operator must be set to get the cost');
    }

    final resp = await execute_(client, 120);
    final dynamic queryResponse = getQueryResponse(resp);
    return Hbar.fromTinybars(queryResponse.header.cost.toInt());
  }

  bool isPaymentRequired() {
    return true;
  }

  @override
  Method getMethod(Channel channel);

  @override
  Future<query_pb.Query> makeRequest();

  @override
  Object mapResponse(Object response, Object nodeId, Object protoRequest) {
    return response;
  }

  @override
  ExecutionState shouldRetry(Object response) {
    final dynamic queryResponse = getQueryResponse(response);
    final status = queryResponse.header.nodeTransactionPrecheckCode.value;

    List<int> retryablePrecheckCodes = [
      ResponseCode.PLATFORM_TRANSACTION_NOT_CREATED,
      ResponseCode.PLATFORM_NOT_ACTIVE,
      ResponseCode.BUSY,
    ];

    if (retryablePrecheckCodes.contains(status)) {
      return ExecutionState.retry;
    }
    if (status == ResponseCode.OK) {
      return ExecutionState.finished;
    }

    return ExecutionState.error;
  }

  @override
  Exception mapStatusError(Object response) {
    final dynamic queryResponse = getQueryResponse(response);
    final status = queryResponse.header.nodeTransactionPrecheckCode.value;
    return PrecheckError(statusOrCode: status);
  }
}
