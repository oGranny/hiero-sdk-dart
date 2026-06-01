import 'package:hiero_sdk_dart/src/hapi/services/duration.pb.dart'
    as duration_pb;

//TODO: complete implementation
class Duration {
  int seconds;

  Duration(this.seconds);

  factory Duration.fromProto(duration_pb.Duration proto) {
    return Duration(proto.seconds.toInt());
  }
}
