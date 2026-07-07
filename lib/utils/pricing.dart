/// Display math for the paywall's price anchoring.
///
/// Works off the store-localized [priceString] plus the numeric price,
/// so the derived strings reuse the store's own currency symbol
/// instead of guessing locale formatting.
library;

import '../services/purchases_gateway.dart';

/// Display order: short cadences first, lifetime last as the anchor.
int packageDisplayRank(PremiumPackage p) => p.kind.index;

/// Sort packages for the paywall list.
List<PremiumPackage> sortForDisplay(List<PremiumPackage> packages) {
  final sorted = [...packages]
    ..sort((a, b) => packageDisplayRank(a).compareTo(packageDisplayRank(b)));
  return sorted;
}

/// The package to pre-select: annual when present (the plan we want to
/// anchor on), otherwise the first in display order.
PremiumPackage? defaultSelection(List<PremiumPackage> packages) {
  if (packages.isEmpty) return null;
  for (final p in packages) {
    if (p.kind == PackageKind.annual) return p;
  }
  return sortForDisplay(packages).first;
}

/// Currency symbol/prefix pulled out of a store price string, e.g.
/// "\$" from "\$19.99", "€" from "€19,99". Empty when the string leads
/// with digits (symbol-suffix locales fall back to no symbol).
String currencySymbol(String priceString) {
  final match = RegExp(r'^[^\d\s]+').firstMatch(priceString.trim());
  return match?.group(0) ?? '';
}

/// "≈ $1.67 / month" for a yearly price, using the store's own
/// currency symbol. Null when the numeric price is unknown.
String? perMonthEquivalent(PremiumPackage p) {
  final price = p.price;
  if (price == null) return null;
  final months = switch (p.kind) {
    PackageKind.annual => 12,
    PackageKind.sixMonth => 6,
    PackageKind.threeMonth => 3,
    PackageKind.twoMonth => 2,
    _ => null,
  };
  if (months == null) return null;
  final symbol = currencySymbol(p.priceString);
  return '≈ $symbol${(price / months).toStringAsFixed(2)} / month';
}

/// Whole-percent savings of [candidate] against paying [monthly] for
/// the same span, e.g. 44 for $19.99/yr vs $2.99/mo. Null when either
/// price is unknown, not comparable, or there are no savings.
int? savingsVersusMonthly(PremiumPackage candidate, PremiumPackage monthly) {
  final candidatePrice = candidate.price;
  final monthlyPrice = monthly.price;
  if (candidatePrice == null || monthlyPrice == null || monthlyPrice <= 0) {
    return null;
  }
  final months = switch (candidate.kind) {
    PackageKind.annual => 12,
    PackageKind.sixMonth => 6,
    PackageKind.threeMonth => 3,
    PackageKind.twoMonth => 2,
    _ => null,
  };
  if (months == null) return null;
  final fullPrice = monthlyPrice * months;
  if (candidatePrice >= fullPrice) return null;
  return ((1 - candidatePrice / fullPrice) * 100).round();
}
