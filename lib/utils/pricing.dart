/// Client-side estimate of what a student pays and what a teacher earns.
///
/// **The card fee is fronted to the customer.** A teacher's price is what
/// *settles*, not what is charged: Paystack's cut is added on top at checkout,
/// so the student pays a little more and the teacher's earning stops depending
/// on a fee they never agreed to. The consequence worth knowing is that a
/// teacher now earns exactly [kPlatformFeePercent] less than their list price,
/// every time, with no threshold to fall foul of.
///
/// The authoritative amounts are computed server-side — `initialize-payment`
/// charges the grossed-up total and `_shared/paystack.ts` splits what actually
/// settles. This only mirrors that so a teacher can see the numbers *while*
/// setting a price. Always present the result as approximate.
library;

/// Platform commission, taken on the course's list price.
///
/// Mirrors `PLATFORM_FEE_PERCENT` on the server — change both. The server
/// still takes its cut from what genuinely settles, so if Paystack's real fee
/// differs from the estimate below, the server is right and this is close.
const double kPlatformFeePercent = 15;

/// Paystack local-card pricing. VERIFY AGAINST CURRENT PAYSTACK RATES: these
/// are only used for the on-screen estimate, never for real money.
const double _paystackPercent = 1.5;
const double _paystackFlatFee = 100;
const double _paystackFlatFeeWaivedBelow = 2500;
const double _paystackFeeCap = 2000;

/// How close to the threshold still counts as "just over" for the warning
/// below. A judgement call, sized to the jump it is warning about.
const double _thresholdWarningBand = 150;

/// What a student must be charged for [listPrice] to settle in full.
///
/// Paystack's fee is a percentage *of the amount charged*, so adding it on top
/// grows it — this solves for the total rather than adding a fee to the price
/// and coming up short. Rounded up, because landing a kobo below the list
/// price would quietly underpay the teacher on every single sale.
double customerTotalFor(double listPrice) {
  if (listPrice <= 0) return 0;

  // Each branch assumes a fee regime, then only accepts its answer if the
  // regime still holds at that total. Rounding up can nudge a total across
  // Paystack's threshold, which would quietly re-introduce the flat fee and
  // underpay the teacher on every sale — so the check has to come after the
  // rounding, not before it.
  final waived = (listPrice / (1 - _paystackPercent / 100)).ceilToDouble();
  if (waived < _paystackFlatFeeWaivedBelow) return waived;

  final withFlat =
      ((listPrice + _paystackFlatFee) / (1 - _paystackPercent / 100))
          .ceilToDouble();
  if (withFlat * (_paystackPercent / 100) + _paystackFlatFee <=
      _paystackFeeCap) {
    return withFlat;
  }

  // Past the cap the fee stops growing, so it is simply added on.
  return (listPrice + _paystackFeeCap).ceilToDouble();
}

class PriceBreakdown {
  /// What the teacher set, and what settles.
  final double listPrice;

  /// What the student is actually charged.
  final double customerTotal;

  /// Estimated Paystack processing fee, carried by the student.
  final double paystackFee;

  /// Estimated platform commission, taken on [listPrice].
  final double platformFee;

  /// Estimated amount owed to the teacher.
  final double teacherEarning;

  const PriceBreakdown({
    required this.listPrice,
    required this.customerTotal,
    required this.paystackFee,
    required this.platformFee,
    required this.teacherEarning,
  });

  /// The teacher's cut as a percentage of their list price. Computed rather
  /// than assumed, so rounding never makes this line quietly wrong.
  double get teacherShareOfList =>
      listPrice <= 0 ? 0 : (teacherEarning / listPrice) * 100;

  /// True when a price sits just above the point where Paystack's flat fee
  /// starts applying, so one naira more from the teacher costs the student
  /// around NGN 100 extra.
  ///
  /// Under the old model this was a trap for the *teacher's* earnings. Now
  /// their earnings rise smoothly and it is the student's total that jumps,
  /// which still matters: it is the number that decides whether anyone buys.
  bool get crossesFlatFeeThreshold {
    final suggested = suggestedListPriceBelowThreshold;
    return listPrice > suggested &&
        listPrice <= suggested + _thresholdWarningBand;
  }

  /// The highest list price whose student total still escapes the flat fee.
  ///
  /// Derived rather than hardcoded so it stays correct if Paystack's rates
  /// above are ever updated.
  static double get suggestedListPriceBelowThreshold {
    var price =
        (_paystackFlatFeeWaivedBelow * (1 - _paystackPercent / 100))
            .floorToDouble();
    while (price > 0 &&
        customerTotalFor(price) >= _paystackFlatFeeWaivedBelow) {
      price -= 1;
    }
    return price;
  }
}

/// Estimates the split for a [listPrice] in naira.
PriceBreakdown estimateBreakdown(double listPrice) {
  if (listPrice <= 0) {
    return const PriceBreakdown(
      listPrice: 0,
      customerTotal: 0,
      paystackFee: 0,
      platformFee: 0,
      teacherEarning: 0,
    );
  }

  final total = customerTotalFor(listPrice);
  final platformFee =
      (listPrice * (kPlatformFeePercent / 100)).roundToDouble();

  return PriceBreakdown(
    listPrice: listPrice,
    customerTotal: total,
    paystackFee: total - listPrice,
    platformFee: platformFee,
    teacherEarning: listPrice - platformFee,
  );
}
