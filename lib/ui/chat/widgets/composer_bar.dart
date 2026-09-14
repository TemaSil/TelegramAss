import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../core/glass_tokens.dart';
import '../../../core/tg_theme.dart';
import '../../../data/models.dart';
import '../../../core/tg_icons.dart';
import '../../../l10n/app_localizations.dart';

/// Bottom composer: attachment button, growing text area, send / voice button.
///
/// The reply banner slides in above the field with [GlassMaterialize] so the
/// glass grows into place instead of popping.
class ComposerBar extends StatefulWidget {
  const ComposerBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onAttach,
    required this.onVoice,
    this.replyTo,
    this.editing,
    this.onCancelReply,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onVoice;
  final TgMessage? replyTo;
  final TgMessage? editing;
  final VoidCallback? onCancelReply;

  @override
  State<ComposerBar> createState() => _ComposerBarState();
}

class _ComposerBarState extends State<ComposerBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final banner = widget.editing ?? widget.replyTo;

    return Padding(
      padding: EdgeInsets.fromLTRB(10, 0, 10, bottomPad > 0 ? bottomPad : 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassMaterialize(
            visible: banner != null,
            alignment: Alignment.bottomCenter,
            child: banner == null
                ? const SizedBox.shrink()
                : _Banner(
                    message: banner,
                    isEdit: widget.editing != null,
                    onCancel: widget.onCancelReply,
                  ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GlassIconButton(
                icon: const Icon(TgIcons.attach, size: 22),
                size: 46,
                settings: GlassTokens.composer(context),
                quality: GlassQuality.premium,
                onPressed: widget.onAttach,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GlassContainer(
                  shape: const LiquidRoundedRectangle(borderRadius: 23),
                  settings: GlassTokens.composer(context),
                  quality: GlassQuality.premium,
                  child: CupertinoTextField(
                    controller: widget.controller,
                    placeholder: widget.editing != null
                        ? l10n.editMessage
                        : l10n.message,
                    minLines: 1,
                    maxLines: 5,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    style: TgText.body(context),
                    // The glass is the surface; the field must not paint a
                    // second one on top of it.
                    decoration: const BoxDecoration(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GlassIconButton(
                icon: Icon(_hasText ? TgIcons.send : TgIcons.voice, size: 21),
                size: 46,
                settings: GlassTokens.composer(context).copyWith(
                  glassColor: _hasText
                      ? TgColors.accent
                            .resolveFrom(context)
                            .withValues(alpha: 0.78)
                      : null,
                ),
                quality: GlassQuality.premium,
                glowColor: TgColors.accent.resolveFrom(context),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  if (_hasText) {
                    widget.onSend();
                  } else {
                    widget.onVoice();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.message,
    required this.isEdit,
    required this.onCancel,
  });

  final TgMessage message;
  final bool isEdit;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final accent = TgColors.accent.resolveFrom(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassContainer(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: const LiquidRoundedRectangle(borderRadius: 18),
        settings: GlassTokens.composer(context),
        child: Row(
          children: [
            Icon(
              isEdit ? TgIcons.edit : TgIcons.reply,
              size: 18,
              color: accent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isEdit
                        ? l10n.editMessage
                        : l10n.replyToSender(
                            message.senderName ?? l10n.message,
                          ),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                  Text(
                    message.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TgText.timestamp(context),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onCancel,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  TgIcons.close,
                  size: 17,
                  color: TgColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
