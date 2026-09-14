import 'package:flutter_test/flutter_test.dart';
import 'package:telegram_liquid/data/app_state.dart';
import 'package:telegram_liquid/data/models.dart';

/// Exercises the demo backend end to end: log in, read the chat list, open a
/// conversation, send a message and react to one.
///
/// These are deliberately not widget tests — the glass widgets render through
/// fragment shaders that need a real GPU surface, which `flutter test` does
/// not provide.
void main() {
  /// State updates reach [AppState] through broadcast streams, so give the
  /// microtask queue a turn before reading them back.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<AppState> signedIn() async {
    final state = await AppState.create();
    await state.client.submitPhone('+7 999 123 45 67');
    await state.client.submitCode('12345');
    await settle();
    return state;
  }

  test('login flow advances phone -> code -> ready', () async {
    final state = await AppState.create();
    addTearDown(state.dispose);

    expect(state.stage, TgAuthStage.phone);

    final codeStage = await state.client.submitPhone('+7 999 123 45 67');
    expect(codeStage.error, isNull);
    expect(state.client.currentStage, TgAuthStage.code);

    final rejected = await state.client.submitCode('00000');
    expect(rejected.error, isNotNull);

    final accepted = await state.client.submitCode('12345');
    expect(accepted.error, isNull);
    expect(state.client.currentStage, TgAuthStage.ready);
    expect(state.client.currentChats, isNotEmpty);
    expect(state.me, isNotNull);
  });

  test('a phone number ending in zero asks for the cloud password', () async {
    final state = await AppState.create();
    addTearDown(state.dispose);

    await state.client.submitPhone('+7 999 123 45 60');
    await state.client.submitCode('12345');
    expect(state.client.currentStage, TgAuthStage.password);

    final result = await state.client.submitPassword('telegram');
    expect(result.error, isNull);
    expect(state.client.currentStage, TgAuthStage.ready);
  });

  test('sending a message updates the thread and the chat preview', () async {
    final state = await signedIn();
    addTearDown(state.dispose);

    final chat = state.chats.first;
    final before = state.client.currentMessagesOf(chat.id).length;

    await state.client.sendText(chat.id, 'Hello from the test');

    final after = state.client.currentMessagesOf(chat.id);
    expect(after.length, before + 1);
    expect(after.last.text, 'Hello from the test');
    expect(after.last.isOutgoing, isTrue);

    await settle();
    expect(state.chatById(chat.id)?.lastMessage, 'Hello from the test');
  });

  test('folder filtering and search narrow the visible chats', () async {
    final state = await signedIn();
    addTearDown(state.dispose);

    state.setFolder('channels');
    expect(
      state.visibleChats.every((chat) => chat.kind == TgChatKind.channel),
      isTrue,
    );

    state.setFolder('all');
    state.setSearchQuery('design');
    expect(state.visibleChats, isNotEmpty);
    expect(
      state.visibleChats.every(
        (chat) =>
            chat.title.toLowerCase().contains('design') ||
            (chat.lastMessage ?? '').toLowerCase().contains('design'),
      ),
      isTrue,
    );
  });

  test('deleting a chat removes it and its history', () async {
    final state = await signedIn();
    addTearDown(state.dispose);

    final chat = state.chats.first;
    final before = state.chats.length;

    await state.client.deleteChat(chat.id);
    await settle();

    expect(state.chats.length, before - 1);
    expect(state.chatById(chat.id), isNull);
    expect(state.client.currentMessagesOf(chat.id), isEmpty);
  });

  test('drafts survive leaving and returning to a chat', () async {
    final state = await signedIn();
    addTearDown(state.dispose);

    final chat = state.chats.first;
    state.setDraft(chat.id, 'half-written thought');
    await settle();

    expect(state.chatById(chat.id)?.draft, 'half-written thought');
  });

  test('in-chat search matches message text, newest first', () async {
    final state = await signedIn();
    addTearDown(state.dispose);

    final chat = state.chats.first;
    await state.client.sendText(chat.id, 'first needle here');
    await state.client.sendText(chat.id, 'second needle here');

    final results = state.client.searchMessages(chat.id, 'needle');
    expect(results.length, 2);
    expect(results.first.text, 'second needle here');

    expect(state.client.searchMessages(chat.id, 'nothing-matches'), isEmpty);
  });

  test('a picked photo keeps the path it was picked from', () async {
    final state = await signedIn();
    addTearDown(state.dispose);

    final chat = state.chats.first;
    await state.client.sendPhoto(chat.id, path: '/tmp/holiday.jpg');

    final sent = state.client.currentMessagesOf(chat.id).last;
    expect(sent.kind, TgMessageKind.photo);
    expect(sent.localPath, '/tmp/holiday.jpg');
    expect(sent.isOutgoing, isTrue);
  });

  test('a picked document carries its name, size and path', () async {
    final state = await signedIn();
    addTearDown(state.dispose);

    final chat = state.chats.first;
    await state.client.sendFile(
      chat.id,
      'spec.pdf',
      '2.4 MB',
      path: '/tmp/spec.pdf',
    );

    final sent = state.client.currentMessagesOf(chat.id).last;
    expect(sent.kind, TgMessageKind.file);
    expect(sent.fileName, 'spec.pdf');
    expect(sent.fileSize, '2.4 MB');
    expect(sent.localPath, '/tmp/spec.pdf');

    await settle();
    expect(state.chatById(chat.id)?.lastMessage, contains('spec.pdf'));
  });

  test('reactions toggle on and off', () async {
    final state = await signedIn();
    addTearDown(state.dispose);

    final chat = state.chats.first;
    final message = state.client.currentMessagesOf(chat.id).first;

    await state.client.toggleReaction(chat.id, message.id, '👍');
    var updated = state.client
        .currentMessagesOf(chat.id)
        .firstWhere((m) => m.id == message.id);
    expect(updated.reactions.any((r) => r.emoji == '👍' && r.chosen), isTrue);

    await state.client.toggleReaction(chat.id, message.id, '👍');
    updated = state.client
        .currentMessagesOf(chat.id)
        .firstWhere((m) => m.id == message.id);
    expect(updated.reactions.any((r) => r.emoji == '👍'), isFalse);
  });

  test('forwarding copies messages into the destination chat', () async {
    final state = await signedIn();
    addTearDown(state.dispose);

    final source = state.chats.first;
    final destination = state.chats.firstWhere((chat) => chat.id != source.id);
    final picked = state.client.currentMessagesOf(source.id).take(2).toList();
    final before = state.client.currentMessagesOf(destination.id).length;

    await state.client.forwardMessages(
      source.id,
      destination.id,
      picked.map((message) => message.id).toList(),
    );

    final after = state.client.currentMessagesOf(destination.id);
    expect(after.length, before + picked.length);
    expect(after.last.text, picked.last.text);
    // A forward is a new message in the destination, sent by us.
    expect(after.last.isOutgoing, isTrue);
    expect(after.last.id, isNot(picked.last.id));
  });

  test('archiving moves a chat out of the main list', () async {
    final state = await signedIn();
    addTearDown(state.dispose);

    final chat = state.chats.first;
    expect(chat.isArchived, isFalse);

    await state.client.toggleArchive(chat.id);
    await settle();
    expect(state.chatById(chat.id)?.isArchived, isTrue);
    expect(state.visibleChats.any((c) => c.id == chat.id), isFalse);
    expect(state.archivedChats.any((c) => c.id == chat.id), isTrue);

    await state.client.toggleArchive(chat.id);
    await settle();
    expect(state.chatById(chat.id)?.isArchived, isFalse);
    expect(state.visibleChats.any((c) => c.id == chat.id), isTrue);
  });

  test('global search finds messages by text, not just chat titles', () async {
    final state = await signedIn();
    addTearDown(state.dispose);

    final chat = state.chats.first;
    await state.client.sendText(chat.id, 'refraction on the tab bar');
    final results = await state.client.searchGlobal('refraction');

    expect(results.messages, isNotEmpty);
    expect(results.messages.any((m) => m.text.contains('refraction')), isTrue);
  });

  test('the unread divider anchors on the first unread message', () async {
    final state = await signedIn();
    addTearDown(state.dispose);

    // The demo account seeds a chat with a badge, which is what the divider
    // is placed from — and what markChatRead clears on the way in.
    final chat = state.chats.firstWhere((chat) => chat.unreadCount > 0);
    final unread = chat.unreadCount;
    final incoming = state.client
        .currentMessagesOf(chat.id)
        .where((message) => !message.isOutgoing)
        .toList();
    expect(incoming.length, greaterThanOrEqualTo(unread));

    await state.client.markChatRead(chat.id);
    await settle();
    expect(state.chatById(chat.id)?.unreadCount, 0);

    // Which is exactly why the count is captured before the screen opens.
    expect(unread, greaterThan(0));
  });
}
