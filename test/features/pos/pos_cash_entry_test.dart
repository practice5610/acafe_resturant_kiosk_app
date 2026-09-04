import 'package:acafe_customer/features/pos/domain/pos_cash_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const PosCashEntry empty = PosCashEntry();

  PosCashEntry type(String keys, {PosCashEntry from = empty}) {
    PosCashEntry e = from;
    for (final String k in keys.split('')) {
      e = e.key(k);
    }
    return e;
  }

  group('keying', () {
    test('digits build up an amount', () {
      expect(type('20').cents, 2000);
      expect(type('7').cents, 700);
      expect(type('205').cents, 20500);
    });

    test('the comma key opens the decimal part', () {
      expect(type('20,5').cents, 2050);
      expect(type('20,50').cents, 2050);
      expect(type('1,05').cents, 105);
    });

    test('a leading zero is replaced, not appended', () {
      expect(type('05').raw, '5');
      expect(type('0,5').cents, 50);
    });

    test('a second decimal mark is ignored', () {
      expect(type('1,2,3').raw, '1.23');
    });

    test('keys past the currency precision are ignored', () {
      expect(type('1,234').raw, '1.23');
      expect(type('1,234').cents, 123);
    });

    test('a bare comma starts at zero', () {
      expect(type(',5').raw, '0.5');
      expect(type(',5').cents, 50);
    });

    test('non-digits are ignored', () {
      expect(empty.key('a').raw, '');
      expect(empty.key('').raw, '');
    });

    test('the integer part is bounded', () {
      final PosCashEntry e = type('12345678901234');
      expect(e.raw.length, PosCashEntry.maxIntegerDigits);
    });
  });

  group('backspace and clear', () {
    test('backspace drops the last keystroke including the mark', () {
      expect(type('20,5').backspace().raw, '20.');
      expect(type('20,5').backspace().backspace().raw, '20');
      expect(empty.backspace().raw, '');
    });

    test('clear empties the buffer', () {
      expect(type('20').clear().isEmpty, isTrue);
      expect(type('20').clear().cents, 0);
    });
  });

  group('withCents', () {
    test('loads a denomination exactly', () {
      expect(empty.withCents(2000).raw, '20.00');
      expect(empty.withCents(2000).cents, 2000);
    });

    test('loads an exact total with a fraction', () {
      expect(empty.withCents(1670).raw, '16.70');
      expect(empty.withCents(1670).cents, 1670);
    });

    test('pads a sub-unit amount', () {
      expect(empty.withCents(5).raw, '0.05');
      expect(empty.withCents(5).cents, 5);
    });

    test('zero or less clears', () {
      expect(empty.withCents(0).isEmpty, isTrue);
      expect(empty.withCents(-1).isEmpty, isTrue);
    });

    test('typing continues from a loaded chip value', () {
      expect(empty.withCents(2000).backspace().raw, '20.0');
    });
  });

  group('change due is exact', () {
    test('the case that breaks in floating point', () {
      // 20.00 - 16.70 in doubles is 3.3000000000000007.
      final int change = empty.withCents(2000).cents - posMoneyToCents(16.70);
      expect(change, 330);
      expect(posCentsToMoney(change), 3.30);
    });

    test('cents agree with the figure the price formatter prints', () {
      // A double cannot distinguish 2.675 from 2.67499...; what matters is
      // that cents match the rendered total, so Change Due never contradicts
      // the Total shown one row below it.
      for (final double total in [16.70, 2.675, 1.005, 19.99, 0.145]) {
        expect(
          posMoneyToCents(total),
          int.parse(total.toStringAsFixed(2).replaceAll('.', '')),
          reason: 'total $total',
        );
      }
    });

    test('negative amounts keep their sign', () {
      expect(posMoneyToCents(-3.30), -330);
    });
  });

  group('zero-decimal currencies', () {
    const PosCashEntry yen = PosCashEntry(decimals: 0);

    test('the decimal key is inert', () {
      expect(yen.key(',').raw, '');
    });

    test('cents are whole units', () {
      expect(type('500', from: yen).cents, 500);
      expect(yen.withCents(500).raw, '500');
    });
  });
}
