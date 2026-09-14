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
import 'widgets/chat_row.dart';
import 'widgets/story_rail.dart';
import '../../core/tg_icons.dart';

/// Nav bar for the Chats tab: an Edit menu on the left, a filter pull-down
/// and a compose button on the right.
class ChatsAppBar extends StatelessWidget {
  const ChatsAppBar({super.key, required this.controller});

  final GlassLargeTitleController controller;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return GlassAppBar(
      toolbarHeight: 52,
      largeTitleController: controller,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      title: Text('Chats', style: TgText.navTitle(context)),
      leading: _EditMenu(state: state),
      actions: [
        GlassPullDownButton(
          icon: const Icon(TgIcons.filter, size: 19),
          menuWidth: 240,
          quality: GlassQuality.premium,
          // The callback reports the item title, which is also the folder name.
          onSelected: (title) {
            final folder = state.folders.firstWhere(
              (folder) => folder.title == title,
              orElse: () => state.folders.first,
            );
            state.setFolder(folder.id);
          },
          items: [
            for (final folder in state.folders)
              GlassMenuItem(
                title: folder.title,
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
            message: 'New message — pick a contact from the Contacts tab',
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
    return GlassMenu(
      menuWidth: 250,
      menuBorderRadius: 30,
      quality: GlassQuality.premium,
      settings: GlassTokens.menu(context),
      menuAlignment: GlassMenuAlignment.bottomLeft,
      triggerBuilder: (context, toggleMenu) => GlassButton.custom(
        onTap: toggleMenu,
        width: 68,
        height: 44,
        shape: const LiquidRoundedRectangle(borderRadius: 22),
        settings: GlassTokens.chrome(context),
        quality: GlassQuality.premium,
        useOwnLayer: true,
        child: Center(
          child: Text(
            'Edit',
            style: TextStyle(
              fontSize: 17,
              letterSpacing: -0.1,
              color: TgColors.label.resolveFrom(context),
            ),
          ),
        ),
      ),
      items: [
        const GlassMenuLabel(title: 'Chat list'),
        GlassMenuItem(
          title: 'Mark all as read',
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
      message: 'This conversation will be removed from the list.',
      settings: GlassTokens.menu(context),
      quality: GlassQuality.premium,
      actions: [
        GlassActionSheetAction(
          label: 'Delete chat',
          style: GlassActionSheetStyle.destructive,
          icon: const Icon(TgIcons.delete),
          onPressed: () {
            Navigator.of(context).pop();
            AppScope.read(context).client.deleteChat(chat.id);
            GlassToast.show(
              context,
              message: '${chat.title} deleted',
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
          text: 'Chats',
          controller: widget.controller,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          searchBar: GlassSearchBar(
            controller: _searchController,
            placeholder: 'Search chats and messages',
            settings: GlassTokens.chrome(context),
            onChanged: state.setSearchQuery,
            onCancel: () {
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
                onDelete: () => _confirmDelete(context, chat),
              );
            }, childCount: chats.length),
          ),
        SliverToBoxAdapter(child: SizedBox(height: 96 + bottomPad)),
      ],
    );
  }
}

/// Folder selector — a scrollable segmented control with live unread counts.
class _FolderBar extends StatelessWidget {
  const _FolderBar({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final folders = state.folders;
    final selected = folders.indexWhere(
      (folder) => folder.id == state.activeFolder,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: GlassSegmentedControl.scrollable(
        selectedIndex: selected < 0 ? 0 : selected,
        onSegmentSelected: (index) {
          HapticFeedback.selectionClick();
          state.setFolder(folders[index].id);
        },
        height: 40,
        settings: GlassTokens.chrome(context),
        quality: GlassQuality.premium,
        indicatorColor: TgColors.accent
            .resolveFrom(context)
            .withValues(alpha: 0.22),
        selectedTextStyle: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: TgColors.label.resolveFrom(context),
        ),
        unselectedTextStyle: TextStyle(
          fontSize: 14.5,
          color: TgColors.secondaryLabel.resolveFrom(context),
        ),
        segments: [
          for (final folder in folders)
            GlassSegment(label: _labelFor(folder, state), id: folder.id),
        ],
      ),
    );
  }

  static String _labelFor(TgFolder folder, AppState state) {
    final unread = state.unreadInFolder(folder.id);
    return unread > 0 ? '${folder.title}  $unread' : folder.title;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
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
              query.isEmpty ? 'No chats in this folder' : 'Nothing found',
              style: TgText.rowTitle(context),
            ),
            const SizedBox(height: 6),
            Text(
              query.isEmpty
                  ? 'Pick another folder above'
                  : 'Try a different search term',
              textAlign: TextAlign.center,
              style: TgText.rowPreview(context),
            ),
          ],
        ),
      ),
    );
  }
}
