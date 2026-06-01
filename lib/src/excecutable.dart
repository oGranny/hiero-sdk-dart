import 'dart:math';

import 'package:grpc/grpc.dart' as grpc;
import 'package:hiero_sdk_dart/src/account/account_id.dart';
import 'package:hiero_sdk_dart/src/channels.dart';
import 'package:hiero_sdk_dart/src/client/client.dart';
import 'package:hiero_sdk_dart/src/exceptions.dart';
import 'package:hiero_sdk_dart/src/node.dart';
import 'package:hiero_sdk_dart/src/response_code.dart';

import 'hapi/services/query.pb.dart' as query;

class Method {
  Function? query;
  Function? transaction;

  Method({this.query, this.transaction});
}

enum ExecutionState {
  retry(0),
  finished(1),
  error(2),
  expired(3);

  final int value;
  const ExecutionState(this.value);
}

RegExp rstStream = RegExp(
  r'\brst[^0-9a-zA-Z]stream\b',
  caseSensitive: false,
  dotAll: true,
);

abstract class Executable {
  int? maxAttempts;
  double? maxBackoff;
  double? minBackoff;
  double? grpcDeadline;
  double? requestTimeout;

  AccountId? nodeAccountId;
  List<AccountId> nodeAccountIds = [];

  AccountId? usedNodeAccountId;
  int nodeAccountIdsIndex = 0;

  Executable();

  Executable setNodeAccountIds(List<AccountId> nodeAccountIds) {
    this.nodeAccountIds = nodeAccountIds;
    return this;
  }

  Executable setNodeAccountId(AccountId nodeAccountId) {
    return setNodeAccountIds([nodeAccountId]);
  }

  Executable setMaxAttempts(int maxAttempts) {
    if (maxAttempts < 1) {
      throw ArgumentError('maxAttempts must be at least 1');
    }
    this.maxAttempts = maxAttempts;
    return this;
  }

  Executable setMaxBackoff(num maxBackoff) {
    if (maxBackoff < 0) {
      throw ArgumentError('maxBackoff must be non-negative');
    }
    if (minBackoff != null && maxBackoff < minBackoff!) {
      throw ArgumentError(
        'maxBackoff must be greater than or equal to minBackoff',
      );
    }
    this.maxBackoff = maxBackoff.toDouble();
    return this;
  }

  Executable setMinBackoff(num minBackoff) {
    if (minBackoff < 0) {
      throw ArgumentError('minBackoff must be non-negative');
    }
    if (maxBackoff != null && minBackoff > maxBackoff!) {
      throw ArgumentError(
        'minBackoff must be less than or equal to maxBackoff',
      );
    }
    this.minBackoff = minBackoff.toDouble();
    return this;
  }

  Executable setGrpcDeadline(num grpcDeadline) {
    if (!grpcDeadline.isFinite || grpcDeadline <= 0) {
      throw ArgumentError('grpcDeadline must be a finite value greater than 0');
    }
    this.grpcDeadline = grpcDeadline.toDouble();
    return this;
  }

  Executable setRequestTimeout(num requestTimeout) {
    if (!requestTimeout.isFinite || requestTimeout <= 0) {
      throw ArgumentError(
        'requestTimeout must be a finite value greater than 0',
      );
    }
    this.requestTimeout = requestTimeout.toDouble();
    return this;
  }

  AccountId? selectNodeAccountId() {
    if (nodeAccountIds.isNotEmpty) {
      final AccountId selected =
          nodeAccountIds[nodeAccountIdsIndex % nodeAccountIds.length];
      usedNodeAccountId = selected;
      return selected;
    }
    return null;
  }

  void advanceNodeIndex() {
    if (nodeAccountIds.isNotEmpty) {
      nodeAccountIdsIndex = (nodeAccountIdsIndex + 1);
    }
  }

  ExecutionState shouldRetry(Object response);

  Exception mapStatusError(Object response);

  Future<Object> makeRequest();

  Method getMethod(Channel channel);

  Object mapResponse(Object response, Object nodeId, Object protoRequest);

  String getRequestId() {
    return '$runtimeType:${DateTime.now().millisecondsSinceEpoch}';
  }

  void resolveExcecutionConfig(Client client, num? timeout) {
    requestTimeout ??= timeout?.toDouble();
    final defaults = [
      ("_min_backoff", client.minBackoff),
      ("_max_backoff", client.maxBackoff),
      ("_grpc_deadline", client.grpcDeadline),
      ("_request_timeout", client.requestTimeout),
      ("_max_attempts", client.maxAttempts),
    ];

    for (final (field, value) in defaults) {
      switch (field) {
        case "_min_backoff":
          minBackoff ??= value.toDouble();
          break;
        case "_max_backoff":
          maxBackoff ??= value.toDouble();
          break;
        case "_grpc_deadline":
          grpcDeadline ??= value.toDouble();
          break;
        case "_request_timeout":
          requestTimeout ??= value.toDouble();
          break;
        case "_max_attempts":
          maxAttempts ??= value.toInt();
          break;
      }
    }

    if (nodeAccountIds.isEmpty) {
      nodeAccountIds = [for (Node node in client.network.nodes) node.accountId];
    }
    if (nodeAccountIds.isEmpty) {
      throw ArgumentError('No healthy nodes available for execution');
    }
  }

  bool shouldRetryExponentially(Object error) {
    if (error is grpc.GrpcError) {
      return (error.code == grpc.StatusCode.unavailable ||
              error.code == grpc.StatusCode.deadlineExceeded ||
              error.code == grpc.StatusCode.resourceExhausted) ||
          (error.code == grpc.StatusCode.internal &&
              rstStream.hasMatch(error.message ?? error.toString()));
    }

    return true;
  }

  double calculateBackoff(int attempt) {
    return min(minBackoff!, minBackoff! * pow(2, attempt + 1).toDouble());
  }

  Future<bool> handleUnhealthyNode(
    Object protoRequest,
    int attempt,
    Object? error,
  ) async {
    if (isTransactionOrQuery(protoRequest)) {
      await delayForAttempt(getRequestId(), minBackoff ?? 0.0, attempt, error);
    }
    return true;
  }

  Future<Object> execute_(Client client, double timeout) async {
    resolveExcecutionConfig(client, timeout);

    Object? errorPersistant;
    final startTime = DateTime.now();

    for (int attempt = 0; attempt < maxAttempts!; attempt++) {
      final elapsed =
          DateTime.now().difference(startTime).inMilliseconds / 1000.0;
      if (elapsed >= timeout) {
        break;
      }

      final AccountId? nodeId = selectNodeAccountId();
      if (nodeId == null) {
        throw StateError('No node selected');
      }

      final Node? node = client.network.getNode(nodeId);
      if (node == null) {
        throw StateError('No node found for node_account_id: $nodeId');
      }

      nodeAccountId = node.accountId;
      final channel = await node.getChannel();

      print(
        "Executing requestId: ${getRequestId()}; nodeAccountId: $nodeAccountId; attempt: ${attempt + 1}; maxAttempts: $maxAttempts;",
      );

      final Method method = getMethod(channel);
      final protoRequest = await makeRequest();

      if (!node.isHealthy()) {
        await handleUnhealthyNode(protoRequest, attempt, errorPersistant);
        continue;
      }

      Object? response;

      try {
        print("Making gRPC call for requestId: ${getRequestId()}");
        response = await excecuteMethod(method, protoRequest, grpcDeadline!);
      } catch (e) {
        if (!shouldRetryExponentially(e)) rethrow;
        client.network.increaseBackoff(node);
        errorPersistant = e;
        print(e);
        advanceNodeIndex();
        // rethrow;
        continue;
      }

      client.network.decreaseBackoff(node);

      final dynamic statusError = mapStatusError(response!);

      final ExecutionState executionState = shouldRetry(response);

      print(
        "$runtimeType status recieved; nodeAccountId: $nodeAccountId; network: ${client.network.network}; executionState: $executionState",
      );

      switch (executionState) {
        case ExecutionState.finished:
          print("$runtimeType finished excecution");
          return mapResponse(response, nodeId, protoRequest);
        case ExecutionState.error:
          throw statusError;
        case ExecutionState.expired:
          return statusError;
        case ExecutionState.retry:
          if (statusError.statusCode == ResponseCode.INVALID_NODE_ACCOUNT) {
            client.network.increaseBackoff(node);
            client.updateNetwork();
          }
          errorPersistant = statusError;
          await delayForAttempt(
            getRequestId(),
            calculateBackoff(attempt),
            attempt,
            errorPersistant,
          );
          advanceNodeIndex();
          continue;
      }
    }

    print(
      "Exceeded maximum attempts for request; requestId: ${getRequestId()}; last exception: $errorPersistant",
    );

    throw MaxAttemptsError(
      'Exceeded max attempts or timeout. Last error: $errorPersistant',
      nodeAccountId.toString(),
      (errorPersistant as Exception?),
    );
  }
}

bool isTransactionOrQuery(Object protoRequest) {
  if (protoRequest is! query.Query) {
    return false;
  }
  return protoRequest.hasTransactionGetReceipt() ||
      protoRequest.hasTransactionGetRecord();
}

Future<void> delayForAttempt(
  String requestId,
  double backoff,
  int attempt,
  Object? error,
) async {
  final dur = Duration(milliseconds: (backoff * 1000).toInt());
  print(
    "Retrying request attempt requestId $requestId, attempt $attempt delay ${backoff.toStringAsFixed(2)} error: $error",
  );
  await Future.delayed(dur);
}

Future<Object?> excecuteMethod(
  Method method,
  Object protoRequest,
  double timeout,
) async {
  final grpc.CallOptions options = grpc.CallOptions(
    timeout: Duration(milliseconds: (timeout * 1000).round()),
  );
  if (method.transaction != null) {
    return await method.transaction!(protoRequest, options: options);
  } else if (method.query != null) {
    return await method.query!(protoRequest, options: options);
  }
  throw StateError('Method has no transaction or query function');
}
