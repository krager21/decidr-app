import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

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

  /// The underlying SDK object; opaque to callers.
  final Object? raw;

  const PremiumPackage({
    required this.id,
    required this.label,
    required this.priceString,
    required this.periodSuffix,
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
    final info = await Purchases.restorePurchases();
    return _hasEntitlement(info);
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
    final (label, suffix) = switch (p.packageType) {
      PackageType.monthly => ('Monthly', '/ month'),
      PackageType.annual => ('Annual', '/ year'),
      PackageType.lifetime => ('Lifetime', ''),
      PackageType.weekly => ('Weekly', '/ week'),
      PackageType.sixMonth => ('6 months', '/ 6 months'),
      PackageType.threeMonth => ('3 months', '/ 3 months'),
      PackageType.twoMonth => ('2 months', '/ 2 months'),
      _ => (p.storeProduct.title, ''),
    };
    return PremiumPackage(
      id: p.identifier,
      label: label,
      priceString: p.storeProduct.priceString,
      periodSuffix: suffix,
      raw: p,
    );
  }
}
