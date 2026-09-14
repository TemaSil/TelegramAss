import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../app.dart';
import '../../core/glass_tokens.dart';
import '../../core/tg_theme.dart';
import '../../data/models.dart';
import '../common/wallpaper.dart';
import '../../core/tg_icons.dart';

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
                        _titleFor(stage),
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
                        _subtitleFor(stage),
                        textAlign: TextAlign.center,
                        style: TgText.rowPreview(context),
                      ),
                      const SizedBox(height: 22),
                      _field(stage),
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
                          enabled: !_busy,
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
                                        ? 'Send code'
                                        : 'Continue',
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
                if (!state.client.isLive) _DemoHint(stage: stage),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TgAuthStage stage) {
    switch (stage) {
      case TgAuthStage.code:
        return GlassFormField(
          label: 'Confirmation code',
          child: GlassTextField(
            controller: _codeController,
            placeholder: '• • • • •',
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
          label: 'Two-step verification',
          helperText: 'Your cloud password protects this account',
          child: GlassPasswordField(
            controller: _passwordController,
            placeholder: 'Password',
            autofocus: true,
            settings: GlassTokens.chrome(context),
            onSubmitted: (_) => _submit(),
          ),
        );
      case TgAuthStage.splash:
      case TgAuthStage.phone:
      case TgAuthStage.ready:
        return GlassFormField(
          label: 'Phone number',
          child: GlassTextField(
            controller: _phoneController,
            placeholder: '+7 900 000 00 00',
            keyboardType: TextInputType.phone,
            prefixIcon: const Icon(TgIcons.calls, size: 19),
            settings: GlassTokens.chrome(context),
            onSubmitted: (_) => _submit(),
          ),
        );
    }
  }

  static String _titleFor(TgAuthStage stage) {
    switch (stage) {
      case TgAuthStage.code:
        return 'Enter the code';
      case TgAuthStage.password:
        return 'One more step';
      default:
        return 'Telegram Liquid';
    }
  }

  static String _subtitleFor(TgAuthStage stage) {
    switch (stage) {
      case TgAuthStage.code:
        return 'We sent a code to your Telegram app';
      case TgAuthStage.password:
        return 'This account is protected by a cloud password';
      default:
        return 'Sign in with your phone number to continue';
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

class _DemoHint extends StatelessWidget {
  const _DemoHint({required this.stage});

  final TgAuthStage stage;

  @override
  Widget build(BuildContext context) {
    final text = switch (stage) {
      TgAuthStage.code => 'Demo mode — the code is 12345',
      TgAuthStage.password => 'Demo mode — the password is "telegram"',
      _ => 'Demo mode — any phone number works',
    };

    return GlassChip(
      label: text,
      icon: const Icon(TgIcons.info, size: 15),
      settings: GlassTokens.chrome(context),
      labelStyle: TextStyle(
        fontSize: 13,
        color: TgColors.secondaryLabel.resolveFrom(context),
      ),
    );
  }
}
