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
      state.visibleChats.every((chat) =>
          chat.title.toLowerCase().contains('design') ||
          (chat.lastMessage ?? '').toLowerCase().contains('design')),
      isTrue,
    );
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
}
