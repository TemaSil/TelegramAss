import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../core/formatters.dart';
import '../../../core/glass_tokens.dart';
import '../../../core/tg_theme.dart';
import '../../../data/models.dart';
import '../../../data/voice_recorder.dart';
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
    required this.onVoiceRecorded,
    this.replyTo,
    this.editing,
    this.onCancelReply,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  /// Called with the finished recording: the file, its length, and whether it
  /// is OGG/Opus — a true voice note — or the AAC fallback.
  final void Function(String path, int seconds, bool isOpus) onVoiceRecorded;
  final TgMessage? replyTo;
  final TgMessage? editing;
  final VoidCallback? onCancelReply;

  @override
  State<ComposerBar> createState() => _ComposerBarState();
}

class _ComposerBarState extends State<ComposerBar> {
  bool _hasText = false;

  /// Set while the mic is held down. The composer swaps the field for a timer
  /// and a slide-to-cancel hint, as the official clients do.
  bool _recording = false;
  bool _willCancel = false;
  Duration _elapsed = Duration.zero;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _tick?.cancel();
    // A take still running when the chat closes is abandoned, not sent.
    if (_recording) TgVoiceRecorder.instance.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (_recording) return;
    HapticFeedback.mediumImpact();
    final started = await TgVoiceRecorder.instance.start();
    if (!mounted) return;
    if (!started) {
      // No microphone permission, or no encoder. Saying nothing would look
      // like a dead button.
      await GlassDialog.show<void>(
        context: context,
        title: AppL10n.of(context).voiceUnavailable,
        message: AppL10n.of(context).voiceUnavailableMessage,
        settings: GlassTokens.menu(context),
        actions: [
          GlassDialogAction(
            label: AppL10n.of(context).ok,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
      return;
    }

    setState(() {
      _recording = true;
      _willCancel = false;
      _elapsed = Duration.zero;
    });
    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      setState(() => _elapsed = TgVoiceRecorder.instance.elapsed);
    });
  }

  Future<void> _finishRecording({required bool cancelled}) async {
    if (!_recording) return;
    _tick?.cancel();
    _tick = null;

    if (cancelled) {
      HapticFeedback.lightImpact();
      await TgVoiceRecorder.instance.cancel();
    } else {
      final recording = await TgVoiceRecorder.instance.stop();
      if (recording != null) {
        HapticFeedback.mediumImpact();
        widget.onVoiceRecorded(
          recording.path,
          recording.seconds,
          recording.isOpus,
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _recording = false;
      _willCancel = false;
      _elapsed = Duration.zero;
    });
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
                quality: GlassTokens.quality(context),
                onPressed: widget.onAttach,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _recording
                    ? _RecordingField(
                        elapsed: _elapsed,
                        willCancel: _willCancel,
                      )
                    : GlassContainer(
                        shape: const LiquidRoundedRectangle(borderRadius: 23),
                        settings: GlassTokens.composer(context),
                        quality: GlassTokens.quality(context),
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
              // Tap sends when there is text; otherwise the button is held to
              // record, and slid left to throw the take away.
              GestureDetector(
                onLongPressStart: _hasText ? null : (_) => _startRecording(),
                onLongPressMoveUpdate: _hasText
                    ? null
                    : (details) {
                        final willCancel =
                            details.localOffsetFromOrigin.dx < -70;
                        if (willCancel != _willCancel) {
                          setState(() => _willCancel = willCancel);
                        }
                      },
                onLongPressEnd: _hasText
                    ? null
                    : (_) => _finishRecording(cancelled: _willCancel),
                onLongPressCancel: _hasText
                    ? null
                    : () => _finishRecording(cancelled: true),
                child: GlassIconButton(
                  icon: Icon(
                    _hasText
                        ? TgIcons.send
                        : (_recording ? TgIcons.record : TgIcons.voice),
                    size: 21,
                  ),
                  size: 46,
                  settings: GlassTokens.composer(context).copyWith(
                    glassColor: _hasText
                        ? TgColors.accent
                              .resolveFrom(context)
                              .withValues(alpha: 0.78)
                        : (_recording
                              ? CupertinoColors.systemRed
                                    .resolveFrom(context)
                                    .withValues(alpha: 0.78)
                              : null),
                  ),
                  quality: GlassTokens.quality(context),
                  glowColor: _recording
                      ? CupertinoColors.systemRed.resolveFrom(context)
                      : TgColors.accent.resolveFrom(context),
                  onPressed: () {
                    if (!_hasText) return;
                    HapticFeedback.lightImpact();
                    widget.onSend();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Replaces the text field while a take is running: a pulsing red dot, the
/// elapsed time, and the hint that sliding left throws it away.
class _RecordingField extends StatelessWidget {
  const _RecordingField({required this.elapsed, required this.willCancel});

  final Duration elapsed;
  final bool willCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final red = CupertinoColors.systemRed.resolveFrom(context);

    return GlassContainer(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shape: const LiquidRoundedRectangle(borderRadius: 23),
      settings: GlassTokens.composer(context),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(shape: BoxShape.circle, color: red),
          ),
          const SizedBox(width: 10),
          Text(
            TgFormat.duration(elapsed),
            style: TgText.body(context)
                .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          const Spacer(),
          Text(
            willCancel ? l10n.releaseToCancel : l10n.slideToCancel,
            style: TextStyle(
              fontSize: 13,
              color: willCancel
                  ? red
                  : TgColors.secondaryLabel.resolveFrom(context),
            ),
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
