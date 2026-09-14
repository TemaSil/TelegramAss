import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../app.dart';
import '../../core/glass_tokens.dart';
import '../../core/tg_theme.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../chat/chat_screen.dart';
import '../stories/story_viewer.dart';
import 'archive_screen.dart';
import 'widgets/chat_row.dart';
import 'widgets/story_rail.dart';
import '../../core/tg_icons.dart';
import '../../l10n/app_localizations.dart';

/// Nav bar for the Chats tab: an Edit menu on the left, a filter pull-down
/// and a compose button on the right.
class ChatsAppBar extends StatelessWidget {
  const ChatsAppBar({super.key, required this.controller});

  final GlassLargeTitleController controller;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l10n = AppL10n.of(context);

    return GlassAppBar(
      toolbarHeight: 52,
      largeTitleController: controller,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      title: Text(l10n.chats, style: TgText.navTitle(context)),
      leading: _EditMenu(state: state),
      actions: [
        GlassPullDownButton(
          icon: const Icon(TgIcons.filter, size: 19),
          menuWidth: 240,
          quality: GlassQuality.premium,
          // The callback reports the item title, which is also the folder name.
          onSelected: (title) {
            final folder = state.folders.firstWhere(
              (folder) => _FolderBar.folderTitle(folder, l10n) == title,
              orElse: () => state.folders.first,
            );
            state.setFolder(folder.id);
          },
          items: [
            for (final folder in state.folders)
              GlassMenuItem(
                title: _FolderBar.folderTitle(folder, l10n),
                icon: Icon(
                  folder.id == state.activeFolder
                      ? TgIcons.selected
                      : TgIcons.unselected,
                ),
                onTap: () {},
              ),
          ],
        ),
        const SizedBox(width: 6),
        GlassIconButton(
          icon: const Icon(TgIcons.compose, size: 20),
          size: 44,
          settings: GlassTokens.chrome(context),
          quality: GlassQuality.premium,
          onPressed: () => GlassToast.show(
            context,
            message: l10n.newMessageHint,
            type: GlassToastType.info,
            icon: const Icon(TgIcons.compose, size: 18),
          ),
        ),
      ],
    );
  }
}

class _EditMenu extends StatelessWidget {
  const _EditMenu({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return GlassMenu(
      autoAdjustToScreen: true,
      menuWidth: 250,
      menuBorderRadius: 30,
      quality: GlassQuality.premium,
      settings: GlassTokens.menu(context),
      menuAlignment: GlassMenuAlignment.bottomLeft,
      triggerBuilder: (context, toggleMenu) => GlassButton.custom(
        onTap: toggleMenu,
        // Sized to the label: "Изменить" does not fit a fixed 68pt pill.
        width: null,
        height: 44,
        shape: const LiquidRoundedRectangle(borderRadius: 22),
        settings: GlassTokens.chrome(context),
        quality: GlassQuality.premium,
        useOwnLayer: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            widthFactor: 1,
            child: Text(
              l10n.edit,
              style: TextStyle(
                fontSize: 17,
                letterSpacing: -0.1,
                color: TgColors.label.resolveFrom(context),
              ),
            ),
          ),
        ),
      ),
      items: [
        GlassMenuLabel(title: l10n.chatList),
        GlassMenuItem(
          title: l10n.markAllAsRead,
          icon: const Icon(TgIcons.markRead),
          onTap: () {
            for (final chat in state.chats) {
              state.client.markChatRead(chat.id);
            }
          },
        ),
      ],
    );
  }
}

/// Scrollable content of the Chats tab.
class ChatsBody extends StatefulWidget {
  const ChatsBody({super.key, required this.controller});

  final GlassLargeTitleController controller;

  @override
  State<ChatsBody> createState() => _ChatsBodyState();
}

class _ChatsBodyState extends State<ChatsBody> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openChat(BuildContext context, TgChat chat) {
    final state = AppScope.read(context);
    // With read receipts off we do not tell the server the chat was opened.
    if (state.readReceipts) state.client.markChatRead(chat.id);
    Navigator.of(context).push(
      CupertinoPageRoute<void>(builder: (_) => ChatScreen(chatId: chat.id)),
    );
  }

  Future<void> _confirmDelete(BuildContext context, TgChat chat) async {
    await showGlassActionSheet<void>(
      context: context,
      title: chat.title,
      message: AppL10n.of(context).deleteChatMessage,
      settings: GlassTokens.menu(context),
      quality: GlassQuality.premium,
      actions: [
        GlassActionSheetAction(
          label: AppL10n.of(context).deleteChat,
          style: GlassActionSheetStyle.destructive,
          icon: const Icon(TgIcons.delete),
          onPressed: () {
            Navigator.of(context).pop();
            AppScope.read(context).client.deleteChat(chat.id);
            GlassToast.show(
              context,
              message: AppL10n.of(context).chatDeleted(chat.title),
              type: GlassToastType.success,
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l10n = AppL10n.of(context);
    final chats = state.visibleChats;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final topPad = MediaQuery.paddingOf(context).top;

    return CustomScrollView(
      controller: widget.controller.scrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: topPad + 52)),
        GlassLargeTitle(
          text: l10n.chats,
          controller: widget.controller,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          searchBar: CupertinoSearchTextField(
            controller: _searchController,
            placeholder: l10n.searchChats,
            onChanged: state.setSearchQuery,
            onSuffixTap: () {
              _searchController.clear();
              state.setSearchQuery('');
            },
          ),
        ),
        if (state.searchQuery.isEmpty) ...[
          SliverToBoxAdapter(
            child: StoryRail(
              stories: state.stories,
              onOpen: (index) => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => StoryViewerScreen(
                    stories: state.stories,
                    initialIndex: index,
                  ),
                  fullscreenDialog: true,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _FolderBar(state: state)),
          if (state.archivedChats.isNotEmpty && state.activeFolder != 'archive')
            SliverToBoxAdapter(
              child: _ArchiveRow(
                count: state.archivedChats.length,
                unread: state.archivedChats.fold<int>(
                  0,
                  (sum, chat) => sum + (chat.isMuted ? 0 : chat.unreadCount),
                ),
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (_) => const ArchiveScreen(),
                  ),
                ),
              ),
            ),
        ],
        if (chats.isEmpty)
          SliverToBoxAdapter(child: _EmptyState(query: state.searchQuery))
        else
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final chat = chats[index];
              return ChatRow(
                chat: chat,
                isTyping: state.typingChatId == chat.id,
                onTap: () => _openChat(context, chat),
                onPin: () {
                  HapticFeedback.selectionClick();
                  state.client.togglePin(chat.id);
                },
                onMute: () {
                  HapticFeedback.selectionClick();
                  state.client.toggleMute(chat.id);
                },
                onMarkRead: () => state.client.markChatRead(chat.id),
                onArchive: () {
                  HapticFeedback.selectionClick();
                  state.client.toggleArchive(chat.id);
                },
                onDelete: () => _confirmDelete(context, chat),
              );
            }, childCount: chats.length),
          ),
        SliverToBoxAdapter(child: SizedBox(height: 96 + bottomPad)),
      ],
    );
  }
}

/// Folder tabs.
///
/// Telegram's folder strip scrolls, which no Cupertino segmented control does,
/// and the glass one mis-measured segments whose labels carry a count — the
/// indicator drifted off its label. This is the plain iOS reading: a scrolling
/// row of labels, the selected one in a pill, the unread count beside it.
/// The row above the chat list that leads into the archive, the way iOS
/// Telegram surfaces it.
class _ArchiveRow extends StatelessWidget {
  const _ArchiveRow({
    required this.count,
    required this.unread,
    required this.onTap,
  });

  final int count;
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return CupertinoListSection.insetGrouped(
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      children: [
        CupertinoListTile.notched(
          leading: Icon(
            TgIcons.archive,
            color: TgColors.secondaryLabel.resolveFrom(context),
          ),
          title: Text(l10n.archivedChats),
          additionalInfo: Text('\$count'),
          trailing: unread > 0
              ? GlassBadge(
                  count: unread,
                  settings: GlassTokens.chrome(context),
                  child: const CupertinoListTileChevron(),
                )
              : const CupertinoListTileChevron(),
          onTap: onTap,
        ),
      ],
    );
  }
}

class _FolderBar extends StatelessWidget {
  const _FolderBar({required this.state});

  final AppState state;

  /// Folder names come from the backend as ids; the built-in set is
  /// translated, anything else (a server-side folder) keeps its own name.
  static String folderTitle(TgFolder folder, AppL10n l10n) {
    switch (folder.id) {
      case 'all':
        return l10n.folderAll;
      case 'personal':
        return l10n.folderPersonal;
      case 'groups':
        return l10n.folderGroups;
      case 'channels':
        return l10n.folderChannels;
      case 'unread':
        return l10n.folderUnread;
      case 'bots':
        return l10n.folderBots;
      default:
        return folder.title;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final folders = state.folders;

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: folders.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final folder = folders[index];
          final selected = folder.id == state.activeFolder;
          final unread = state.unreadInFolder(folder.id);
          final accent = TgColors.accent.resolveFrom(context);

          return CupertinoButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              state.setFolder(folder.id);
            },
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: 0.18)
                    : const Color(0x00000000),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    folderTitle(folder, l10n),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected
                          ? accent
                          : TgColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                  if (unread > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '$unread',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? accent
                            : TgColors.tertiaryLabel.resolveFrom(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
      child: GlassCard(
        padding: const EdgeInsets.all(26),
        shape: const LiquidRoundedSuperellipse(borderRadius: 30),
        settings: GlassTokens.panel(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              query.isEmpty ? TgIcons.chats : TgIcons.search,
              size: 34,
              color: TgColors.secondaryLabel.resolveFrom(context),
            ),
            const SizedBox(height: 12),
            Text(
              query.isEmpty ? l10n.noChatsInFolder : l10n.nothingFound,
              style: TgText.rowTitle(context),
            ),
            const SizedBox(height: 6),
            Text(
              query.isEmpty ? l10n.pickAnotherFolder : l10n.tryAnotherSearch,
              textAlign: TextAlign.center,
              style: TgText.rowPreview(context),
            ),
          ],
        ),
      ),
    );
  }
}
