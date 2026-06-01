import 'dart:math';
import 'package:hiero_sdk_dart/src/hapi/services/timestamp.pb.dart'
    as timestamp_pb;

//TODO: complete implementation
class TimeStamp {
  int seconds;
  int nanos;

  TimeStamp(this.seconds, this.nanos);

  factory TimeStamp.generate({hasJitter = true}) {
    int jitter = hasJitter ? Random().nextInt(8000) + 5000 : 0;
    int now = DateTime.now().millisecondsSinceEpoch - jitter;
    int seconds = now ~/ 1000;
    int nanos = (now % 1000) * 1000000 + Random().nextInt(1000000);
    return TimeStamp(seconds, nanos);
  }

  factory TimeStamp.fromProto(timestamp_pb.Timestamp proto) {
    return TimeStamp(proto.seconds.toInt(), proto.nanos);
  }

  @override
  String toString() {
    return '$seconds.$nanos';
  }
}
