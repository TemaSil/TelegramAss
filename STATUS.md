# Telegram Liquid — build status

Flutter Telegram client for Android, styled with the iOS 26 *Liquid Glass*
design language (`liquid_glass_widgets` 1.4.4).

**Current state: work in progress — the app does NOT compile yet.** Four screen
files referenced by the shell have not been written. Everything below is an
honest account of what exists and what is left.

## Environment

- Flutter **3.47.3** stable (latest stable; only beta 3.48.0-0.4.pre is newer).
  The glass package requires ≥ 3.41.
- Dependencies: `liquid_glass_widgets ^1.4.4`, `cupertino_icons`, `ffi`,
  `path_provider`.
- Android only so far (`flutter create --platforms=android`).

## Done

| File | What it does |
|---|---|
| `lib/core/tg_theme.dart` | iOS-style dynamic colour + type scale |
| `lib/core/glass_tokens.dart` | Glass vocabulary: chrome / panel / menu / bubble / composer presets |
| `lib/core/formatters.dart` | Time, day-separator, duration formatting |
| `lib/data/models.dart` | `TgChat`, `TgMessage`, `TgUser`, `TgStory`, `TgCall`, `TgFolder` |
| `lib/data/telegram_client.dart` | Backend-agnostic interface |
| `lib/data/demo_client.dart` | Offline backend: seeded chats, typing, delivery ticks, ambient traffic |
| `lib/data/tdlib/tdlib_ffi.dart` | `dart:ffi` bindings to `libtdjson` (`td_create_client_id` / `td_send` / `td_receive` / `td_execute`) |
| `lib/data/tdlib/tdlib_client.dart` | Real TDLib JSON backend: auth flow, chat list, history, send/edit/delete/react |
| `lib/data/app_state.dart` | `ChangeNotifier` state, folder + search filtering, preferences, backend selection |
| `lib/main.dart`, `lib/app.dart` | Shader preload, `LiquidGlassWidgets.wrap`, `AppScope` |
| `lib/ui/common/wallpaper.dart` | Animated mesh-gradient wallpaper (glass needs something to refract) |
| `lib/ui/common/tg_avatar.dart` | Gradient monogram avatar, story ring, presence dot |
| `lib/ui/auth/auth_screen.dart` | Phone → code → 2FA, glass card |
| `lib/ui/shell/root_shell.dart` | 4-tab `GlassScaffold` + `GlassTabBar.bottom` |
| `lib/ui/chats/chats_screen.dart` | Large title, search, folders, stories, chat list |
| `lib/ui/chats/widgets/chat_row.dart` | Row + long-press `GlassMenu` + glass unread badge + delivery ticks |
| `lib/ui/chats/widgets/story_rail.dart` | Horizontal stories strip |

## Missing — next session

1. `lib/ui/chat/chat_screen.dart` — conversation: pinned nav bar with avatar and
   presence, message list, day separators, typing indicator.
2. `lib/ui/chat/widgets/message_bubble.dart` — glass bubbles (outgoing tinted
   with the accent), reply quote, photo/voice/file kinds, reactions, upload
   progress, long-press context menu with a reaction row.
3. `lib/ui/chat/widgets/composer_bar.dart` — glass composer: text area,
   attach button opening `GlassModalSheet`, voice button.
4. `lib/ui/contacts/contacts_screen.dart` — `ContactsAppBar` + `ContactsBody`
   (grouped sections, alphabetical).
5. `lib/ui/calls/calls_screen.dart` — `CallsAppBar` + `CallsBody`
   (segmented All/Missed, call rows).
6. `lib/ui/settings/settings_screen.dart` — `SettingsAppBar` + `SettingsBody`
   (profile card, `GlassGroupedSection` + `GlassListTile`, `GlassSwitch`,
   `GlassSlider` for glass intensity, `GlassStepper` for font size,
   `GlassPicker` for wallpaper, backend row, log out).
7. `lib/ui/stories/story_viewer.dart` — full-screen viewer with
   `GlassPageControl`.
8. `flutter analyze` has never been run — expect API fixes across the board.
9. Android: `minSdk` 24+, `jniLibs/<abi>/libtdjson.so` slot, app label/icon.
10. README with build and TDLib-credential instructions.

## Backend modes

- **Demo** (default, no keys): code `12345`, 2FA password `telegram` (a phone
  number ending in `0` triggers the 2FA branch).
- **TDLib** (live): `flutter run --dart-define=TELEGRAM_API_ID=... --dart-define=TELEGRAM_API_HASH=...`
  plus `libtdjson.so` in `android/app/src/main/jniLibs/<abi>/`. Falls back to
  demo automatically when the native library is absent.

## Glass components in use so far

`GlassScaffold`, `GlassAppBar`, `GlassTabBar.bottom`, `GlassLargeTitle`,
`GlassSearchBar`, `GlassSegmentedControl.scrollable`, `GlassMenu`,
`GlassMenuItem`, `GlassMenuLabel`, `GlassMenuDivider`, `GlassPullDownButton`,
`GlassIconButton`, `GlassButton.custom`, `GlassCard`, `GlassContainer`,
`GlassChip`, `GlassToast`, `showGlassActionSheet`, `GlassFormField`,
`GlassTextField`, `GlassPasswordField`, `GlassProgressIndicator`.

Still to wire up: `GlassModalSheet`, `GlassDialog`, `GlassPopover`,
`GlassGroupedSection`, `GlassListTile`, `GlassSwitch`, `GlassSlider`,
`GlassStepper`, `GlassPicker`, `GlassPageControl`, `GlassBadge`,
`GlassButtonGroup`, `GlassDivider`, `GlassTextArea`, `GlassMaterialize`,
`ProgressiveBlur`, `GlassScrollEdgeEffect`, `GlassToolbar`.
