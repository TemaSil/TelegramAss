# Telegram Liquid (repository: TelegramAss)

A Flutter Telegram client for Android that has to feel like a **native iOS 26
app**. It speaks to real Telegram servers through the TDLib JSON interface
over `dart:ffi`, and falls back to a generated demo account when credentials
or the native library are missing.

Requires Flutter **3.47.3+** — `liquid_glass_widgets` needs ≥ 3.41 and
Impeller.

## This is not the Kotlin client

There is a sibling project, **TelegramYou**: a separate Android client in
Kotlin and Compose, styled after Material You. The two share no code and are
worked on in separate sessions. A request about Compose, Gradle or Material
You is about that project, not this one.

## Design rules — the ones that keep getting broken

These were settled by repeated correction. Treat them as constraints, not
preferences.

- **Controls are stock Cupertino.** `CupertinoTextField`, `CupertinoButton`,
  `CupertinoListSection.insetGrouped`, `CupertinoListTile.notched`,
  `CupertinoSearchTextField`, `CupertinoSlidingSegmentedControl`,
  `CupertinoActivityIndicator`. Settings and forms are built from these.
- **No invented widgets.** Do not hand-roll something iOS already provides,
  and do not imitate glass with gradients, opacity and blurs —
  "glassmorphism" was rejected explicitly and more than once. Real glass
  comes from `liquid_glass_widgets` or it does not happen.
- **Glass is only for what floats**: nav bars, the tab bar, sheets, context
  menus, the composer surface, badges. Not for content, not for forms.
  Switches are the exception among controls — `GlassSwitch`, not
  `CupertinoSwitch`, because iOS 26's switch is a glass one.
- **Bubbles are iMessage's**: solid blue and grey, tail on the last message
  of a run. Never translucent — text must not fight the wallpaper.
- **The coloured wallpaper appears only inside an open chat.** Every tab
  screen uses the system background.
- Custom painting only where iOS has no widget and Telegram does have the
  thing: monogram avatars, delivery ticks, the voice waveform, typing dots,
  the bubble outline, the wallpaper.

Icons are SF Symbols via `flutter_cupertino_symbols`, mapped semantically in
`lib/core/tg_icons.dart` — add new ones there, never inline.

Both **English and Russian** are supported and follow the system language.
Every user-visible string goes through `lib/l10n/*.arb` and `AppL10n`; run
`flutter gen-l10n` after editing them.

## Layout

```
lib/
  core/       glass tokens, colours, type scale, icons, formatters
  l10n/       app_en.arb, app_ru.arb + generated AppL10n
  data/
    models.dart           transport-agnostic view models
    telegram_client.dart  the backend interface every screen depends on
    demo_client.dart      offline backend
    tdlib/                FFI bindings, live backend, web stub
    app_state.dart        ChangeNotifier: chats, folders, search, preferences
    notifications.dart    foreground service + local notifications
    audio_player.dart     one shared player for voice and music
  ui/  auth/ shell/ chats/ chat/ contacts/ calls/ settings/ stories/ common/
```

**Adding a backend method means four files**: the interface plus
`demo_client.dart`, `tdlib/tdlib_client.dart` and `tdlib/tdlib_client_web.dart`.
They use `implements`, so a default body on the interface does not carry —
the analyzer will say so.

## Checks

```bash
flutter analyze        # must be clean
flutter test           # must pass
dart format lib test
bash tool/preview.sh   # web preview + README screenshots
```

Widget tests that mount glass hang: it needs a real GPU. Test the backends
and the pure logic with plain `test()`, as `test/app_smoke_test.dart` does.

`tool/tdlib_probe.dart` drives the real TDLib backend outside Flutter, which
is how protocol handling gets checked without a device or an account.

## Builds and releases

Work lands on `main`, and that is what the builds are for. Pushing there runs
two workflows: `.github/workflows/build-apk.yml`, which publishes a
`build-<run number>` GitHub release with debug and release APKs, and
`.github/workflows/deploy-web.yml`, which puts the web build on GitHub Pages
so a change can be looked at without installing anything.

The web copy always runs the demo account — TDLib has no web backend — and it
is built with no API credentials on purpose: a `--dart-define` becomes plain
JavaScript served to whoever opens the page.

- `.github/workflows/build-tdlib.yml` compiles `libtdjson` for the Android
  ABIs and publishes a `tdlib-<sha>` release. It takes over an hour and is
  run by hand. **Every APK build downloads libtdjson from that release —
  never delete a `tdlib-*` release.**
- `.github/workflows/cleanup.yml` removes old builds, by hand only, keeping
  the newest N. It matches `build-<number>` exactly so `tdlib-*` cannot be
  caught by it.
- Both variants are signed with the committed development key in
  `android/keystore`. That is deliberate — it makes each build install over
  the last instead of being rejected for a changed signature. It is a
  development key with a known password and must never sign a store release.

## Credentials — never commit them

`TELEGRAM_API_ID` and `TELEGRAM_API_HASH` reach the app only as
`--dart-define`, fed from repository secrets in CI. With neither set the app
runs the demo backend, and the login screen says which mode it is in.

**Do not commit an api_hash, and do not ask for one to put in a file git
tracks.** It cannot be reissued at my.telegram.org, so a committed hash is
public permanently, on an account that cannot be detached from it. Never ask
the user for a Telegram login code, and never log in to their account.

## When something does not work

`TgDiagnostics.instance` keeps a ring buffer surfaced by the Diagnostics
sheet on the login screen: whether the library loaded, whether credentials
were compiled in, every authorization and connection state, every error.
Where MTProto is filtered the connection sits in `connectionStateConnecting`
forever and no code is ever sent — that is a network problem, not a bug in
the client, and the Proxy sheet next to it exists for it.

## State of the project

`ROADMAP.md` is the honest account of what works and what does not, compared
against the official client and Nekogram. Keep it current: it is the file
that answers "what is still missing", and it is wrong the moment a feature
lands without it being updated.
