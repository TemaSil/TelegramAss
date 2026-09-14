import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../app.dart';
import '../../core/formatters.dart';
import '../../core/glass_tokens.dart';
import '../../core/tg_icons.dart';
import '../../core/tg_theme.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';

/// Devices signed in to the account, and a way to sign them out.
class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  List<TgSession>? _sessions;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sessions = await AppScope.read(context).client.activeSessions();
    if (!mounted) return;
    setState(() => _sessions = sessions);
  }

  Future<void> _terminate(TgSession session) async {
    final l10n = AppL10n.of(context);
    await GlassDialog.show<void>(
      context: context,
      title: l10n.terminateSession,
      message: session.deviceModel,
      settings: GlassTokens.menu(context),
      actions: [
        GlassDialogAction(
          label: l10n.cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        GlassDialogAction(
          label: l10n.terminate,
          isDestructive: true,
          onPressed: () async {
            Navigator.of(context).pop();
            await AppScope.read(context).client.terminateSession(session.id);
            await _load();
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final sessions = _sessions;
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return GlassScaffold(
      settings: GlassTokens.chrome(context),
      statusBarStyle: GlassStatusBarStyle.auto,
      appBarHeight: 52,
      appBar: GlassAppBar(
        toolbarHeight: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        title: Text(l10n.activeSessions, style: TgText.navTitle(context)),
        leading: GlassIconButton(
          icon: const Icon(TgIcons.back, size: 22),
          size: 42,
          settings: GlassTokens.chrome(context),
          quality: GlassTokens.quality(context),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: sessions == null
          ? const Center(child: CupertinoActivityIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(16, topPad + 60, 16, bottomPad + 24),
              children: [
                for (final session in sessions)
                  CupertinoListSection.insetGrouped(
                    margin: const EdgeInsets.only(bottom: 14),
                    header: Text(
                      session.isCurrent ? l10n.thisDevice : l10n.otherSessions,
                      style: TgText.sectionHeader(context),
                    ),
                    children: [
                      CupertinoListTile.notched(
                        leading: const Icon(TgIcons.sessions),
                        title: Text(session.deviceModel),
                        subtitle: Text(
                          [
                            session.appName,
                            session.platform,
                            if (session.location != null) session.location!,
                            if (session.ip != null) session.ip!,
                          ].where((part) => part.isNotEmpty).join('\n'),
                        ),
                        additionalInfo: session.lastActive == null
                            ? null
                            : Text(TgFormat.listStamp(session.lastActive)),
                      ),
                      if (!session.isCurrent)
                        CupertinoListTile.notched(
                          leading: Icon(
                            TgIcons.delete,
                            color: CupertinoColors.systemRed.resolveFrom(
                              context,
                            ),
                          ),
                          title: Text(
                            l10n.terminate,
                            style: TextStyle(
                              color: CupertinoColors.systemRed.resolveFrom(
                                context,
                              ),
                            ),
                          ),
                          onTap: () => _terminate(session),
                        ),
                    ],
                  ),
              ],
            ),
    );
  }
}
