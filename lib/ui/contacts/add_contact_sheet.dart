import 'package:flutter/cupertino.dart';

import '../../app.dart';
import '../../core/tg_theme.dart';
import '../../l10n/app_localizations.dart';

/// Adds someone by phone number, the way Telegram does it: the number is
/// looked up on the server, and a chat opens if anyone is registered on it.
class AddContactSheet extends StatefulWidget {
  const AddContactSheet({super.key, required this.onAdded});

  /// Called with the chat to open once the contact is in.
  final ValueChanged<int> onAdded;

  @override
  State<AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<AddContactSheet> {
  final _phone = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final phone = _phone.text.trim();
    if (phone.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final chatId = await AppScope.read(context).client
        .addContact(phone, _firstName.text.trim(), _lastName.text.trim());

    if (!mounted) return;
    if (chatId == null) {
      setState(() {
        _busy = false;
        _error = AppL10n.of(context).contactNotFound;
      });
      return;
    }
    widget.onAdded(chatId);
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
            l10n.addContact,
            textAlign: TextAlign.center,
            style: TgText.rowTitle(context),
          ),
          const SizedBox(height: 12),
          CupertinoListSection.insetGrouped(
            margin: EdgeInsets.zero,
            children: [
              CupertinoTextFormFieldRow(
                controller: _phone,
                placeholder: l10n.phoneNumber,
                keyboardType: TextInputType.phone,
                autofocus: true,
              ),
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
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: CupertinoColors.systemRed.resolveFrom(context),
              ),
            ),
          ],
          const SizedBox(height: 16),
          CupertinoButton.filled(
            onPressed: _busy ? null : _add,
            child: _busy
                ? const CupertinoActivityIndicator()
                : Text(l10n.addContact),
          ),
        ],
      ),
    );
  }
}
