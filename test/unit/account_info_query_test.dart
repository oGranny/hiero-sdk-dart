import 'package:hiero_sdk_dart/hiero_sdk_dart.dart';
import 'package:hiero_sdk_dart/src/channels.dart';
import 'package:hiero_sdk_dart/src/hapi/services/crypto_service.pbgrpc.dart';
import 'package:grpc/grpc.dart' as $grpc;
import 'package:hiero_sdk_dart/src/hapi/services/query.pb.dart' as $query;
import 'package:hiero_sdk_dart/src/hapi/services/response.pb.dart' as $response;
import 'package:test/test.dart';

class FakeClientChannel implements $grpc.ClientChannel {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class MockChannel extends Channel {
  final CryptoServiceClient? _mockCrypto;

  MockChannel(this._mockCrypto) : super(FakeClientChannel());

  @override
  CryptoServiceClient? get crypto => _mockCrypto;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCrypto implements CryptoServiceClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();

  @override
  $grpc.ResponseFuture<$response.Response> getAccountInfo(
    $query.Query request, {
    $grpc.CallOptions? options,
  }) {
    throw UnimplementedError();
  }
}

class MockClient extends Client {
  final Operator? _mockOperator;

  MockClient({Operator? operator}) : _mockOperator = operator, super();

  @override
  Operator? get operator => _mockOperator;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AccountInfoQuery unit tests', () {
    test('testConstructor', () {
      final accountId = AccountId(num: 2);
      final query = AccountInfoQuery(accountId);
      expect(query.accountId, equals(accountId));
    });

    test('testSetAccountId', () {
      final accountId = AccountId(num: 2);
      final query = AccountInfoQuery(null);
      query.setAccountId(accountId);
      expect(query.accountId, equals(accountId));
    });

    test('testExecuteFailsWithMissingAccountId', () async {
      final query = AccountInfoQuery(null);
      final client = MockClient();

      expect(
        () => query.execute(client),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Account ID must be set before making the request'),
          ),
        ),
      );
    });

    test('testMakeRequest', () async {
      final accountId = AccountId(num: 2);
      final query = AccountInfoQuery(accountId);
      final privKey = await PrivateKey.generateEd25519();
      final client = MockClient(operator: Operator(AccountId(num: 1234), privKey));

      // We need to set nodeAccountId for makeRequestHeader
      query.nodeAccountId = AccountId(num: 3);

      final request = await query.makeRequest();
      expect(request, isA<$query.Query>());
      expect(request.hasCryptoGetInfo(), isTrue);
      expect(request.cryptoGetInfo.accountID.accountNum.toInt(), 2);
    });

    test('testGetMethod', () {
      final query = AccountInfoQuery(null);
      final fakeCrypto = FakeCrypto();
      final mockChannel = MockChannel(fakeCrypto);

      final method = query.getMethod(mockChannel);

      expect(method.transaction, isNull);
      expect(method.query, equals(fakeCrypto.getAccountInfo));
    });
  });
}
