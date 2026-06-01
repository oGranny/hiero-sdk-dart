import 'package:hiero_sdk_dart/hiero_sdk_dart.dart';
import 'package:hiero_sdk_dart/src/account/account_info.dart';
import 'package:hiero_sdk_dart/src/channels.dart';
import 'package:hiero_sdk_dart/src/excecutable.dart';
import 'package:hiero_sdk_dart/src/query/query.dart';
import 'package:hiero_sdk_dart/src/hapi/services/response.pb.dart'
    as response_pb;
import 'package:hiero_sdk_dart/src/hapi/services/query.pb.dart' as query_pb;
import 'package:hiero_sdk_dart/src/hapi/services/basic_types.pb.dart'
    as basic_types;
import 'package:hiero_sdk_dart/src/hapi/services/crypto_get_info.pb.dart'
    as crypto_get_info_pb;

class AccountInfoQuery extends Query {
  AccountId? accountId;

  AccountInfoQuery(this.accountId);

  AccountInfoQuery setAccountId(AccountId accountId) {
    this.accountId = accountId;
    return this;
  }

  @override
  Object getQueryResponse(Object response) {
    return (response as response_pb.Response).cryptoGetInfo;
  }

  @override
  Method getMethod(Channel channel) {
    return Method(query: channel.crypto?.getAccountInfo);
  }

  @override
  Future<query_pb.Query> makeRequest() async {
    if (accountId == null) {
      throw StateError("Account ID must be set before making the request.");
    }
    try {
      var queryHeader = await makeRequestHeader();
      var cryptoGetInfoQuery = crypto_get_info_pb.CryptoGetInfoQuery()
        ..header = queryHeader
        ..accountID = accountId!.toProto();
      query_pb.Query query = query_pb.Query()
        ..cryptoGetInfo = cryptoGetInfoQuery;
      return query;
    } catch (e) {
      throw Exception("Failed to make request: $e");
    }
  }

  Future<AccountInfo> execute(Client client, {num? timeout}) async {
    if (accountId == null) {
      throw StateError("Account ID must be set before making the request.");
    }
    await beforeExecute(client);
    final response = await execute_(client, timeout?.toDouble() ?? 120.0);
    final infoResponse = (response as response_pb.Response).cryptoGetInfo;
    return AccountInfo.fromProto(infoResponse.accountInfo);
  }
}
