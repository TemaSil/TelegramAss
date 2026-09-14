import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../app.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../common/tg_avatar.dart';

/// Picks who to write to: contacts and existing chats first, then whatever the
/// server can find by name once something is typed.
class NewMessageSheet extends StatefulWidget {
  const NewMessageSheet({super.key, required this.onPick});

  final ValueChanged<int> onPick;

  @override
  State<NewMessageSheet> createState() => _NewMessageSheetState();
}

class _NewMessageSheetState extends State<NewMessageSheet> {
  final _controller = TextEditingController();

  List<TgChat> _found = const [];
  Timer? _debounce;
  int _seq = 0;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    setState(() => _query = query);
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _found = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    final seq = ++_seq;
    final results = await AppScope.read(context).client.searchGlobal(query);
    if (!mounted || seq != _seq) return;
    setState(() => _found = results.chats);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l10n = AppL10n.of(context);
    final needle = _query.trim().toLowerCase();

    // Private chats and contacts are who you usually mean; groups follow.
    final known = <TgChat>[
      for (final chat in state.chats)
        if (!chat.isArchived &&
            (needle.isEmpty || chat.title.toLowerCase().contains(needle)))
          chat,
    ];
    final rows = <TgChat>[
      ...known,
      for (final chat in _found)
        if (!known.any((existing) => existing.id == chat.id)) chat,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CupertinoSearchTextField(
            controller: _controller,
            placeholder: l10n.searchChats,
            autofocus: true,
            onChanged: _onChanged,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final chat = rows[index];
                return CupertinoListTile.notched(
                  leading: TgAvatar(
                    seed: chat.id,
                    initials: chat.initials,
                    size: 38,
                    photoPath: chat.photoPath,
                  ),
                  title: Text(chat.title, maxLines: 1),
                  subtitle: Text(chat.presence, maxLines: 1),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => widget.onPick(chat.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
