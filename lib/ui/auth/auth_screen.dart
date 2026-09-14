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
      background: const GlassWallpaper(variant: 'aurora'),
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
                        height: 54,
                        child: GlassButton.custom(
                          onTap: _submit,
                          enabled: !_busy && _canSubmit(state, stage),
                          shape: const LiquidRoundedRectangle(borderRadius: 27),
                          settings: GlassTokens.chrome(context),
                          quality: GlassQuality.premium,
                          useOwnLayer: true,
                          glowColor: TgColors.accent.resolveFrom(context),
                          child: Center(
                            child: _busy
                                ? const GlassProgressIndicator.circular(
                                    size: 22,
                                    strokeWidth: 2.5,
                                  )
                                : Text(
                                    stage == TgAuthStage.phone
                                        ? l10n.sendCode
                                        : l10n.continueAction,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: TgColors.accent.resolveFrom(
                                        context,
                                      ),
                                    ),
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

  Widget _field(TgAuthStage stage, AppL10n l10n) {
    switch (stage) {
      case TgAuthStage.code:
        return GlassFormField(
          label: l10n.confirmationCode,
          child: GlassTextField(
            controller: _codeController,
            placeholder: l10n.codeHint,
            keyboardType: TextInputType.number,
            autofocus: true,
            textStyle: const TextStyle(fontSize: 22, letterSpacing: 6),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            settings: GlassTokens.chrome(context),
            onSubmitted: (_) => _submit(),
          ),
        );
      case TgAuthStage.password:
        return GlassFormField(
          label: l10n.twoStepVerification,
          helperText: l10n.cloudPasswordHelper,
          child: GlassPasswordField(
            controller: _passwordController,
            placeholder: l10n.password,
            autofocus: true,
            settings: GlassTokens.chrome(context),
            onSubmitted: (_) => _submit(),
          ),
        );
      case TgAuthStage.splash:
      case TgAuthStage.phone:
      case TgAuthStage.ready:
        return GlassFormField(
          label: l10n.phoneNumber,
          child: GlassTextField(
            controller: _phoneController,
            placeholder: l10n.phoneHint,
            keyboardType: TextInputType.phone,
            prefixIcon: const Icon(TgIcons.calls, size: 19),
            settings: GlassTokens.chrome(context),
            onSubmitted: (_) => _submit(),
          ),
        );
    }
  }

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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassChip(
          label: text,
          icon: Icon(
            isProblem ? TgIcons.failed : TgIcons.info,
            size: 15,
            color: isProblem ? TgColors.destructive.resolveFrom(context) : null,
          ),
          settings: GlassTokens.chrome(context),
          labelStyle: TextStyle(
            fontSize: 13,
            color: isProblem
                ? TgColors.destructive.resolveFrom(context)
                : TgColors.secondaryLabel.resolveFrom(context),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => showDiagnosticsSheet(context),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              l10n.diagnostics,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: TgColors.accent.resolveFrom(context),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
