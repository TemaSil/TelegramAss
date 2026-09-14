import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../app.dart';
import '../../core/glass_tokens.dart';
import '../../core/tg_theme.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../data/diagnostics.dart';
import '../common/wallpaper.dart';
import '../settings/proxy_sheet.dart';
import 'diagnostics_sheet.dart';
import '../../core/tg_icons.dart';
import '../../l10n/app_localizations.dart';

/// Phone → code → two-factor password, each step a glass card that
/// materialises over the wallpaper.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _phoneController = TextEditingController(text: '+7 900 000 00 00');
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// A live backend rejects a phone number until it has finished its
  /// handshake, so the button waits rather than failing silently.
  bool _canSubmit(AppState state, TgAuthStage stage) {
    if (stage != TgAuthStage.phone && stage != TgAuthStage.splash) return true;
    return state.client.isReadyForPhone;
  }

  Future<void> _submit() async {
    final state = AppScope.read(context);
    setState(() {
      _busy = true;
      _error = null;
    });

    TgAuthResult result;
    switch (state.stage) {
      case TgAuthStage.code:
        result = await state.client.submitCode(_codeController.text);
      case TgAuthStage.password:
        result = await state.client.submitPassword(_passwordController.text);
      case TgAuthStage.splash:
      case TgAuthStage.phone:
      case TgAuthStage.ready:
        result = await state.client.submitPhone(_phoneController.text);
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = result.error;
    });

    if (result.error != null) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l10n = AppL10n.of(context);
    final stage = state.stage;

    return GlassScaffold(
      background: const GlassWallpaper(variant: GlassWallpaper.none),
      settings: GlassTokens.chrome(context),
      statusBarStyle: GlassStatusBarStyle.light,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Logo(),
                const SizedBox(height: 28),
                GlassCard(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                  shape: const LiquidRoundedSuperellipse(borderRadius: 34),
                  settings: GlassTokens.panel(context),
                  quality: GlassQuality.premium,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _titleFor(stage, l10n),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
                          color: TgColors.label.resolveFrom(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _subtitleFor(stage, l10n),
                        textAlign: TextAlign.center,
                        style: TgText.rowPreview(context),
                      ),
                      const SizedBox(height: 22),
                      _field(stage, l10n),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: TgColors.destructive.resolveFrom(context),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 50,
                        child: CupertinoButton.filled(
                          onPressed: _busy || !_canSubmit(state, stage)
                              ? null
                              : _submit,
                          borderRadius: BorderRadius.circular(12),
                          padding: EdgeInsets.zero,
                          child: _busy
                              ? const CupertinoActivityIndicator(
                                  color: CupertinoColors.white,
                                )
                              : Text(
                                  stage == TgAuthStage.phone
                                      ? l10n.sendCode
                                      : l10n.continueAction,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _StatusBar(stage: stage),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Stock iOS controls: a login form is not a place for invented widgets.
  /// The glass is the card they sit on, not the field itself.
  Widget _field(TgAuthStage stage, AppL10n l10n) {
    switch (stage) {
      case TgAuthStage.code:
        return _LabelledField(
          label: l10n.confirmationCode,
          child: CupertinoTextField(
            controller: _codeController,
            placeholder: l10n.codeHint,
            keyboardType: TextInputType.number,
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, letterSpacing: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: _fieldDecoration(context),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onSubmitted: (_) => _submit(),
          ),
        );

      case TgAuthStage.password:
        return _LabelledField(
          label: l10n.twoStepVerification,
          helper: l10n.cloudPasswordHelper,
          child: CupertinoTextField(
            controller: _passwordController,
            placeholder: l10n.password,
            obscureText: true,
            autofocus: true,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: _fieldDecoration(context),
            onSubmitted: (_) => _submit(),
          ),
        );

      case TgAuthStage.splash:
      case TgAuthStage.phone:
      case TgAuthStage.ready:
        return _LabelledField(
          label: l10n.phoneNumber,
          child: CupertinoTextField(
            controller: _phoneController,
            placeholder: l10n.phoneHint,
            keyboardType: TextInputType.phone,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: _fieldDecoration(context),
            prefix: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Icon(
                TgIcons.calls,
                size: 18,
                color: TgColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
        );
    }
  }

  static BoxDecoration _fieldDecoration(BuildContext context) => BoxDecoration(
    color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
    borderRadius: BorderRadius.circular(10),
  );

  static String _titleFor(TgAuthStage stage, AppL10n l10n) {
    switch (stage) {
      case TgAuthStage.code:
        return l10n.enterCodeTitle;
      case TgAuthStage.password:
        return l10n.passwordTitle;
      default:
        return l10n.appName;
    }
  }

  static String _subtitleFor(TgAuthStage stage, AppL10n l10n) {
    switch (stage) {
      case TgAuthStage.code:
        return l10n.enterCodeSubtitle;
      case TgAuthStage.password:
        return l10n.passwordSubtitle;
      default:
        return l10n.signInSubtitle;
    }
  }
}

/// The iOS form idiom: a small caption above the control, helper text below.
class _LabelledField extends StatelessWidget {
  const _LabelledField({required this.label, required this.child, this.helper});

  final String label;
  final Widget child;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TgText.sectionHeader(context)),
        const SizedBox(height: 7),
        child,
        if (helper != null) ...[
          const SizedBox(height: 6),
          Text(helper!, style: TgText.timestamp(context)),
        ],
      ],
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      width: 96,
      height: 96,
      shape: const LiquidRoundedSuperellipse(borderRadius: 30),
      settings: GlassTokens.panel(context),
      quality: GlassQuality.premium,
      useOwnLayer: true,
      child: Center(
        child: Icon(
          TgIcons.logo,
          size: 42,
          color: TgColors.accent.resolveFrom(context),
        ),
      ),
    );
  }
}

/// Says which backend is actually running, and why the screen may be stuck.
///
/// Before this existed, a demo build and a live build that failed to connect
/// looked exactly the same: you typed a number, tapped the button, and no code
/// ever arrived.
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.stage});

  final TgAuthStage stage;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l10n = AppL10n.of(context);
    final client = state.client;
    final lastError = TgDiagnostics.instance.lastError;

    final String text;
    final bool isProblem;
    if (!client.isLive) {
      text = switch (stage) {
        TgAuthStage.code => l10n.demoCodeHint,
        TgAuthStage.password => l10n.demoPasswordHint,
        _ => l10n.demoBanner,
      };
      isProblem = true;
    } else if (lastError != null) {
      text = lastError.message;
      isProblem = true;
    } else if (!client.isReadyForPhone && stage != TgAuthStage.ready) {
      text = l10n.connecting;
      isProblem = false;
    } else {
      text = client.connectionState == 'connectionStateReady'
          ? 'TDLib · ${l10n.presenceOnline}'
          : 'TDLib';
      isProblem = false;
    }

    final color = isProblem
        ? TgColors.destructive.resolveFrom(context)
        : TgColors.secondaryLabel.resolveFrom(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isProblem ? TgIcons.failed : TgIcons.info,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.3, color: color),
              ),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LinkButton(
              label: l10n.diagnostics,
              onPressed: () => showDiagnosticsSheet(context),
            ),
            _LinkButton(
              label: l10n.proxy,
              onPressed: () => showProxySheet(context, state),
            ),
          ],
        ),
      ],
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      onPressed: onPressed,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      minimumSize: Size.zero,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: TgColors.accent.resolveFrom(context),
        ),
      ),
    );
  }
}
