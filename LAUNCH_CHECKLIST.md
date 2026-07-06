# Decidr Launch Checklist

The code side of Phases 4–8 is done: paywall plumbing, entitlement wiring,
saved profiles, privacy fixes, and a green test suite. What remains is
account setup and store configuration that only a human with the accounts
can do. Work top to bottom.

## 1. RevenueCat + store accounts (blocks paid features)

- [ ] Apple Developer Program membership ($99/yr) — needed for TestFlight
      and App Store
- [ ] Create the app in App Store Connect (bundle id currently
      `com.example.decidrApp` — **change it first** in Xcode; example ids
      are rejected)
- [ ] In App Store Connect, create in-app purchases (suggested:
      `decidr_premium_monthly`, `decidr_premium_annual`,
      `decidr_premium_lifetime`)
- [ ] Create a RevenueCat account + project "Decidr"
  - [ ] Add the App Store app, paste the App Store Connect API key
  - [ ] Create entitlement **`premium`** (must match
        `PremiumService.entitlementId`)
  - [ ] Create an offering (default) with the packages
  - [ ] Copy the Apple API key → build with
        `--dart-define=REVENUECAT_API_KEY_APPLE=appl_...`
- [ ] Sandbox-test on a device: purchase, restore, refund revocation
- [ ] (Later) Google Play + `REVENUECAT_API_KEY_GOOGLE`; RevenueCat Web
      Billing + `REVENUECAT_API_KEY_WEB` if web purchases are wanted

## 2. App identity

- [ ] Change iOS/macOS bundle identifier from `com.example.decidrApp`
      (Xcode → Runner → Signing & Capabilities) — Android is already
      `com.decidr.app`; matching it (`com.decidr.app`) is a good choice
- [ ] Generate app icons: `flutter pub run flutter_launcher_icons`
      (verify `assets/icon/app_icon.png` is final art)
- [ ] Host PRIVACY_POLICY.md at a public URL (GitHub Pages works) and put
      the URL in App Store Connect / Play Console

## 3. Store metadata

- [ ] Screenshots (6.7", 6.1", iPad if targeting iPad)
- [ ] App description, keywords, category (Lifestyle)
- [ ] App Privacy questionnaire in App Store Connect — answers per
      PRIVACY_POLICY.md: location (approximate, app functionality, not
      linked to identity, opt-in), purchases via RevenueCat, no tracking
- [ ] Age rating questionnaire

## 4. Release builds

```bash
# iOS
flutter build ipa \
  --dart-define=OPENWEATHER_API_KEY=... \
  --dart-define=REVENUECAT_API_KEY_APPLE=appl_...

# Web (GitHub Pages; omit weather key to keep it out of the JS bundle,
# or use a separate revocable key)
flutter build web --base-href "/decidr-app/"
rm -rf docs && cp -r build/web docs
```

Notes:
- `DECIDR_PREMIUM_OVERRIDE` is ignored in release builds (kReleaseMode
  guard), so a leaked dev flag cannot unlock Premium in production.
- Any `OPENWEATHER_API_KEY` passed to a web build is readable in the
  shipped JavaScript — ship web without it, or use a key you can rotate.

## 5. Pre-submit smoke test

- [ ] `flutter analyze` → no issues, `flutter test` → all pass
- [ ] Fresh install: onboarding → questionnaire → deal → heart a card →
      appears in Profile favorites
- [ ] Settings: premium deck tap → paywall shows packages; purchase
      (sandbox) → deck applies without re-tapping
- [ ] Go-out card → Nearby (premium sandbox) → places render → Open in
      Maps works on device
- [ ] Location toggles OFF → no OS location prompt anywhere (weather stays
      pending until consent)
- [ ] Restore purchases on a second device/simulator
