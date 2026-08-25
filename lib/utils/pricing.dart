/// Client-side estimate of how a course price splits three ways.
///
/// The authoritative split is computed in the `verify-payment` edge function
/// from Paystack's reported fee — this only mirrors it so a teacher can see
/// roughly what they will earn *while* setting a price. Always present the
/// result as approximate.

/// Platform commission, taken on the amount that actually settles (after
/// Paystack's cut). Mirrors `PLATFORM_FEE_PERCENT` on the server — change both.
const double kPlatformFeePercent = 15;

/// Paystack local-card pricing. VERIFY AGAINST CURRENT PAYSTACK RATES: these
/// are only used for the on-screen estimate, never for real money.
const double _paystackPercent = 1.5;
const double _paystackFlatFee = 100;
const double _paystackFlatFeeWaivedBelow = 2500;
const double _paystackFeeCap = 2000;

/// Above this, the flat fee has kicked in but the teacher still earns less than
/// they would just under the threshold. See [PriceBreakdown.isInFeeDeadZone].
const double _deadZoneCeiling = 2610;

class PriceBreakdown {
  /// What the student is charged.
  final double price;

  /// Estimated Paystack processing fee.
  final double paystackFee;

  /// Estimated platform commission, taken on the settled amount.
  final double platformFee;

  /// Estimated amount owed to the teacher.
  final double teacherEarning;

  const PriceBreakdown({
    required this.price,
    required this.paystackFee,
    required this.platformFee,
    required this.teacherEarning,
  });

  /// What actually settles into the platform account.
  double get net => price - paystackFee;

  /// The teacher's cut as a percentage of the list price.
  double get teacherShareOfList =>
      price <= 0 ? 0 : (teacherEarning / price) * 100;

  /// True when the price sits just above Paystack's flat-fee threshold, where
  /// charging *more* earns the teacher *less* than pricing just below it.
  bool get isInFeeDeadZone =>
      price >= _paystackFlatFeeWaivedBelow && price <= _deadZoneCeiling;

  /// The price just under the threshold, for suggesting a better one.
  static double get suggestedPriceBelowThreshold =>
      _paystackFlatFeeWaivedBelow - 1;
}

/// Estimates the split for a [price] in naira.
PriceBreakdown estimateBreakdown(double price) {
  if (price <= 0) {
    return const PriceBreakdown(
      price: 0,
      paystackFee: 0,
      platformFee: 0,
      teacherEarning: 0,
    );
  }

  var paystackFee = price * (_paystackPercent / 100);
  if (price >= _paystackFlatFeeWaivedBelow) paystackFee += _paystackFlatFee;
  if (paystackFee > _paystackFeeCap) paystackFee = _paystackFeeCap;
  paystackFee = paystackFee.roundToDouble();

  final net = price - paystackFee;
  final platformFee = (net * (kPlatformFeePercent / 100)).roundToDouble();

  return PriceBreakdown(
    price: price,
    paystackFee: paystackFee,
    platformFee: platformFee,
    teacherEarning: net - platformFee,
  );
}
