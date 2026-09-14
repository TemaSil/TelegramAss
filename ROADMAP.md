# Gap analysis against the official Telegram client

Written by comparing this client's code (~7.7k lines of Dart) against the
feature set of the official Telegram for Android. The official APK was not
decompiled — this is a functional comparison, not a binary diff.

Legend: **done** · **partial** — works but incomplete · **missing**

## Authorization

| Feature | State |
|---|---|
| Phone → code → two-step password | done |
| Log out | done |
| QR-code login | missing |
| Multiple accounts | missing |
| Sign-up for a new account | missing |
| Email login codes, password recovery | missing |
| Active session list, terminating sessions | missing (row exists, no backing) |

## Chat list

| Feature | State |
|---|---|
| Chat list, pin, mute, delete, unread counters | done |
| Folders | partial — six fixed folders; the account's own `chatFolders` are not read |
| Search | partial — local, over loaded titles and previews; no server-side global search for messages, people or public chats |
| Stories rail | partial — UI works, data is demo-only |
| Archived chats | missing |
| Swipe actions on a row | missing |
| Selection mode and bulk actions | missing |
| Forum topics | missing |
| Secret chats | missing |

## Conversation

| Feature | State |
|---|---|
| Text send, reply, edit, delete | done |
| Reactions | partial — one fixed emoji row; no custom or paid reactions, no reaction list |
| Drafts | done |
| In-chat search | partial — local only, no jump-to-message |
| Forwarding | partial — text only, single message, no attribution header |
| Day separators, typing indicator, delivery state | done |
| Shared-media grid | partial — renders placeholders, no real files |
| Sending real photos, files and voice | missing — no picker, no recorder; TDLib requests are shaped but carry no file |
| Viewing and downloading media | missing |
| Text formatting (bold, italic, code, spoiler, links) | missing |
| Link previews | missing |
| Stickers, GIFs, custom emoji | missing |
| Polls, locations, contacts, albums | missing |
| Pinned messages | missing |
| Scheduled and silent send | missing |
| Message threads and channel comments | missing |
| Multi-select, multi-forward | missing |
| Unread divider, scroll-to-bottom button | missing |
| Translation, voice-to-text | missing |

## Groups and channels

Effectively absent. Member lists, admin tools and permissions, invite links,
joining and leaving, channel posting, comment sections, slow mode and topics
are all missing. Broadcast channels are now typed correctly, and that is the
extent of it.

## Calls

The Calls tab renders history from demo data. Real calls are not just
unimplemented — **TDLib does not carry voice or video**. Calls need the
separate `tgcalls` WebRTC stack with its own native build, which is a project
of its own. Group calls and video chats likewise.

## Media and storage

No file downloading, no cache management, no avatar photos (avatars are
generated monograms), no storage usage screen, no auto-download rules.

## Notifications

None. No FCM registration, no notification channels, no background service,
no in-app sounds. The app only receives updates while it is open.

## Settings

| Feature | State |
|---|---|
| Appearance, wallpaper, glass intensity, text size | done |
| Read receipts toggle | partial — gates whether opening a chat is reported |
| Privacy (last seen, who can call, blocked users) | missing |
| Data and storage | missing |
| Notification settings | missing |
| Language | missing — the UI is English only |
| Premium | missing |

## Platform integration

Deep links (`t.me/...`), the system share sheet, biometric or passcode lock,
widgets and backup are all missing.

## Engineering

- Never run on a physical device or emulator: verification so far is
  `flutter analyze`, ten tests and a successful APK build.
- Release APKs are signed with the debug key; no keystore is configured.
- No ProGuard/R8 rules for the TDLib JNI surface.
- TDLib errors are not surfaced in the UI.
- The app name and icon reuse Telegram branding and must change before any
  public distribution.

## What is worth doing next

1. **Attachments that actually attach** — an image picker and a voice recorder
   wired to `inputFileLocal`, plus file download and display. Without this the
   client cannot be used as a daily driver.
2. **Real avatars and photos** — download chat photos and message media through
   TDLib's file API.
3. **Notifications** — FCM plus a background connection, otherwise messages
   only arrive while the app is open.
4. **Server-side search and the account's own folders.**
5. **Text formatting and link previews** — the most visible gap in everyday
   conversation.

Calls, stickers and group administration are each large enough to be their own
milestone, and calls in particular require a second native stack.
