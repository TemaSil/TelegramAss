import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/glass_tokens.dart';
import '../../core/tg_theme.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';

/// Proxy settings.
///
/// Where Telegram's data centres are unreachable the connection never leaves
/// `connectionStateConnecting` and no login code is ever sent; a proxy is the
/// standard way out, so this is reachable from the login screen too.
Future<void> showProxySheet(BuildContext context, AppState state) {
  return GlassModalSheet.show<void>(
    context: context,
    halfSize: 0.72,
    settings: GlassTokens.panel(context),
    quality: GlassTokens.quality(context),
    builder: (_) => _ProxySheet(state: state),
  );
}

class _ProxySheet extends StatefulWidget {
  const _ProxySheet({required this.state});

  final AppState state;

  @override
  State<_ProxySheet> createState() => _ProxySheetState();
}

class _ProxySheetState extends State<_ProxySheet> {
  late final TgProxy? _initial = widget.state.proxy;

  late final _server = TextEditingController(text: _initial?.server ?? '');
  late final _port = TextEditingController(
    text: _initial?.port == null ? '' : '${_initial!.port}',
  );
  late final _secret = TextEditingController(text: _initial?.secret ?? '');
  late final _username = TextEditingController(text: _initial?.username ?? '');
  late final _password = TextEditingController(text: _initial?.password ?? '');

  late bool _enabled = _initial?.enabled ?? false;
  late int _type = (_initial?.type ?? 'mtproto') == 'socks5' ? 1 : 0;

  @override
  void dispose() {
    _server.dispose();
    _port.dispose();
    _secret.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _save() {
    final port = int.tryParse(_port.text.trim()) ?? 0;
    final proxy = TgProxy(
      type: _type == 1 ? 'socks5' : 'mtproto',
      server: _server.text.trim(),
      port: port,
      secret: _secret.text.trim(),
      username: _username.text.trim(),
      password: _password.text,
      enabled: _enabled,
    );

    final l10n = AppL10n.of(context);
    if (_enabled && !proxy.isValid) {
      GlassToast.show(
        context,
        message: l10n.proxyInvalid,
        type: GlassToastType.error,
      );
      return;
    }

    widget.state.setProxy(proxy.server.isEmpty ? null : proxy);
    Navigator.of(context).pop();
    GlassToast.show(
      context,
      message: _enabled ? l10n.proxyEnabled : l10n.proxyDisabled,
      type: GlassToastType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final isMtproto = _type == 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.proxy,
            textAlign: TextAlign.center,
            style: TgText.rowTitle(context),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.proxyHint,
            textAlign: TextAlign.center,
            style: TgText.timestamp(context),
          ),
          const SizedBox(height: 18),

          CupertinoSegmentedControl<int>(
            groupValue: _type,
            onValueChanged: (value) => setState(() => _type = value),
            children: const {
              0: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Text('MTProto'),
              ),
              1: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Text('SOCKS5'),
              ),
            },
          ),
          const SizedBox(height: 18),

          _Field(label: l10n.proxyServer, controller: _server),
          const SizedBox(height: 12),
          _Field(
            label: l10n.proxyPort,
            controller: _port,
            keyboardType: TextInputType.number,
            formatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 12),

          if (isMtproto)
            _Field(label: l10n.proxySecret, controller: _secret)
          else ...[
            _Field(label: l10n.proxyUsername, controller: _username),
            const SizedBox(height: 12),
            _Field(
              label: l10n.proxyPassword,
              controller: _password,
              obscure: true,
            ),
          ],

          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(l10n.proxyUse, style: TgText.rowTitle(context)),
              ),
              CupertinoSwitch(
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
            ],
          ),
          const SizedBox(height: 20),

          CupertinoButton.filled(
            onPressed: _save,
            borderRadius: BorderRadius.circular(12),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.formatters,
    this.obscure = false,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TgText.sectionHeader(context)),
        const SizedBox(height: 6),
        CupertinoTextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: formatters,
          obscureText: obscure,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }
}
