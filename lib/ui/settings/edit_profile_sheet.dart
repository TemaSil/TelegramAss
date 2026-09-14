import 'package:flutter/cupertino.dart';

import '../../app.dart';
import '../../core/tg_theme.dart';
import '../../l10n/app_localizations.dart';

/// Edits the account's own name, bio and username.
class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({super.key});

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _bio;
  late final TextEditingController _username;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final me = AppScope.read(context).me;
    // Telegram stores the two names apart; we only carry the joined one, so
    // the split is by the first space, which is what the official clients do
    // when they show a single line.
    final parts = (me?.name ?? '').trim().split(RegExp(r'\s+'));
    _firstName = TextEditingController(text: parts.isEmpty ? '' : parts.first);
    _lastName = TextEditingController(
      text: parts.length > 1 ? parts.sublist(1).join(' ') : '',
    );
    _bio = TextEditingController(text: me?.bio ?? '');
    _username = TextEditingController(text: me?.username ?? '');
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _bio.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final state = AppScope.read(context);
    await state.client.updateProfile(
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      bio: _bio.text.trim(),
      username: _username.text.trim(),
    );
    state.refresh();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.editProfile,
            textAlign: TextAlign.center,
            style: TgText.rowTitle(context),
          ),
          const SizedBox(height: 12),
          CupertinoListSection.insetGrouped(
            margin: EdgeInsets.zero,
            children: [
              CupertinoTextFormFieldRow(
                controller: _firstName,
                placeholder: l10n.firstName,
                textCapitalization: TextCapitalization.words,
              ),
              CupertinoTextFormFieldRow(
                controller: _lastName,
                placeholder: l10n.lastName,
                textCapitalization: TextCapitalization.words,
              ),
              CupertinoTextFormFieldRow(
                controller: _username,
                placeholder: l10n.username,
                autocorrect: false,
              ),
              CupertinoTextFormFieldRow(
                controller: _bio,
                placeholder: l10n.bio,
                maxLines: 3,
              ),
            ],
          ),
          const SizedBox(height: 16),
          CupertinoButton.filled(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const CupertinoActivityIndicator()
                : Text(l10n.save),
          ),
        ],
      ),
    );
  }
}
