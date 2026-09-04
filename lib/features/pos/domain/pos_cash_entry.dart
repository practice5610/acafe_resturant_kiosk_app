import 'dart:math' as math;

/// The amount an operator has keyed into the cash-tender field.
///
/// Immutable, pure, and free of `BuildContext` so the input rules can be tested
/// without pumping a widget — and, more importantly, so **money never touches a
/// double**. Everything is held as minor units (cents) and as the literal
/// keystroke buffer; `Change Due = tendered - total` is an integer subtraction,
/// which is the only way `20.00 - 16.70` reliably prints `3.30` rather than
/// `3.3000000000000007`.
///
/// [raw] is the buffer exactly as typed, using `.` as the internal decimal mark
/// regardless of which key produced it — the design's `,` key is an input
/// affordance, while display goes through the app's existing currency formatter
/// so a cash amount reads the same as every other price in the app.
class PosCashEntry {
  /// Digits with at most one `.`, e.g. `''`, `'2'`, `'20'`, `'20.'`, `'20.5'`.
  final String raw;

  /// Currency precision, from `configModel.decimalPointSettings`.
  final int decimals;

  const PosCashEntry({this.raw = '', this.decimals = 2});

  /// Guards against a runaway key-repeat producing an unrenderable number.
  /// Ten integer digits is far past any single cash sale.
  static const int maxIntegerDigits = 10;

  static const String decimalMark = '.';

  bool get isEmpty => raw.isEmpty;

  bool get _hasDecimal => raw.contains(decimalMark);

  String get _integerPart =>
      _hasDecimal ? raw.substring(0, raw.indexOf(decimalMark)) : raw;

  String get _fractionPart =>
      _hasDecimal ? raw.substring(raw.indexOf(decimalMark) + 1) : '';

  /// Minor units. Parsed from the buffer digit by digit, never through
  /// `double.parse`, so no rounding happens on the way in.
  int get cents {
    if (raw.isEmpty) return 0;
    final int unit = math.pow(10, decimals).toInt();
    final int whole = _integerPart.isEmpty ? 0 : int.parse(_integerPart);
    final String padded = _fractionPart.padRight(decimals, '0');
    final String used = padded.substring(0, decimals);
    return whole * unit + (used.isEmpty ? 0 : int.parse(used));
  }

  /// Appends one character. Non-digits other than a decimal mark are ignored,
  /// so a stray hardware keypress cannot corrupt the buffer.
  PosCashEntry key(String token) {
    if (token == decimalMark || token == ',') return _decimal();
    if (token.length != 1 || !_isDigit(token)) return this;

    if (_hasDecimal) {
      // Past the currency's precision the keypress is a no-op rather than
      // silently shifting the amount by a factor of ten.
      if (_fractionPart.length >= decimals) return this;
      return _with('$raw$token');
    }
    // A leading zero is replaced, not appended to: '0' then '5' is 5, not 05.
    if (raw == '0') return _with(token);
    if (_integerPart.length >= maxIntegerDigits) return this;
    return _with('$raw$token');
  }

  PosCashEntry _decimal() {
    if (decimals == 0 || _hasDecimal) return this;
    return _with(raw.isEmpty ? '0$decimalMark' : '$raw$decimalMark');
  }

  /// Drops the last keystroke, decimal mark included.
  PosCashEntry backspace() =>
      raw.isEmpty ? this : _with(raw.substring(0, raw.length - 1));

  PosCashEntry clear() => _with('');

  /// Sets the buffer to an exact amount in minor units — how a denomination
  /// chip and `Exact` load a value.
  PosCashEntry withCents(int value) {
    if (value <= 0) return clear();
    final int unit = math.pow(10, decimals).toInt();
    final String whole = '${value ~/ unit}';
    if (decimals == 0) return _with(whole);
    final String fraction =
        '${value % unit}'.padLeft(decimals, '0');
    return _with('$whole$decimalMark$fraction');
  }

  PosCashEntry _with(String next) =>
      PosCashEntry(raw: next, decimals: decimals);

  static bool _isDigit(String c) {
    final int code = c.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }

  @override
  bool operator ==(Object other) =>
      other is PosCashEntry && other.raw == raw && other.decimals == decimals;

  @override
  int get hashCode => Object.hash(raw, decimals);

  @override
  String toString() => 'PosCashEntry($raw)';
}

/// Converts a display amount to minor units. Totals reach this screen as
/// doubles from the cart math, so this is the one place the conversion happens.
///
/// Rounds through `toStringAsFixed`, which is exactly what
/// `PriceConverterHelper.convertPrice` uses to render a price. That matters:
/// for a total whose third decimal sits on a rounding boundary, multiplying by
/// 100 and rounding can land a cent away from the figure printed next to
/// "Total" — and Change Due would then contradict the number the operator is
/// reading off the screen. Agreeing with the display is worth more here than
/// agreeing with the ideal decimal.
int posMoneyToCents(double amount, {int decimals = 2}) {
  final String fixed = amount.toStringAsFixed(decimals);
  final bool negative = fixed.startsWith('-');
  final String digits = fixed.replaceAll(RegExp(r'[^0-9]'), '');
  final int value = digits.isEmpty ? 0 : int.parse(digits);
  return negative ? -value : value;
}

double posCentsToMoney(int cents, {int decimals = 2}) =>
    cents / math.pow(10, decimals);
