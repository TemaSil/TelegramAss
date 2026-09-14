import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../app.dart';
import '../../core/glass_tokens.dart';
import '../../core/tg_theme.dart';
import '../../l10n/app_localizations.dart';
import '../chat/chat_screen.dart';
import 'widgets/chat_row.dart';

/// The archive: the same chat list, over the chats the account put away.
class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l10n = AppL10n.of(context);
    final chats = state.archivedChats;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final topPad = MediaQuery.paddingOf(context).top;

    return GlassScaffold(
      settings: GlassTokens.chrome(context),
      statusBarStyle: GlassStatusBarStyle.auto,
      appBarHeight: 52,
      appBar: GlassAppBar.pinned(
        toolbarHeight: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        title: Text(l10n.archivedChats, style: TgText.navTitle(context)),
      ),
      body: chats.isEmpty
          ? Center(
              child: Text(
                l10n.archiveEmpty,
                style: TextStyle(
                  fontSize: 15,
                  color: TgColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.fromLTRB(0, topPad + 60, 0, bottomPad + 24),
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                return ChatRow(
                  chat: chat,
                  isTyping: state.typingChatId == chat.id,
                  onTap: () {
                    final unread = chat.unreadCount;
                    if (state.readReceipts) state.client.markChatRead(chat.id);
                    Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (_) =>
                            ChatScreen(chatId: chat.id, unreadCount: unread),
                      ),
                    );
                  },
                  onPin: () => state.client.togglePin(chat.id),
                  onMute: () => state.client.toggleMute(chat.id),
                  onMarkRead: () => state.client.markChatRead(chat.id),
                  onArchive: () {
                    HapticFeedback.selectionClick();
                    state.client.toggleArchive(chat.id);
                  },
                  onDelete: () => state.client.deleteChat(chat.id),
                );
              },
            ),
    );
  }
}
