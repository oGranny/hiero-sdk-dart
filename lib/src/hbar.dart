import 'package:decimal/decimal.dart';

import 'package:hiero_sdk_dart/src/hbar_unit.dart';

final RegExp _fromStringPattern = RegExp(
  r'^((?:\+|\-)?\d+(?:\.\d+)?)(?: (tℏ|μℏ|mℏ|ℏ|kℏ|Mℏ|Gℏ))?$',
);

class Hbar implements Comparable<Hbar> {
  static const Hbar zero = Hbar._fromTinybars(0);
  static const Hbar max = Hbar._fromTinybars(50_000_000_000);
  static const Hbar min = Hbar._fromTinybars(-50_000_000_000);

  const Hbar._fromTinybars(this._amountInTinybars);

  factory Hbar(Object amount, [HbarUnit unit = HbarUnit.hbar]) {
    if (amount is bool ||
        (amount is! int && amount is! double && amount is! Decimal)) {
      throw ArgumentError('Amount must be of type int, double, or Decimal');
    }

    if (amount is double && !amount.isFinite) {
      throw ArgumentError('Hbar amount must be finite');
    }

    if (unit == HbarUnit.tinybar) {
      if (amount is! int) {
        throw ArgumentError('Fractional tinybar value not allowed');
      }
      return Hbar._fromTinybars(amount);
    }

    final Decimal decimalAmount = amount is Decimal
        ? amount
        : Decimal.parse(amount.toString());
    final Decimal tinybars = decimalAmount * Decimal.fromInt(unit.tinybars);

    if (!tinybars.isInteger) {
      throw ArgumentError('Fractional tinybar value not allowed');
    }

    return Hbar._fromTinybars(tinybars.toBigInt().toInt());
  }

  final int _amountInTinybars;

  factory Hbar.of(Object amount, HbarUnit unit) => Hbar(amount, unit);

  factory Hbar.fromTinybars(int tinybars) => Hbar._fromTinybars(tinybars);

  factory Hbar.fromMicrobars(Object amount) => Hbar(amount, HbarUnit.microbar);

  factory Hbar.fromMillibars(Object amount) => Hbar(amount, HbarUnit.millibar);

  factory Hbar.fromHbars(Object amount) => Hbar(amount, HbarUnit.hbar);

  factory Hbar.fromKilobars(Object amount) => Hbar(amount, HbarUnit.kilobar);

  factory Hbar.fromMegabars(Object amount) => Hbar(amount, HbarUnit.megabar);

  factory Hbar.fromGigabars(Object amount) => Hbar(amount, HbarUnit.gigabar);

  factory Hbar.fromString(String amount, [HbarUnit unit = HbarUnit.hbar]) {
    final match = _fromStringPattern.firstMatch(amount);
    if (match == null) {
      throw FormatException('Invalid Hbar format: $amount');
    }

    final value = Decimal.parse(match.group(1)!);
    final parsedUnit = match.group(2) == null
        ? unit
        : HbarUnit.fromString(match.group(2)!);
    return Hbar(value, parsedUnit);
  }

  double to(HbarUnit unit) => _amountInTinybars / unit.tinybars;

  int toTinybars() => _amountInTinybars;

  double toHbars() => to(HbarUnit.hbar);

  Hbar negated() => Hbar._fromTinybars(-_amountInTinybars);

  String _formatHbarAmount() =>
      _amountInTinybars.toDecimal().shift(-8).toStringAsFixed(8);

  @override
  String toString() => '${_formatHbarAmount()} ℏ';

  String toDebugString() => 'Hbar(${_formatHbarAmount()})';

  @override
  bool operator ==(Object other) =>
      other is Hbar && _amountInTinybars == other._amountInTinybars;

  @override
  int get hashCode => _amountInTinybars.hashCode;

  @override
  int compareTo(Hbar other) =>
      _amountInTinybars.compareTo(other._amountInTinybars);

  bool operator <(Hbar other) => compareTo(other) < 0;

  bool operator <=(Hbar other) => compareTo(other) <= 0;

  bool operator >(Hbar other) => compareTo(other) > 0;

  bool operator >=(Hbar other) => compareTo(other) >= 0;
}
