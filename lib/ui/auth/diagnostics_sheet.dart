import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/glass_tokens.dart';
import '../../core/tg_icons.dart';
import '../../core/tg_theme.dart';
import '../../data/diagnostics.dart';
import '../../l10n/app_localizations.dart';

/// Shows the TDLib log.
///
/// The point is to make a stalled login explainable without a cable: whether
/// the native library loaded, what authorization state TDLib reached, and the
/// text of any error it returned.
Future<void> showDiagnosticsSheet(BuildContext context) {
  return GlassModalSheet.show<void>(
    context: context,
    halfSize: 0.7,
    settings: GlassTokens.panel(context),
    quality: GlassQuality.premium,
    builder: (_) => const _DiagnosticsSheet(),
  );
}

class _DiagnosticsSheet extends StatefulWidget {
  const _DiagnosticsSheet();

  @override
  State<_DiagnosticsSheet> createState() => _DiagnosticsSheetState();
}

class _DiagnosticsSheetState extends State<_DiagnosticsSheet> {
  late final _subscription = TgDiagnostics.instance.stream.listen((_) {
    if (mounted) setState(() {});
  });

  @override
  void initState() {
    super.initState();
    _subscription; // start listening
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final lines = TgDiagnostics.instance.lines;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l10n.diagnostics, style: TgText.rowTitle(context)),
              ),
              GlassIconButton(
                icon: const Icon(TgIcons.copy, size: 17),
                size: 38,
                settings: GlassTokens.chrome(context),
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: TgDiagnostics.instance.asText()),
                  );
                  GlassToast.show(
                    context,
                    message: l10n.diagnosticsCopied,
                    type: GlassToastType.success,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(l10n.diagnosticsHint, style: TgText.timestamp(context)),
          const SizedBox(height: 10),
          Expanded(
            child: lines.isEmpty
                ? Center(
                    child: Text(
                      l10n.diagnosticsEmpty,
                      style: TgText.rowPreview(context),
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    itemCount: lines.length,
                    itemBuilder: (context, index) {
                      final line = lines[lines.length - 1 - index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(line.stamp, style: TgText.timestamp(context)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                line.message,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.35,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                  color: switch (line.level) {
                                    TgLogLevel.error =>
                                      TgColors.destructive.resolveFrom(context),
                                    TgLogLevel.warning =>
                                      CupertinoColors.systemOrange.resolveFrom(
                                        context,
                                      ),
                                    TgLogLevel.info =>
                                      TgColors.label.resolveFrom(context),
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
