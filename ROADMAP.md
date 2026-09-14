# What is done, what is missing

Compared against the official Telegram for Android and against
[Nekogram](https://github.com/Nekogram/Nekogram), a fork of it. Neither was
decompiled: this is a functional comparison, with Nekogram's own feature
toggles read from its `NekoConfig`.

Scale, for honesty: Nekogram is the official client plus patches — about
1.75M lines of Java in `TMessagesProj/src` and 1.28M lines of bundled C/C++
(ffmpeg, BoringSSL, tgcalls, ExoPlayer). This client is about 9k lines of Dart.
It also implements MTProto itself in C++ and does not use TDLib at all, which
is why it can carry calls and streaming media.

Its code cannot be reused here in any case: GPL-2.0 Java against Android views.
Ideas travel; lines do not.

Legend: **done** · **partial** — works but incomplete · **missing**

## Done since the first pass

Login with two-factor, chat list with folders and search, conversations with
replies, editing, deletion, reactions, drafts and forwarding, formatted text
with tappable links and spoilers, attachments that really attach (recent-photo
strip, camera, files), avatars and photos downloaded through TDLib's file API,
a full-screen photo viewer, audio and video shown with their metadata, static
stickers, contacts, call history, persisted settings, English and Russian,
MTProto and SOCKS5 proxy support, and an in-app diagnostics log.

## Conversation

| Feature | State |
|---|---|
| Text, replies, editing, deletion, reactions, drafts | done |
| Formatting, links, spoilers, mentions, hashtags | done |
| Sending photos, camera shots and files | done |
| Photos and avatars downloaded and viewable | done |
| Audio and video shown with title, duration and size | partial — metadata only, no playback |
| Stickers | partial — static WebP only; animated fall back to their emoji |
| Custom emoji | partial — the fallback emoji renders, the custom image does not |
| In-chat search | partial — local, no jump-to-message |
| Forwarding | partial — text, one message, no attribution header |
| Shared media grid | partial — placeholders, not real files |
| Voice recording and playback | missing |
| Link previews | missing |
| Polls, locations, contacts, albums | missing |
| Pinned messages | missing |
| Scheduled and silent send | missing |
| Threads and channel comments | missing |
| Multi-select and multi-forward | missing |
| Unread divider, scroll-to-bottom button | missing |

## Elsewhere

- **Chat list** — archived chats, swipe actions, selection mode and forum
  topics are missing; folders are a fixed set rather than the account's own.
- **Search** — local only; no server-side search across messages, people or
  public chats.
- **Groups and channels** — read-only. No member lists, admin tools,
  permissions, invite links, joining or leaving.
- **Notifications** — none at all. No FCM, no background service: messages
  arrive only while the app is open. This is the largest single gap.
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

Feasible now, since they touch only what is already implemented:

| Feature | Notes |
|---|---|
| Configurable double-tap action | we hardcode "react with ❤️" |
| Message details | date, id, sender, shown from the context menu |
| Copy photo, save file, open in browser | menu entries over existing media |
| Forward without quoting | a flag on the forward we already do |
| Time with seconds, no number rounding | formatting switches |
| Sticker size, system emoji | rendering preferences |
| Hide stories, hide the all-chats tab | visibility toggles |
| Show RPC errors | our diagnostics log already collects them |
| Prefer IPv6, download speed boost | TDLib options |
| Confirm before sending a voice message | a dialog before the send we have |

Need the base first:

| Feature | Blocked on |
|---|---|
| Message translation, auto-translate | a translation backend, and entities per message |
| Voice transcription | audio playback and a transcription service |
| Tablet / two-column layout | nothing structural, but a second layout to maintain |
| Ignore content restrictions | channel and group handling |
| Markdown parser options | a composer that parses markdown at all |
| QR login | an auth path we do not implement |

## Where to go next

1. **Notifications.** Without them this is not a messenger you can leave
   closed.
2. **Voice messages** — recording and playback; they are everywhere in real
   chats.
3. **Server-side search and the account's own folders.**
4. **Link previews**, the most visible remaining gap in ordinary conversation.
5. Then Nekogram's cheap toggles, which are a pleasant layer once the base
   holds.

Stickers, group administration and calls are each their own milestone, and
calls need a second native stack.
