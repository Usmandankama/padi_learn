// The fee split is the one piece of arithmetic in this app that moves real
// money, and it is wrong in ways nobody notices: a teacher underpaid by a few
// naira a sale does not file a bug report.
//
// The invariant that matters is the first group below — whatever Paystack's
// rates are, the student's total must cover the fee *and* leave the list price
// intact. The rest guards the boundaries where that is hardest.

import 'package:flutter_test/flutter_test.dart';
import 'package:padi_learn/utils/pricing.dart';

/// Paystack's own fee calculation, kept separate from the implementation so
/// this checks the maths rather than restating it.
double paystackFeeOn(double charged) {
  var fee = charged * 0.015;
  if (charged >= 2500) fee += 100;
  return fee > 2000 ? 2000 : fee;
}

void main() {
  group('the student covers the fee', () {
    // Spans both sides of the 2,500 flat-fee threshold and the 2,000 cap.
    const prices = [
      100.0, 500.0, 999.0, 2000.0, 2460.0, 2461.0, 2462.0, 2500.0,
      3000.0, 5000.0, 10000.0, 50000.0, 124000.0, 130000.0, 500000.0,
    ];

    for (final price in prices) {
      test('NGN $price settles in full', () {
        final total = customerTotalFor(price);
        final settled = total - paystackFeeOn(total);

        // Never short: rounding up is what guarantees this direction.
        expect(settled, greaterThanOrEqualTo(price),
            reason: 'teacher underpaid at $price (settled $settled)');
        // And never generous by more than the rounding-up of one naira.
        expect(settled - price, lessThan(1.5),
            reason: 'student overcharged at $price');
      });
    }
  });

  group('the teacher earns a flat 85%', () {
    for (final price in [100.0, 2461.0, 2500.0, 10000.0, 200000.0]) {
      test('no threshold distorts NGN $price', () {
        final b = estimateBreakdown(price);
        expect(b.teacherEarning, closeTo(price * 0.85, 1));
        expect(b.teacherShareOfList, closeTo(85, 0.5));
      });
    }

    test('earnings rise monotonically with price', () {
      // The old model had a band where charging more earned less. Fronting
      // the fee is what removed it, so this is the regression guard.
      var previous = 0.0;
      for (var price = 100.0; price <= 6000; price += 1) {
        final earning = estimateBreakdown(price).teacherEarning;
        expect(earning, greaterThanOrEqualTo(previous),
            reason: 'earnings dipped at NGN $price');
        previous = earning;
      }
    });
  });

  group('the parts reconstruct the whole', () {
    for (final price in [500.0, 2500.0, 7500.0, 300000.0]) {
      test('NGN $price', () {
        final b = estimateBreakdown(price);
        expect(b.paystackFee + b.platformFee + b.teacherEarning,
            closeTo(b.customerTotal, 1.5));
        expect(b.customerTotal, greaterThan(b.listPrice));
      });
    }
  });

  group('the flat-fee threshold', () {
    test('the suggested price keeps the student under NGN 2,500', () {
      final suggested = PriceBreakdown.suggestedListPriceBelowThreshold;
      expect(customerTotalFor(suggested), lessThan(2500));
      // And it really is the highest such price.
      expect(customerTotalFor(suggested + 1), greaterThanOrEqualTo(2500));
    });

    test('warns just above it, and not well past it', () {
      final suggested = PriceBreakdown.suggestedListPriceBelowThreshold;
      expect(estimateBreakdown(suggested).crossesFlatFeeThreshold, isFalse);
      expect(estimateBreakdown(suggested + 1).crossesFlatFeeThreshold, isTrue);
      expect(estimateBreakdown(suggested + 500).crossesFlatFeeThreshold, isFalse);
    });

    test('one naira over the threshold costs the student about 100', () {
      final suggested = PriceBreakdown.suggestedListPriceBelowThreshold;
      final jump =
          customerTotalFor(suggested + 1) - customerTotalFor(suggested);
      expect(jump, greaterThan(90));
      expect(jump, lessThan(115));
    });
  });

  test('free stays free', () {
    expect(customerTotalFor(0), 0);
    final b = estimateBreakdown(0);
    expect(b.customerTotal, 0);
    expect(b.teacherEarning, 0);
  });
}
