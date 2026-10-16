import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

import '../app/l10n.dart';
import '../app/locale_controller.dart';
import '../app/theme.dart';
import '../client.dart';
import '../features/demo/demo.dart';
import '../features/demo/demo_widgets.dart';
import '../app/app_icons.dart';
import 'auth_spacing.dart';
import 'email_sign_in.dart';

/// ≥12 chars, a lowercase letter and a number, plus an uppercase letter or
/// a special character. No maximum shown (the server's own policy is just
/// ≥8 chars, no trailing/leading space).
List<PasswordRequirement> pageBlinkPasswordRequirements(L l) => [
  PasswordRequirement.minLength(12),
  PasswordRequirement(
    description: l.pwLowerAndNumber,
    validator: (p) =>
        PasswordRequirement.lowercaseLetters.hasMatch(p) &&
        PasswordRequirement.numbers.hasMatch(p),
  ),
  PasswordRequirement(
    description: l.pwUppercaseOrSpecial,
    validator: (p) =>
        PasswordRequirement.uppercaseLetters.hasMatch(p) ||
        PasswordRequirement.specialCharacters.hasMatch(p),
  ),
];

class SignInScreen extends StatefulWidget {
  final Widget child;
  const SignInScreen({super.key, required this.child});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _isSignedIn = false;

  // Demo login (plan 014): the button exists only while the server says the
  // demo is on. A failed or slow status call just means no button.
  bool _demoEnabled = false;
  bool _demoBusy = false;
  bool _demoFailed = false;

  // Owned here (not by the package widget) so our login form can use it.
  // Created lazily (needs the locale), dropped after sign-in so no typed
  // email/password lingers and the next sign-in screen starts empty.
  EmailAuthController? _email;

  // Keeps the card (and its autofill context) alive when the layout switches
  // between the narrow and wide arrangement.
  final _cardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    client.auth.authInfoListenable.addListener(_updateSignedInState);
    _isSignedIn = client.auth.isAuthenticated;
    if (!_isSignedIn) _loadDemo();
  }

  Future<void> _loadDemo() async {
    final status = await fetchDemoStatus();
    if (mounted && !_isSignedIn) {
      setState(() => _demoEnabled = status?.enabled ?? false);
    }
  }

  Future<void> _startDemo() async {
    if (_demoBusy) return;
    setState(() {
      _demoBusy = true;
      _demoFailed = false;
    });
    try {
      await signInAsDemo(locale: context.l.isKorean ? 'ko' : 'en');
    } catch (e) {
      debugPrint('demo sign-in failed: $e');
      if (mounted) setState(() => _demoFailed = true);
    } finally {
      if (mounted) setState(() => _demoBusy = false);
    }
  }

  @override
  void dispose() {
    client.auth.authInfoListenable.removeListener(_updateSignedInState);
    super.dispose();
  }

  void _updateSignedInState() {
    setState(() {
      _isSignedIn = client.auth.isAuthenticated;
    });
    if (!_isSignedIn) {
      // Back on the sign-in screen (e.g. signed out of the demo).
      _loadDemo();
    }
    if (_isSignedIn) {
      // After the frame: the form's widgets must be unmounted first.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isSignedIn) return;
        _email?.dispose();
        _email = null;
      });
    }
  }

  EmailFlowScreen _startScreen() {
    final signUp = demoSignUpRequested;
    demoSignUpRequested = false;
    return signUp ? EmailFlowScreen.startRegistration : EmailFlowScreen.login;
  }

  void _onEmailAuthenticated() {
    if (!mounted) return;
    final colors = Theme.of(context).colorScheme;
    context.showSnackBar(
      message: context.l.userAuthenticated,
      backgroundColor: colors.primaryContainer,
      foregroundColor: colors.onPrimaryContainer,
    );
  }

  void _onEmailError(Object error) {
    if (!mounted) return;
    final colors = Theme.of(context).colorScheme;
    context.showSnackBar(
      message: context.l.authFailed(error),
      backgroundColor: colors.errorContainer,
      foregroundColor: colors.onErrorContainer,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isSignedIn) return widget.child;
    final l = context.l;
    // Fold-line decisions use the window height over the text scale, NOT the
    // LayoutBuilder height: the keyboard shrinks that one and the hero would
    // flicker while it opens (spec R6). sizeOf/textScalerOf: no rebuild per
    // keyboard inset frame.
    final eff =
        MediaQuery.sizeOf(context).height /
        math.max(1.0, MediaQuery.textScalerOf(context).scale(16) / 16);

    // Only the email provider exists, so the package's SignInWidget (which
    // adds a 24px SafeArea, width 400 and the social-lock coordinator) is not
    // used. ponytail: when a social provider is added, bring SignInWidget (or
    // its SignInFlowCoordinator) back around this.
    final signIn = pageBlinkLocalized(
      l,
      PageBlinkEmailSignIn(
        // Returning users are the common case: open on sign-in; the form
        // shows "Don't have an account? Sign up" below the button.
        controller: _email ??= EmailAuthController(
          client: client,
          // "Sign up" in the demo banner lands on the registration form.
          startScreen: _startScreen(),
          passwordRequirements: pageBlinkPasswordRequirements(l),
          onAuthenticated: _onEmailAuthenticated,
          onError: _onEmailError,
        ),
      ),
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            final desktop = w >= 1024;
            final mobile = w < 600;
            final row = w >= 840 && eff >= 560;
            final pad = mobile ? 16.0 : (desktop ? 32.0 : 24.0);
            final card = SignInCard(
              key: _cardKey,
              compact: mobile,
              signIn: signIn,
              demo: _demoEnabled
                  ? DemoSignInButton(
                      busy: _demoBusy,
                      failed: _demoFailed,
                      onPressed: _startDemo,
                    )
                  : null,
            );
            // Priority: form > headline > pitch > preview (spec R4).
            final size = mobile
                ? _HeroSize.mobile
                : (desktop ? _HeroSize.desktop : _HeroSize.tablet);
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: h),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: pad,
                        vertical: mobile ? 24 : pad,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // In the scroll flow, never over the card (spec R1/R2).
                          const Align(
                            alignment: Alignment.centerRight,
                            child: _LanguageMenu(),
                          ),
                          if (row)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: _Hero(
                                    size: size,
                                    part: _HeroPart.all,
                                    showPreview: desktop && eff >= 880,
                                  ),
                                ),
                                SizedBox(width: desktop ? 48 : 32),
                                SizedBox(
                                  width: desktop ? 420 : 400,
                                  child: card,
                                ),
                              ],
                            )
                          else
                            // Card first (returning users), pitch below.
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 440),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (eff >= 560) ...[
                                    _Hero(
                                      size: size,
                                      part: _HeroPart.head,
                                      showPreview: false,
                                    ),
                                    const SizedBox(height: AuthSpacing.section),
                                  ],
                                  card,
                                  if (eff >= 760) ...[
                                    const SizedBox(height: AuthSpacing.section),
                                    _Hero(
                                      size: size,
                                      part: _HeroPart.pitch,
                                      showPreview: false,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          if (eff >= 560) ...[
                            const SizedBox(height: AuthSpacing.section),
                            const _Footer(),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The sign-in widget ships English texts; give it Korean ones when needed.
@visibleForTesting
Widget pageBlinkLocalized(L l, Widget child) => l.isKorean
    ? SignInLocalizationProvider(
        basic: _koBasic,
        email: _koEmail,
        passwordRequirementTexts: _koPassword,
        child: child,
      )
    : child;

const _koBasic = BasicSignInTexts(
  noAuthenticationProvidersConfigured: '서버에 로그인 방법이 설정되어 있지 않아요.',
  orContinueWith: '또는 다음으로 계속',
);

const _koPassword = PasswordRequirementTexts(
  minLengthTemplate: '{length}자 이상',
  maxLengthTemplate: '{length}자 이하',
  containsLowercase: '소문자 1개 이상',
  containsUppercase: '대문자 1개 이상',
  containsNumber: '숫자 1개 이상',
  containsSpecialCharacter: '특수문자 1개 이상',
);

const _koEmail = EmailSignInTexts(
  title: '이메일로 로그인',
  forgotPassword: '비밀번호를 잊으셨나요?',
  signIn: '로그인',
  dontHaveAnAccount: '계정이 없으신가요?',
  signUp: '가입하기',
  signUpTitle: '이메일로 가입',
  continueAction: '계속',
  alreadyHaveAnAccount: '이미 계정이 있으신가요?',
  verifyAccountTitle: '계정 확인',
  verifyResetCodeTitle: '재설정 코드 확인',
  verificationMessage: '확인 메일을 보냈어요. 메일함을 열어 아래에 인증 코드를 입력해 주세요.',
  verify: '확인',
  setAccountPasswordTitle: '비밀번호 설정',
  passwordLabel: '비밀번호',
  backToSignUp: '가입으로 돌아가기',
  setNewPasswordTitle: '새 비밀번호 설정',
  newPasswordLabel: '새 비밀번호',
  resetPasswordTitle: '비밀번호 재설정',
  resetPasswordDescription: '비밀번호를 재설정할 이메일 주소를 입력해 주세요.',
  requestPasswordReset: '재설정 요청',
  resetPassword: '비밀번호 재설정',
  backToSignIn: '로그인으로 돌아가기',
  emailLabel: '이메일',
  termsIntro: '동의합니다: ',
  termsAndConditions: '이용약관',
  andText: ' 및 ',
  privacyPolicy: '개인정보 처리방침',
);

extension on BuildContext {
  void showSnackBar({
    required String message,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: foregroundColor)),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 5),
      ),
    );
  }
}

/// Language switcher for signed-out users (Settings is unreachable before
/// sign-in). Same [localeController], so it stays in sync with Settings.
class _LanguageMenu extends StatelessWidget {
  const _LanguageMenu();

  static const _system = 'system';

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final names = {
      _system: l.languageSystem,
      'en': l.languageEnglish,
      'ko': l.languageKorean,
    };
    return ValueListenableBuilder<Locale?>(
      valueListenable: localeController,
      builder: (context, locale, _) {
        final chosen = locale?.languageCode ?? _system;
        return PopupMenuButton<String>(
          tooltip: l.changeLanguage,
          onSelected: (code) =>
              localeController.choose(code == _system ? null : Locale(code)),
          itemBuilder: (_) => [
            for (final e in names.entries)
              CheckedPopupMenuItem<String>(
                value: e.key,
                checked: e.key == chosen,
                child: Text(e.value),
              ),
          ],
          // Label: the language in effect (also when following the system).
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(AppIcons.language, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      l.isKorean ? l.languageKorean : l.languageEnglish,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(AppIcons.expand, size: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _HeroSize { desktop, tablet, mobile }

/// `head`: brand + headline. `pitch`: intro + bullets. `all`: both (+ preview).
enum _HeroPart { all, head, pitch }

class _Hero extends StatelessWidget {
  const _Hero({
    required this.size,
    required this.part,
    required this.showPreview,
  });

  final _HeroSize size;
  final _HeroPart part;
  final bool showPreview;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final pb = context.pb;
    final theme = Theme.of(context).textTheme;
    final mobile = size == _HeroSize.mobile;
    final desktop = size == _HeroSize.desktop;
    final ko = l.isKorean;
    final headlineSize = switch (size) {
      _HeroSize.desktop => ko ? 44.0 : 52.0,
      _HeroSize.tablet => ko ? 36.0 : 40.0,
      _HeroSize.mobile => ko ? 26.0 : 28.0,
    };
    final head = part != _HeroPart.pitch;
    final pitch = part != _HeroPart.head;
    final bullets = [
      (
        AppIcons.note,
        l.landingFeatureBoardTitle,
        l.landingFeatureBoardBody,
        false,
      ),
      (
        AppIcons.citation,
        l.landingFeatureCiteTitle,
        l.landingFeatureCiteBody,
        true,
      ),
      (
        AppIcons.projects,
        l.landingFeatureShareTitle,
        l.landingFeatureShareBody,
        false,
      ),
      if (desktop)
        (
          AppIcons.privacy,
          l.landingFeaturePrivacyTitle,
          l.landingFeaturePrivacyBody,
          false,
        ),
    ];
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (head) ...[
              Text(
                '⚡ PageBlink',
                style: theme.headlineMedium?.copyWith(
                  fontSize: mobile ? 24 : 28,
                ),
              ),
              SizedBox(height: mobile ? 16 : 28),
              Semantics(
                header: true,
                child: Text(
                  // Words must not break mid-syllable run (spec §3.5).
                  ko ? keepAll(l.landingHeadline) : l.landingHeadline,
                  style: theme.headlineMedium?.copyWith(
                    fontSize: headlineSize,
                    height: mobile ? 1.25 : 1.15,
                  ),
                ),
              ),
            ],
            if (pitch) ...[
              if (head) const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Text(
                  l.landingSub,
                  style: theme.bodyLarge?.copyWith(
                    fontSize: desktop ? 18 : (mobile ? 15 : 16),
                    height: 1.5,
                    color: pb.inkMuted,
                  ),
                ),
              ),
              SizedBox(height: mobile ? 16 : 28),
              for (final (icon, title, body, accent) in bullets)
                Padding(
                  padding: EdgeInsets.only(bottom: mobile ? 4 : 16),
                  child: _Bullet(
                    icon: icon,
                    title: title,
                    body: body,
                    accent: accent,
                    compact: mobile,
                  ),
                ),
            ],
            if (showPreview) ...[
              const SizedBox(height: 12),
              const _PreviewCard(),
            ],
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
    required this.compact,
  });

  final IconData icon;
  final String title, body;
  final bool accent, compact;

  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    final text = Theme.of(context).textTheme.bodyMedium;
    final iconColor = accent ? pb.accent : pb.ink;
    if (compact) {
      // minHeight, not height: the row grows with the text scale (R2).
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: text?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: pb.glassStrong,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: pb.glassBorder),
          ),
          child: Icon(icon, size: 22, color: iconColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: text?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(body, style: text?.copyWith(color: pb.inkMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Decorative mock of a cited answer (hidden from the accessibility tree).
class _PreviewCard extends StatelessWidget {
  const _PreviewCard();

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final pb = context.pb;
    final theme = Theme.of(context).textTheme;
    WidgetSpan pill(int n) => WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Container(
        height: 18,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.fromLTRB(4, 0, 6, 0),
        decoration: BoxDecoration(
          color: pb.accentContainer,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.citation, size: 12, color: pb.accent),
            Text(
              '$n',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: pb.onAccentContainer,
              ),
            ),
          ],
        ),
      ),
    );
    Widget chip(String label) => Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: pb.accent),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: pb.onAccentContainer,
        ),
      ),
    );
    return ExcludeSemantics(
      child: SizedBox(
        width: 460,
        height: 220,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              width: 220,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: pb.notes[0],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: pb.hairline),
                  boxShadow: [
                    BoxShadow(
                      color: pb.ink.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.landingPreviewNoteTitle,
                      style: theme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l.landingPreviewNoteBody,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 120,
              top: 64,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: pb.glassStrong,
                  border: Border.all(color: pb.glassBorder),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                  boxShadow: [BoxShadow(color: pb.glassShadow, blurRadius: 24)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '${l.landingPreviewAnswerA} '),
                          pill(1),
                          TextSpan(text: ' ${l.landingPreviewAnswerB} '),
                          pill(2),
                        ],
                      ),
                      style: theme.bodyMedium?.copyWith(height: 1.55),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        chip('⚡1 · ${l.landingPreviewNoteTitle}'),
                        chip('⚡2 · Spec.pdf p.4'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The glass card around the email flow. Public only so the layout test can
/// put every step of the flow into the real card.
@visibleForTesting
class SignInCard extends StatelessWidget {
  const SignInCard({
    super.key,
    required this.compact,
    required this.signIn,
    this.demo,
  });

  final bool compact;
  final Widget signIn;

  /// The "Try the demo" button; null when the demo is off.
  final Widget? demo;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final pb = context.pb;
    final theme = Theme.of(context).textTheme;
    return GlassPanel(
      strong: true,
      child: Padding(
        padding: EdgeInsets.all(
          compact ? AuthSpacing.cardPadCompact : AuthSpacing.cardPad,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // The form renders its own title, so the card only adds the
            // privacy note, below the form (the title is the first element).
            Material(
              type: MaterialType.transparency,
              child: signIn,
            ),
            if (demo != null) ...[
              const SizedBox(height: AuthSpacing.field),
              demo!,
            ],
            const SizedBox(height: AuthSpacing.section),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(AppIcons.privacy, size: 16, color: pb.inkMuted),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.signInSubtitle,
                    style: theme.bodySmall?.copyWith(
                      fontSize: 13,
                      height: 1.5,
                      color: pb.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontSize: 12,
      color: context.pb.inkMuted,
    );
    return Column(
      children: [
        Text(l.landingTrust, textAlign: TextAlign.center, style: style),
        const SizedBox(height: 4),
        Text(l.landingFreeModelNote, textAlign: TextAlign.center, style: style),
        const SizedBox(height: 4),
        Text(l.landingFooterCredit, textAlign: TextAlign.center, style: style),
      ],
    );
  }
}
