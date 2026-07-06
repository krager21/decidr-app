# Decidr

Decidr deals you a card so you stop deliberating and start doing. Answer a
30-second questionnaire (where you are, how you feel, how much energy you
have), and the app deals three cards from a curated catalog of activities —
the middle one is yours. Favorite it, do it, or deal again.

**Live web build:** https://krager21.github.io/decidr-app/ (deployed from `/docs`)

## Features

- **Card deal** with mood/energy/weirdness/interest-aware scoring and
  graceful filter degradation
- **Personal context (opt-in)** — live weather and time of day bias the deal
- **Nearby places** (Premium) — "go out" cards surface real spots around you
  via OpenStreetMap Overpass
- **Themed card decks** (Premium) — Tarot, Forest, Sunset, Monochrome backs
- **Custom cards** — mix your own activities into the deck (free tier: 10)
- **Saved profiles** — snapshot questionnaire answers ("Date night",
  "Solo weeknight") and reapply them in one tap
- **History & feedback** — completed activities tracked; skips and dislikes
  tune future deals

## Development

```bash
flutter pub get
flutter test          # 143 tests
flutter analyze       # expected: no issues
flutter run           # macOS, iOS, Android, or Chrome
```

### Build-time configuration (`--dart-define`)

| Define | Purpose |
|---|---|
| `OPENWEATHER_API_KEY` | Enables the weather feature ([get a key](https://openweathermap.org/api)) |
| `REVENUECAT_API_KEY_APPLE` | RevenueCat key for iOS/macOS purchases |
| `REVENUECAT_API_KEY_GOOGLE` | RevenueCat key for Android purchases |
| `REVENUECAT_API_KEY_WEB` | RevenueCat Web Billing key |
| `DECIDR_PREMIUM_OVERRIDE` | `true` unlocks Premium for local testing (ignored in release builds) |

Without any defines the app runs fully featured on the free tier: weather
shows "not configured", and the paywall explains that purchases aren't
available in the build.

### Web deploy (GitHub Pages)

```bash
flutter build web --base-href "/decidr-app/"
rm -rf docs && cp -r build/web docs
git add docs && git commit -m "Deploy web"
```

See [LAUNCH_CHECKLIST.md](LAUNCH_CHECKLIST.md) for the store-release runbook
and [PRIVACY_POLICY.md](PRIVACY_POLICY.md) for the privacy policy.
