import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'purchases_gateway.dart';

/// Single source of truth for the Decidr Premium entitlement.
///
/// Wraps a [PurchasesGateway] (RevenueCat in production, a fake in
/// tests) and exposes entitlement state as a [ChangeNotifier] so gated
/// UI rebuilds when premium unlocks — mid-session, after a restore, or
/// via a cross-device renewal pushed by the store.
///
/// Degrades gracefully along three axes:
///  * **No API key configured** — [storeConfigured] is false, [init]
///    is a no-op, and the paywall shows its "not available yet" state.
///    This keeps the app fully functional before the RevenueCat
///    account exists.
///  * **Dev override** — `--dart-define=DECIDR_PREMIUM_OVERRIDE=true`
///    forces premium on for end-to-end testing of gated features.
///    Ignored in release builds so a copy-pasted dev command line can
///    never ship premium unlocked to real users.
///  * **Gateway errors** — every store call is caught; failures leave
///    the user on the free tier rather than crashing.
///
/// Keys are injected at build time:
///   flutter build ios   --dart-define=REVENUECAT_API_KEY_APPLE=appl_...
///   flutter build macos  --dart-define=REVENUECAT_API_KEY_APPLE=appl_...
///   flutter build apk   --dart-define=REVENUECAT_API_KEY_GOOGLE=goog_...
///   flutter build web   --dart-define=REVENUECAT_API_KEY_WEB=rcb_...
class PremiumService extends ChangeNotifier {
  /// RevenueCat entitlement identifier gating all premium features.
  static const String entitlementId = 'premium';

  static const String _appleKey =
      String.fromEnvironment('REVENUECAT_API_KEY_APPLE');
  static const String _googleKey =
      String.fromEnvironment('REVENUECAT_API_KEY_GOOGLE');
  static const String _webKey =
      String.fromEnvironment('REVENUECAT_API_KEY_WEB');
  static const bool _override =
      bool.fromEnvironment('DECIDR_PREMIUM_OVERRIDE');

  /// Whether the dev-time premium override is active in this build.
  /// Deliberately inert in release mode — see class docs.
  static bool get overrideActive => _override && !kReleaseMode;

  /// The RevenueCat key for the platform we're running on, or '' when
  /// none applies (key not provided, or unsupported desktop platform).
  static String get platformApiKey {
    if (kIsWeb) return _webKey;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return _appleKey;
      case TargetPlatform.android:
        return _googleKey;
      default:
        return '';
    }
  }

  /// Whether a store backend is available in this build. When false,
  /// the paywall renders an informational state instead of packages.
  static bool get storeConfigured => platformApiKey.isNotEmpty;

  final PurchasesGateway _gateway;
  final bool _storeAvailable;

  /// For remembering entitlement across launches so a lapse (expiry,
  /// refund) can be detected and reacted to. Optional — without it,
  /// lapse detection only works within a session.
  final SharedPreferences? _prefs;

  bool _storePremium = false;

  /// True after the entitlement transitions from active to inactive
  /// (expiry, refund, cross-device cancellation) — including across
  /// launches via the persisted `wasPremium` flag. Cleared when the
  /// user is premium again. UI uses this for win-back surfaces.
  bool premiumLapsed = false;

  /// Set only once [PurchasesGateway.configure] has succeeded — a
  /// failed configure must stay retryable, or the paywall's "Try
  /// again" can never recover.
  bool _configured = false;
  Future<void>? _initFuture;

  PremiumService({
    PurchasesGateway? gateway,
    bool? storeAvailable,
    SharedPreferences? prefs,
  })  : _gateway = gateway ?? RevenueCatGateway(entitlementId: entitlementId),
        _storeAvailable = storeAvailable ?? storeConfigured,
        _prefs = prefs;

  /// Whether premium features are unlocked right now.
  bool get isPremium => overrideActive || _storePremium;

  /// Whether purchases can actually be made in this build.
  bool get storeAvailable => _storeAvailable;

  /// One-line description of the most recent failed purchase/restore,
  /// for a snackbar. Null when the last operation succeeded.
  String? get lastErrorMessage => _gateway.lastErrorMessage;

  /// Configure the store SDK and load the current entitlement state.
  /// Safe to call at every app launch; a no-op without a store key.
  /// Never throws — store outages leave the user on the free tier,
  /// and a failed configure is retried by the next store operation.
  Future<void> init() {
    if (!_storeAvailable || _configured) return Future.value();
    return _initFuture ??= _doInit();
  }

  Future<void> _doInit() async {
    try {
      await _gateway.configure(platformApiKey);
      _configured = true;
      _gateway.listenForChanges(_onEntitlementChanged);
      _onEntitlementChanged(await _gateway.fetchIsPremium());
    } catch (e) {
      debugPrint('PremiumService init failed: $e');
    } finally {
      // Clear the memo so a failed configure can be retried lazily
      // (loadPackages/purchase/restore all re-enter through init()).
      _initFuture = null;
    }
  }

  /// Packages the paywall can offer. Empty on failure or when the
  /// store isn't configured.
  Future<List<PremiumPackage>> loadPackages() async {
    if (!_storeAvailable) return const [];
    await init();
    if (!_configured) return const [];
    try {
      return await _gateway.fetchPackages();
    } catch (e) {
      debugPrint('PremiumService loadPackages failed: $e');
      return const [];
    }
  }

  /// Purchase [package]; on success the entitlement flips immediately
  /// and listeners are notified.
  Future<PurchaseOutcome> purchase(PremiumPackage package) async {
    if (!_storeAvailable) return PurchaseOutcome.failed;
    await init();
    if (!_configured) return PurchaseOutcome.failed;
    try {
      final outcome = await _gateway.purchase(package);
      if (outcome == PurchaseOutcome.success) {
        _onEntitlementChanged(true);
      }
      return outcome;
    } catch (e) {
      debugPrint('PremiumService purchase failed: $e');
      return PurchaseOutcome.failed;
    }
  }

  /// Restore purchases made on another device or install.
  Future<RestoreOutcome> restore() async {
    if (!_storeAvailable) return RestoreOutcome.failed;
    await init();
    if (!_configured) return RestoreOutcome.failed;
    try {
      final restored = await _gateway.restore();
      _onEntitlementChanged(restored);
      return restored ? RestoreOutcome.restored : RestoreOutcome.noPurchases;
    } catch (e) {
      debugPrint('PremiumService restore failed: $e');
      return RestoreOutcome.failed;
    }
  }

  /// Store-provided subscription management URL, or null.
  Future<String?> managementUrl() async {
    if (!_storeAvailable) return null;
    try {
      return await _gateway.fetchManagementUrl();
    } catch (_) {
      return null;
    }
  }

  void _onEntitlementChanged(bool isPremium) {
    // Lapse detection: compare against the persisted last-known state
    // so an expiry that happened while the app was closed still
    // registers on the next launch.
    final wasPremium =
        _storePremium || (_prefs?.getBool('wasPremium') ?? false);
    if (isPremium) {
      premiumLapsed = false;
    } else if (wasPremium) {
      premiumLapsed = true;
    }
    _prefs?.setBool('wasPremium', isPremium);

    if (_storePremium == isPremium) {
      // State unchanged in-memory, but lapse may have just been
      // detected from the persisted flag — still notify in that case.
      if (premiumLapsed && wasPremium) notifyListeners();
      return;
    }
    _storePremium = isPremium;
    notifyListeners();
  }
}
