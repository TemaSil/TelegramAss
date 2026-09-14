import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../app.dart';
import '../../core/glass_tokens.dart';
import '../../core/tg_theme.dart';
import '../../data/models.dart';
import '../chat/chat_screen.dart';
import '../common/tg_avatar.dart';

/// Nav bar for the Contacts tab.
class ContactsAppBar extends StatelessWidget {
  const ContactsAppBar({super.key, required this.controller});

  final GlassLargeTitleController controller;

  @override
  Widget build(BuildContext context) {
    return GlassAppBar(
      toolbarHeight: 52,
      largeTitleController: controller,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      title: Text('Contacts', style: TgText.navTitle(context)),
      actions: [
        GlassIconButton(
          icon: const Icon(CupertinoIcons.person_badge_plus, size: 20),
          size: 44,
          settings: GlassTokens.chrome(context),
          quality: GlassQuality.premium,
          onPressed: () => GlassToast.show(
            context,
            message: 'Adding contacts needs the live TDLib backend',
            type: GlassToastType.info,
          ),
        ),
      ],
    );
  }
}

/// Alphabetically grouped contact list.
class ContactsBody extends StatefulWidget {
  const ContactsBody({super.key, required this.controller});

  final GlassLargeTitleController controller;

  @override
  State<ContactsBody> createState() => _ContactsBodyState();
}

class _ContactsBodyState extends State<ContactsBody> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Contacts bucketed by the first letter of their name.
  Map<String, List<TgUser>> _grouped(List<TgUser> contacts) {
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? contacts
        : contacts
            .where((user) =>
                user.name.toLowerCase().contains(query) ||
                (user.username ?? '').toLowerCase().contains(query))
            .toList();

    final groups = <String, List<TgUser>>{};
    for (final user in filtered) {
      final letter = user.name.isEmpty ? '#' : user.name[0].toUpperCase();
      groups.putIfAbsent(letter, () => []).add(user);
    }
    for (final bucket in groups.values) {
      bucket.sort((a, b) => a.name.compareTo(b.name));
    }
    return Map.fromEntries(
      groups.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final groups = _grouped(state.contacts);
    final online = state.contacts.where((user) => user.isOnline).length;
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
          text: 'Contacts',
          controller: widget.controller,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          searchBar: GlassSearchBar(
            controller: _searchController,
            placeholder: 'Search contacts',
            settings: GlassTokens.chrome(context),
            onChanged: (value) => setState(() => _query = value),
            onCancel: () {
              _searchController.clear();
              setState(() => _query = '');
            },
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
            child: Row(
              children: [
                GlassChip(
                  label: '${state.contacts.length} contacts',
                  icon: const Icon(CupertinoIcons.person_2, size: 15),
                  settings: GlassTokens.chrome(context),
                  labelStyle: TgText.rowPreview(context),
                ),
                const SizedBox(width: 8),
                GlassChip(
                  label: '$online online',
                  icon: Icon(
                    CupertinoIcons.circle_fill,
                    size: 10,
                    color: TgColors.teal.resolveFrom(context),
                  ),
                  settings: GlassTokens.chrome(context),
                  labelStyle: TgText.rowPreview(context),
                ),
              ],
            ),
          ),
        ),
        for (final entry in groups.entries)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: GlassGroupedSection(
                header: Text(entry.key, style: TgText.sectionHeader(context)),
                settings: GlassTokens.panel(context),
                quality: GlassQuality.premium,
                children: [
                  for (final user in entry.value)
                    GlassListTile(
                      leading: TgAvatar(
                        seed: user.id,
                        initials: user.initials,
                        size: 40,
                        isOnline: user.isOnline,
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              user.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (user.isVerified) ...[
                            const SizedBox(width: 4),
                            Icon(
                              CupertinoIcons.checkmark_seal_fill,
                              size: 14,
                              color: TgColors.accent.resolveFrom(context),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        user.isOnline
                            ? 'online'
                            : (user.lastSeen ?? user.username ?? ''),
                      ),
                      trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
                      onTap: () => Navigator.of(context).push(
                        CupertinoPageRoute<void>(
                          builder: (_) => ChatScreen(chatId: user.id),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (groups.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 56),
              child: Center(
                child: Text('Nothing found', style: TgText.rowPreview(context)),
              ),
            ),
          ),
        SliverToBoxAdapter(child: SizedBox(height: 96 + bottomPad)),
      ],
    );
  }
}
