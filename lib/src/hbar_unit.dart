enum HbarUnit {
  // 1 tinybar = base unit
  tinybar('tℏ', 1),

  // 1 microbar = 100 tinybars
  microbar('μℏ', 100),

  // 1 millibar = 100,000 tinybars
  millibar('mℏ', 100000),

  // 1 hbar = 100,000,000 tinybars
  hbar('ℏ', 100000000),

  // 1 kilobar = 100,000,000,000 tinybars
  kilobar('kℏ', 100000000000),

  // 1 megabar = 100,000,000,000,000 tinybars
  megabar('Mℏ', 100000000000000),

  // 1 gigabar = 100,000,000,000,000,000 tinybars
  gigabar('Gℏ', 100000000000000000);

  const HbarUnit(this.symbol, this.tinybars);

  final String symbol;
  final int tinybars;

  factory HbarUnit.fromString(String symbol) {
    for (final unit in HbarUnit.values) {
      if (unit.symbol == symbol) {
        return unit;
      }
    }
    throw ArgumentError('Invalid Hbar unit symbol: $symbol');
  }
}
