/// What the yearly plan saves against twelve monthly payments, computed only
/// from the store's own numbers. Nothing here knows a price or a currency.
class YearlySaving {
  /// Whole percent saved against twelve months, at least [minPercent].
  final int percent;

  /// The yearly price spread over twelve months, e.g. "$2.50". Null when it
  /// could not be written in the store's own price format.
  final String? perMonth;

  const YearlySaving({required this.percent, required this.perMonth});

  static const minPercent = 5;
}

/// The saving of the yearly plan over twelve monthly payments, or null when
/// it cannot be stated honestly: a missing or non-positive raw price, two
/// different currencies, or a saving under [YearlySaving.minPercent].
///
/// [yearlyPrice] is the store's formatted yearly price ("$29.99"); the
/// per-month figure is written in that same style so currency symbol,
/// position and separators match what the store shows.
YearlySaving? yearlySaving({
  required double? monthlyRaw,
  required double? yearlyRaw,
  required String yearlyPrice,
  String? monthlyCurrency,
  String? yearlyCurrency,
}) {
  if (monthlyRaw == null || yearlyRaw == null) return null;
  if (!monthlyRaw.isFinite || !yearlyRaw.isFinite) return null;
  if (monthlyRaw <= 0 || yearlyRaw <= 0) return null;
  if (monthlyCurrency != null &&
      yearlyCurrency != null &&
      monthlyCurrency != yearlyCurrency) {
    return null;
  }
  final percent = ((1 - yearlyRaw / (monthlyRaw * 12)) * 100).round();
  if (percent < YearlySaving.minPercent) return null;
  return YearlySaving(
    percent: percent,
    perMonth: formatLike(yearlyPrice, yearlyRaw / 12),
  );
}

final _number = RegExp(r'\d(?:[\d.,\u00a0\u202f ]*\d)?');

/// Writes [value] in the style of the store-formatted [template]: the
/// template's currency text, its decimal and grouping separators and its
/// number of fraction digits. Returns null when the template has no number
/// or its style cannot be read with confidence.
String? formatLike(String template, double value) {
  final match = _number.firstMatch(template);
  if (match == null || !value.isFinite || value < 0) return null;
  final token = match.group(0)!;

  // A trailing separator followed by 1 or 2 digits is the decimal point;
  // followed by exactly 3 digits it groups thousands ("299.000").
  String? decimalSep;
  var fractionDigits = 0;
  final tail = RegExp(r'([.,])(\d{1,2})$').firstMatch(token);
  if (tail != null) {
    decimalSep = tail.group(1);
    fractionDigits = tail.group(2)!.length;
  }
  final intPart = decimalSep == null
      ? token
      : token.substring(0, token.length - fractionDigits - 1);
  final groupSepMatch = RegExp(r'[.,\u00a0\u202f ]').firstMatch(intPart);
  final groupSep = groupSepMatch?.group(0);
  if (groupSep != null && groupSep == decimalSep) return null;

  // A style with no fraction digits is right for yen or rupiah but would
  // round a small dollar amount badly, so only trust it for large values.
  if (fractionDigits == 0 && value < 100) return null;

  final fixed = value.toStringAsFixed(fractionDigits);
  final parts = fixed.split('.');
  var whole = parts[0];
  if (groupSep != null && whole.length > 3) {
    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(groupSep);
      buffer.write(whole[i]);
    }
    whole = buffer.toString();
  }
  final number = fractionDigits == 0
      ? whole
      : '$whole$decimalSep${parts.length > 1 ? parts[1] : '0' * fractionDigits}';
  return template.replaceRange(match.start, match.end, number);
}
