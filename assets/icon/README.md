# App Icon Setup

Place your icon files here:

## Required Files

1. **app_icon.png** (1024x1024 px)
   - Your main app icon
   - Used for iOS, web, and Windows
   - Should be square with no transparency for iOS

2. **app_icon_foreground.png** (1024x1024 px) - Optional but recommended for Android
   - The foreground layer for Android adaptive icons
   - Should have transparent background
   - Keep important content in the center 66% (safe zone)
   - The background color is set to #6750A4 (Material purple)

## Icon Design Tips

- Keep it simple - icons are viewed at small sizes
- Use bold shapes that are recognizable at 48x48px
- For Decidr: a spinning wheel, pie chart, or circular arrows work well
- Avoid text - it's unreadable at small sizes

## Quick Options to Create Icons

1. **Canva** (free): Search "app icon" templates
2. **Figma** (free): Use the iOS/Android icon templates
3. **AI generators**: "minimalist app icon spinning wheel decision purple"

## Generate Icons

After adding your icon files, run:

```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

This will generate all required icon sizes for Android, iOS, web, and Windows.
