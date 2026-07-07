import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool throwOnRestore = false;

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
  Future<bool> restore() async {
    if (throwOnRestore) {
      lastErrorMessage = 'store unreachable';
      throw Exception('store unreachable');
    }
    return premium;
  }

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
      expect(await service.restore(), RestoreOutcome.failed);
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

    test('restore distinguishes restored / no purchases / store error',
        () async {
      final gateway = FakeGateway(premium: true);
      final service =
          PremiumService(gateway: gateway, storeAvailable: true);
      expect(await service.restore(), RestoreOutcome.restored);
      expect(service.isPremium, isTrue);

      final gateway2 = FakeGateway(premium: false);
      final service2 =
          PremiumService(gateway: gateway2, storeAvailable: true);
      expect(await service2.restore(), RestoreOutcome.noPurchases);
      expect(service2.isPremium, isFalse);

      final gateway3 = FakeGateway()..throwOnRestore = true;
      final service3 =
          PremiumService(gateway: gateway3, storeAvailable: true);
      expect(await service3.restore(), RestoreOutcome.failed,
          reason: 'a store outage must not read as "no purchases"');
      expect(service3.lastErrorMessage, isNotNull);
    });

    test('loadPackages returns store packages and [] on error', () async {
      final gateway = FakeGateway(packages: [monthly]);
      final service =
          PremiumService(gateway: gateway, storeAvailable: true);

      expect(await service.loadPackages(), hasLength(1));

      gateway.throwOnFetch = true;
      expect(await service.loadPackages(), isEmpty);
    });

    test('a store push revoking premium marks the lapse', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final gateway = FakeGateway(premium: true);
      final service = PremiumService(
        gateway: gateway,
        storeAvailable: true,
        prefs: prefs,
      );
      await service.init();
      expect(service.isPremium, isTrue);
      expect(service.premiumLapsed, isFalse);

      gateway.listener!(false); // expiry / refund pushed by the store
      expect(service.isPremium, isFalse);
      expect(service.premiumLapsed, isTrue);
      expect(prefs.getBool('wasPremium'), isFalse);

      gateway.listener!(true); // renewed
      expect(service.premiumLapsed, isFalse);
    });

    test('a lapse while the app was closed is detected at init', () async {
      SharedPreferences.setMockInitialValues({'wasPremium': true});
      final prefs = await SharedPreferences.getInstance();
      final service = PremiumService(
        gateway: FakeGateway(premium: false), // store says expired
        storeAvailable: true,
        prefs: prefs,
      );

      await service.init();

      expect(service.isPremium, isFalse);
      expect(service.premiumLapsed, isTrue,
          reason: 'persisted wasPremium + inactive entitlement = lapse');
    });

    test('a failed configure is retried by the next store call', () async {
      final gateway = FakeGateway(packages: [monthly])
        ..throwOnConfigure = true;
      final service =
          PremiumService(gateway: gateway, storeAvailable: true);

      await service.init();
      expect(await service.loadPackages(), isEmpty,
          reason: 'store still down');

      gateway.throwOnConfigure = false; // store recovers
      expect(await service.loadPackages(), hasLength(1),
          reason: 'loadPackages must lazily retry init');
      expect(gateway.configured, isTrue);
    });
  });
}
