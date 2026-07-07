import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Billing cadence of a [PremiumPackage], ordered for display: short
/// cadences first, lifetime last (it anchors the price list).
enum PackageKind { weekly, monthly, twoMonth, threeMonth, sixMonth, annual, lifetime, other }

/// A store package the user can buy, projected into app-owned types so
/// the rest of the app (PremiumService, paywall UI, tests) never
/// imports the RevenueCat SDK. [raw] carries the underlying
/// [Package] for the purchase call; tests can leave it null.
class PremiumPackage {
  /// RevenueCat package identifier (e.g. `$rc_monthly`).
  final String id;

  /// Human label derived from the package type — "Monthly", "Annual",
  /// "Lifetime" — falling back to the store product title.
  final String label;

  /// Localized price string straight from the store, e.g. "$1.99".
  final String priceString;

  /// Billing cadence suffix for display, e.g. "/ month". Empty for
  /// one-time purchases.
  final String periodSuffix;

  /// Cadence, for sorting and per-month price math.
  final PackageKind kind;

  /// Numeric price in the store currency (pairs with [priceString]).
  /// Null when unknown (tests, exotic stores).
  final double? price;

  /// Human description of an introductory offer, e.g.
  /// "7 days free" or "3 months at $0.99" — null when none.
  final String? introOffer;

  /// Whether [introOffer] is a free trial (drives the CTA copy).
  final bool hasFreeTrial;

  /// The underlying SDK object; opaque to callers.
  final Object? raw;

  const PremiumPackage({
    required this.id,
    required this.label,
    required this.priceString,
    required this.periodSuffix,
    this.kind = PackageKind.other,
    this.price,
    this.introOffer,
    this.hasFreeTrial = false,
    this.raw,
  });
}

/// Result of a purchase or restore attempt, reduced to what the UI
/// needs to react to.
enum PurchaseOutcome {
  /// Entitlement is now active.
  success,

  /// User backed out of the store sheet — no error surface needed.
  cancelled,

  /// Anything else; [PurchasesGateway.lastErrorMessage] has a
  /// user-presentable description.
  failed,
}

/// Result of a restore attempt. Distinguishes "the store answered and
/// found nothing" from "the store couldn't be reached" — conflating
/// them tells a paying user their purchase is gone.
enum RestoreOutcome {
  /// Entitlement restored and active.
  restored,

  /// Store reachable, but no prior purchase on this account.
  noPurchases,

  /// Store unreachable or errored; try again later.
  failed,
}

/// Thin seam over the static RevenueCat API so [PremiumService] can be
/// unit-tested with a fake. Only this file imports purchases_flutter.
abstract class PurchasesGateway {
  /// One-line description of the most recent [PurchaseOutcome.failed],
  /// suitable for a snackbar. Never contains keys or identifiers.
  String? get lastErrorMessage;

  /// Configure the SDK. Must be called once before anything else.
  Future<void> configure(String apiKey);

  /// Register [onChanged] to fire with the new premium state whenever
  /// the store pushes a customer-info update (renewal, refund,
  /// cross-device purchase).
  void listenForChanges(void Function(bool isPremium) onChanged);

  /// Whether the entitlement is currently active.
  Future<bool> fetchIsPremium();

  /// Packages available for purchase from the current offering,
  /// in display order.
  Future<List<PremiumPackage>> fetchPackages();

  Future<PurchaseOutcome> purchase(PremiumPackage package);

  /// Restore previous purchases; returns the resulting premium state.
  Future<bool> restore();

  /// Store-provided subscription management URL, if any.
  Future<String?> fetchManagementUrl();
}

/// Production gateway backed by the RevenueCat SDK.
class RevenueCatGateway implements PurchasesGateway {
  final String entitlementId;

  RevenueCatGateway({required this.entitlementId});

  @override
  String? lastErrorMessage;

  @override
  Future<void> configure(String apiKey) {
    return Purchases.configure(PurchasesConfiguration(apiKey));
  }

  @override
  void listenForChanges(void Function(bool isPremium) onChanged) {
    Purchases.addCustomerInfoUpdateListener((info) {
      onChanged(_hasEntitlement(info));
    });
  }

  @override
  Future<bool> fetchIsPremium() async {
    final info = await Purchases.getCustomerInfo();
    return _hasEntitlement(info);
  }

  @override
  Future<List<PremiumPackage>> fetchPackages() async {
    final offerings = await Purchases.getOfferings();
    final packages = offerings.current?.availablePackages ?? const [];
    return packages.map(_toPremiumPackage).toList();
  }

  @override
  Future<PurchaseOutcome> purchase(PremiumPackage package) async {
    final raw = package.raw;
    if (raw is! Package) {
      lastErrorMessage = 'This package can’t be purchased.';
      return PurchaseOutcome.failed;
    }
    try {
      final result = await Purchases.purchase(PurchaseParams.package(raw));
      return _hasEntitlement(result.customerInfo)
          ? PurchaseOutcome.success
          : PurchaseOutcome.failed;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return PurchaseOutcome.cancelled;
      }
      lastErrorMessage = e.message ?? 'Purchase failed. Please try again.';
      return PurchaseOutcome.failed;
    }
  }

  @override
  Future<bool> restore() async {
    try {
      final info = await Purchases.restorePurchases();
      return _hasEntitlement(info);
    } on PlatformException catch (e) {
      lastErrorMessage =
          e.message ?? 'Couldn’t reach the store. Please try again.';
      rethrow;
    }
  }

  @override
  Future<String?> fetchManagementUrl() async {
    final info = await Purchases.getCustomerInfo();
    return info.managementURL;
  }

  bool _hasEntitlement(CustomerInfo info) {
    return info.entitlements.active.containsKey(entitlementId);
  }

  PremiumPackage _toPremiumPackage(Package p) {
    final (label, suffix, kind) = switch (p.packageType) {
      PackageType.monthly => ('Monthly', '/ month', PackageKind.monthly),
      PackageType.annual => ('Annual', '/ year', PackageKind.annual),
      PackageType.lifetime => ('Lifetime', '', PackageKind.lifetime),
      PackageType.weekly => ('Weekly', '/ week', PackageKind.weekly),
      PackageType.sixMonth => ('6 months', '/ 6 months', PackageKind.sixMonth),
      PackageType.threeMonth =>
        ('3 months', '/ 3 months', PackageKind.threeMonth),
      PackageType.twoMonth => ('2 months', '/ 2 months', PackageKind.twoMonth),
      _ => (p.storeProduct.title, '', PackageKind.other),
    };
    final intro = p.storeProduct.introductoryPrice;
    return PremiumPackage(
      id: p.identifier,
      label: label,
      priceString: p.storeProduct.priceString,
      periodSuffix: suffix,
      kind: kind,
      price: p.storeProduct.price,
      introOffer: intro == null ? null : _describeIntro(intro),
      hasFreeTrial: intro != null && intro.price == 0,
      raw: p,
    );
  }

  /// "7 days free", "1 month free", "3 months at $0.99" — the store's
  /// intro offer in one human line.
  String _describeIntro(IntroductoryPrice intro) {
    final unit = switch (intro.periodUnit) {
      PeriodUnit.day => 'day',
      PeriodUnit.week => 'week',
      PeriodUnit.month => 'month',
      PeriodUnit.year => 'year',
      _ => 'period',
    };
    final n = intro.periodNumberOfUnits * intro.cycles;
    final span = n == 1 ? '1 $unit' : '$n ${unit}s';
    return intro.price == 0
        ? '$span free'
        : '$span at ${intro.priceString}';
  }
}
