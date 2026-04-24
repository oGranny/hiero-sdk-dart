import 'package:grpc/grpc.dart';

import 'hapi/services/file_service.pbgrpc.dart';
import 'hapi/services/address_book_service.pbgrpc.dart';
import 'hapi/services/consensus_service.pbgrpc.dart';
import 'hapi/services/crypto_service.pbgrpc.dart';
import 'hapi/services/freeze_service.pbgrpc.dart';
import 'hapi/services/network_service.pbgrpc.dart';
import 'hapi/services/schedule_service.pbgrpc.dart';
import 'hapi/services/smart_contract_service.pbgrpc.dart';
import 'hapi/services/token_service.pbgrpc.dart';
import 'hapi/services/util_service.pbgrpc.dart';

class Channel {
  final ClientChannel channel;

  CryptoServiceClient? _crypto;
  FileServiceClient? _file;
  NetworkServiceClient? _network;
  SmartContractServiceClient? _smartContract;
  TokenServiceClient? _token;
  ConsensusServiceClient? _topic;
  FreezeServiceClient? _freeze;
  ScheduleServiceClient? _schedule;
  UtilServiceClient? _util;
  AddressBookServiceClient? _addressBook;

  Channel(this.channel);

  CryptoServiceClient? get crypto =>
      channel == null ? null : _crypto ??= CryptoServiceClient(channel);

  FileServiceClient? get file =>
      channel == null ? null : _file ??= FileServiceClient(channel);

  NetworkServiceClient? get network =>
      channel == null ? null : _network ??= NetworkServiceClient(channel);

  SmartContractServiceClient? get smartContract => channel == null
      ? null
      : _smartContract ??= SmartContractServiceClient(channel);

  TokenServiceClient? get token =>
      channel == null ? null : _token ??= TokenServiceClient(channel);

  ConsensusServiceClient? get topic =>
      channel == null ? null : _topic ??= ConsensusServiceClient(channel);

  FreezeServiceClient? get freeze =>
      channel == null ? null : _freeze ??= FreezeServiceClient(channel);

  ScheduleServiceClient? get schedule =>
      channel == null ? null : _schedule ??= ScheduleServiceClient(channel);

  UtilServiceClient? get util =>
      channel == null ? null : _util ??= UtilServiceClient(channel);

  AddressBookServiceClient? get addressBook => channel == null
      ? null
      : _addressBook ??= AddressBookServiceClient(channel);
}
