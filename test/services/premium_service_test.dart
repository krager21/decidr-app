import 'package:flutter_test/flutter_test.dart';

import 'package:decidr_app/services/premium_service.dart';
import 'package:decidr_app/services/purchases_gateway.dart';

/// In-memory gateway standing in for RevenueCat.
class FakeGateway implements PurchasesGateway {
  bool premium;
  bool configured = false;
  String? configuredKey;
  void Function(bool isPremium)? listener;
  List<PremiumPackage> packages;
  PurchaseOutcome purchaseOutcome;
  bool throwOnConfigure = false;
  bool throwOnFetch = false;

  FakeGateway({
    this.premium = false,
    this.packages = const [],
    this.purchaseOutcome = PurchaseOutcome.success,
  });

  @override
  String? lastErrorMessage;

  @override
  Future<void> configure(String apiKey) async {
    if (throwOnConfigure) throw Exception('store down');
    configured = true;
    configuredKey = apiKey;
  }

  @override
  void listenForChanges(void Function(bool isPremium) onChanged) {
    listener = onChanged;
  }

  @override
  Future<bool> fetchIsPremium() async {
    if (throwOnFetch) throw Exception('network');
    return premium;
  }

  @override
  Future<List<PremiumPackage>> fetchPackages() async {
    if (throwOnFetch) throw Exception('network');
    return packages;
  }

  @override
  Future<PurchaseOutcome> purchase(PremiumPackage package) async {
    if (purchaseOutcome == PurchaseOutcome.success) premium = true;
    return purchaseOutcome;
  }

  @override
  Future<bool> restore() async => premium;

  @override
  Future<String?> fetchManagementUrl() async =>
      premium ? 'https://example.com/manage' : null;
}

const monthly = PremiumPackage(
  id: r'$rc_monthly',
  label: 'Monthly',
  priceString: r'$1.99',
  periodSuffix: '/ month',
);

void main() {
  group('PremiumService without a store', () {
    test('is free tier and inert', () async {
      final gateway = FakeGateway(premium: true);
      final service = PremiumService(gateway: gateway, storeAvailable: false);

      await service.init();

      expect(service.isPremium, isFalse);
      expect(gateway.configured, isFalse, reason: 'init must be a no-op');
      expect(await service.loadPackages(), isEmpty);
      expect(await service.purchase(monthly), PurchaseOutcome.failed);
      expect(await service.restore(), isFalse);
      expect(await service.managementUrl(), isNull);
    });
  });

  group('PremiumService with a store', () {
    test('init picks up an existing entitlement and notifies', () async {
      final service = PremiumService(
        gateway: FakeGateway(premium: true),
        storeAvailable: true,
      );
      var notified = 0;
      service.addListener(() => notified++);

      await service.init();

      expect(service.isPremium, isTrue);
      expect(notified, 1);
    });

    test('init survives a configure failure and stays free', () async {
      final service = PremiumService(
        gateway: FakeGateway(premium: true)..throwOnConfigure = true,
        storeAvailable: true,
      );

      await service.init();

      expect(service.isPremium, isFalse);
    });

    test('successful purchase flips entitlement and notifies', () async {
      final service = PremiumService(
        gateway: FakeGateway(packages: [monthly]),
        storeAvailable: true,
      );
      await service.init();
      expect(service.isPremium, isFalse);
      var notified = 0;
      service.addListener(() => notified++);

      final outcome = await service.purchase(monthly);

      expect(outcome, PurchaseOutcome.success);
      expect(service.isPremium, isTrue);
      expect(notified, 1);
    });

    test('cancelled purchase leaves the free tier untouched', () async {
      final service = PremiumService(
        gateway:
            FakeGateway(purchaseOutcome: PurchaseOutcome.cancelled),
        storeAvailable: true,
      );
      await service.init();

      final outcome = await service.purchase(monthly);

      expect(outcome, PurchaseOutcome.cancelled);
      expect(service.isPremium, isFalse);
    });

    test('store push (renewal/refund) updates entitlement', () async {
      final gateway = FakeGateway();
      final service =
          PremiumService(gateway: gateway, storeAvailable: true);
      await service.init();

      gateway.listener!(true);
      expect(service.isPremium, isTrue);

      gateway.listener!(false); // refund revokes
      expect(service.isPremium, isFalse);
    });

    test('restore reports and applies the restored state', () async {
      final gateway = FakeGateway(premium: true);
      final service =
          PremiumService(gateway: gateway, storeAvailable: true);

      expect(await service.restore(), isTrue);
      expect(service.isPremium, isTrue);
    });

    test('loadPackages returns store packages and [] on error', () async {
      final gateway = FakeGateway(packages: [monthly]);
      final service =
          PremiumService(gateway: gateway, storeAvailable: true);

      expect(await service.loadPackages(), hasLength(1));

      gateway.throwOnFetch = true;
      expect(await service.loadPackages(), isEmpty);
    });
  });
}
