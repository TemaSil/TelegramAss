# Telegram Liquid

A Flutter Telegram client for Android that presents as a native iOS 26 app,
built on the [`liquid_glass_widgets`](https://pub.dev/packages/liquid_glass_widgets)
shader-based Liquid Glass material.

Every surface that floats — nav bars, the tab bar, message bubbles, menus,
sheets, badges — is real refracting glass rendered by a fragment shader, over
an animated mesh-gradient wallpaper that gives the material something to bend.

## Requirements

- Flutter **3.47.3** or newer (the glass package needs ≥ 3.41 and Impeller)
- Android device or emulator; Impeller is the default renderer

## Run

```bash
flutter pub get
flutter run
```

That starts **demo mode**: a generated account with conversations, typing
indicators, delivery ticks and background traffic. The login code is `12345`;
a phone number ending in `0` also asks for the two-step password `telegram`.

## Live Telegram (TDLib)

The app speaks the official [TDLib JSON interface](https://core.telegram.org/tdlib/getting-started)
over `dart:ffi`, with the blocking `td_receive` loop in its own isolate.

1. Create an application at [my.telegram.org](https://my.telegram.org) →
   *API development tools*.
2. Drop `libtdjson.so` for each ABI into
   `android/app/src/main/jniLibs/<abi>/` (`arm64-v8a`, `armeabi-v7a`,
   `x86_64`).
3. Run with the credentials:

```bash
flutter run \
  --dart-define=TELEGRAM_API_ID=123456 \
  --dart-define=TELEGRAM_API_HASH=your_api_hash
```

Without credentials, or when the native library is missing, the app falls
back to demo mode instead of failing to start.

## Build an APK

CI builds both APKs on every push to `main` and uploads them as the
`telegram-liquid-apk` artifact — see `.github/workflows/build-apk.yml`.
Locally:

```bash
flutter build apk --release
```

## Project map

```
lib/
  core/          glass tokens, colour + type scale, formatters
  data/
    models.dart        transport-agnostic view models
    telegram_client.dart   backend interface
    demo_client.dart       offline backend
    tdlib/                 FFI bindings + live TDLib backend
    app_state.dart         ChangeNotifier state, folders, search, preferences
  ui/
    auth/          phone → code → 2FA
    shell/         four-tab GlassScaffold + GlassTabBar
    chats/         chat list, folders, stories, context menus
    chat/          conversation, bubbles, composer
    contacts/ calls/ settings/ stories/
    common/        wallpaper, avatars
```

## Screens

| Tab | What it shows |
|---|---|
| **Chats** | Large title that collapses into the bar, search, scrollable folder control with live unread counts, stories rail, rows with glass unread badges and a long-press menu |
| **Chat** | Glass bubbles (outgoing tinted with the accent), reply quotes, photo/voice/file messages, reactions, upload progress, day separators, animated typing bubble, attachment sheet |
| **Contacts** | Alphabetically grouped glass sections |
| **Calls** | All / Missed segmented control, call history |
| **Settings** | Profile card, wallpaper picker, glass intensity slider, text-size stepper, privacy switches, backend mode, log out |

## Licence

The Liquid Glass widgets are MIT-licensed by their author. This client is an
independent project and is not affiliated with Telegram.
