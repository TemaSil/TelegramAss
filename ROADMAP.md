# What is done, what is missing

Compared against the official Telegram for Android and against
[Nekogram](https://github.com/Nekogram/Nekogram), a fork of it. Neither was
decompiled: this is a functional comparison, with Nekogram's own feature
toggles read from its `NekoConfig`.

Scale, for honesty — and because the line counts are easy to misread. Nekogram
is the official Telegram for Android with about eighty patches on top: roughly
1.75M lines of Java in `TMessagesProj/src` and 1.28M of bundled C/C++ (ffmpeg,
BoringSSL, tgcalls, ExoPlayer). That number measures a finished product with
fifteen years of history, not better craft, and most of it is not protocol work
at all: it is media codecs, calls, and every screen Telegram has ever shipped.
Nekogram's own contribution is a few thousand lines of preferences.

This client is about 12.5k lines of Dart because TDLib does the protocol — the
same library Telegram publishes and their own desktop clients use. TDLib is not
what limits anything here; what is missing is UI that has not been written yet,
plus two things TDLib genuinely does not carry: voice and video calls, which
need `tgcalls` and its own native build per ABI.

Its code cannot be reused here in any case: GPL-2.0 Java against Android views.
Ideas travel; lines do not.

Legend: **done** · **partial** — works but incomplete · **missing**

## Done since the first pass

Login with two-factor; the account's own chat folders and the archive; search
that asks the server — chats, public chats and message text across every
conversation; conversations with replies, editing, deletion, reactions, drafts,
selection mode and forwarding through TDLib with its attribution intact;
formatted text with tappable links and spoilers; unfurled link previews; the
unread divider and a jump-to-latest button; pinned messages with a bar and
jump-to-message; attachments that really attach (recent-photo strip, camera,
files); avatars and photos downloaded through TDLib's file API; a full-screen
photo viewer; voice notes and music that play, and voice recording;
notifications through a foreground service, with no Firebase; static stickers;
contacts; call history; persisted settings; English and Russian; MTProto and
SOCKS5 proxy support; and an in-app diagnostics log.

## Conversation

| Feature | State |
|---|---|
| Text, replies, editing, deletion, reactions, drafts | done |
| Formatting, links, spoilers, mentions, hashtags | done |
| Sending photos, camera shots and files | done |
| Photos and avatars downloaded and viewable | done |
| Voice notes and music: playback, scrubbing, waveform progress | done |
| Voice recording — hold to record, slide to cancel | done |
| Link previews | done |
| Pinned messages, with a bar and jump-to-message | done |
| Unread divider and jump-to-latest | done |
| Multi-select and multi-forward, with attribution | done |
| Video shown with title, duration and size | partial — poster only, no playback |
| Stickers | partial — static WebP only; animated fall back to their emoji |
| Custom emoji | partial — the fallback emoji renders, the custom image does not |
| In-chat search | partial — local text, but results jump to the message |
| Shared media grid | partial — placeholders, not real files |
| Video playback | missing |
| Polls, locations, contacts, albums | missing |
| Scheduled and silent send | missing |
| Threads and channel comments | missing |

## Elsewhere

- **Chat list** — the account's folders and the archive are in; chat-level
  selection mode and forum topics are not.
- **Search** — server-side across chats, public chats and messages. Searching
  within one chat is still local to the loaded history.
- **Groups and channels** — read-only. No member lists, admin tools,
  permissions, invite links, joining or leaving.
- **Notifications** — a foreground service holds the TDLib connection and each
  new message becomes a local notification, which needs no Firebase project.
  Tapping one opens the chat. Not covered: in-app notification settings per
  chat beyond mute, and delivery when the service is killed by the system.
- **Privacy and sessions** — the rows exist, nothing stands behind them.
- **Calls** — impossible through TDLib, which carries neither voice nor video.
  They need `tgcalls` with its own native build for every ABI: a project in
  itself.
- **Platform** — no deep links, share-sheet integration, or passcode lock.

## Engineering

- Release APKs are signed with the committed development key; a store release
  needs its own.
- No ProGuard/R8 rules for the TDLib JNI surface.
- The app name and icon reuse Telegram branding and must change before any
  public distribution.

## Nekogram's own additions

These are what Nekogram adds *on top of* a complete client. Most are small
client-side behaviours, which makes them cheap here — but they are a layer over
a base this client does not have yet, so they are listed after it.

Done:

| Feature | Notes |
|---|---|
| Configurable double-tap action | choose the emoji, or turn it off |
| Message details | date, id, sender, from the context menu |
| Forward without quoting | its own menu entry |
| Hide stories | Settings → Extras |

Still cheap, since they touch only what is already implemented:

| Feature | Notes |
|---|---|
| Copy photo, save file, open in browser | menu entries over existing media |
| Time with seconds, no number rounding | formatting switches |
| Sticker size, system emoji | rendering preferences |
| Hide the all-chats tab | a visibility toggle |
| Show RPC errors | our diagnostics log already collects them |
| Prefer IPv6, download speed boost | TDLib options |
| Confirm before sending a voice message | a dialog before the send we have |

Need the base first:

| Feature | Blocked on |
|---|---|
| Message translation, auto-translate | a translation backend, and entities per message |
| Voice transcription | a transcription service; playback is in |
| Tablet / two-column layout | nothing structural, but a second layout to maintain |
| Ignore content restrictions | channel and group handling |
| Markdown parser options | a composer that parses markdown at all |
| QR login | an auth path we do not implement |

## Where to go next

1. **Animated stickers and custom emoji.** The most visible thing left in an
   ordinary conversation: both currently fall back to an emoji.
2. **Video playback**, which needs a player and TDLib's streaming download.
3. **Group and channel administration** — member lists, permissions, invite
   links, joining and leaving.
4. **Polls, locations and albums.**
5. Then the rest of the mod toggles, which are a pleasant layer now that the
   base holds.

Calls remain their own milestone and need a second native stack.
