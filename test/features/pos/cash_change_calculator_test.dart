import 'package:acafe_customer/features/pos/domain/cash_change_calculator.dart';
import 'package:acafe_customer/features/pos/domain/pos_cash_denominations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const CashChangeCalculator calc = CashChangeCalculator();
  final List<int> breakdownSet = PosCashDenominations.eur.breakdown;
  final List<int> units = PosCashDenominations.eur.suggestionUnits;

  group('status', () {
    test('tendered over due → change', () {
      expect(calc.status(3050, 5000), const CashStatus(CashStatusKind.change, 1950));
      expect(calc.status(30, 50), const CashStatus(CashStatusKind.change, 20));
    });

    test('tendered under due → remaining', () {
      expect(calc.status(3050, 3000), const CashStatus(CashStatusKind.remaining, 50));
    });

    test('tendered equals due → exact', () {
      expect(calc.status(3050, 3050), const CashStatus(CashStatusKind.exact, 0));
    });

    test('empty tender → remaining = full due', () {
      expect(calc.status(3050, 0), const CashStatus(CashStatusKind.remaining, 3050));
    });
  });

  group('breakdown', () {
    test('30.50 due, 50 tendered → 19.50 as 10 + 5 + 2×2 + 0.50', () {
      expect(calc.breakdown(1950, breakdownSet), const [
        CashBreakdownPart(1000, 1),
        CashBreakdownPart(500, 1),
        CashBreakdownPart(200, 2),
        CashBreakdownPart(50, 1),
      ]);
    });

    test('change 20 → single 0.20 coin', () {
      expect(calc.breakdown(20, breakdownSet), const [CashBreakdownPart(20, 1)]);
    });

    test('zero change → empty', () {
      expect(calc.breakdown(0, breakdownSet), isEmpty);
    });

    test('one cent → single 0.01 coin', () {
      expect(calc.breakdown(1, breakdownSet), const [CashBreakdownPart(1, 1)]);
    });
  });

  group('suggestions', () {
    test('30.50 → 31, 35, 40, 50', () {
      expect(calc.suggestions(3050, units), [3100, 3500, 4000, 5000]);
    });

    test('1.00 → 2, 5, 10, 20', () {
      expect(calc.suggestions(100, units), [200, 500, 1000, 2000]);
    });

    test('87.20 → 88, 90, 100 (only three)', () {
      expect(calc.suggestions(8720, units), [8800, 9000, 10000]);
    });

    test('100.00 → no value at or below due, no duplicates', () {
      final List<int> s = calc.suggestions(10000, units);
      expect(s.every((v) => v > 10000), isTrue);
      expect(s.toSet().length, s.length);
    });

    test('zero / negative due → no suggestions', () {
      expect(calc.suggestions(0, units), isEmpty);
    });
  });

  group('denomination resolver', () {
    test('euro symbol → EUR set', () {
      expect(PosCashDenominations.forSymbol('€'), same(PosCashDenominations.eur));
    });

    test('unknown symbol → EUR fallback', () {
      expect(PosCashDenominations.forSymbol(r'$'), same(PosCashDenominations.eur));
      expect(PosCashDenominations.forSymbol(null), same(PosCashDenominations.eur));
    });
  });
}
