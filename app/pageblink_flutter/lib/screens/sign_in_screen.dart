import 'package:flutter/material.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

import '../app/l10n.dart';
import '../app/theme.dart';
import '../client.dart';

/// 12–50 chars, a lowercase letter and a number, plus an uppercase letter or
/// a special character. (The server's own policy, ≥8 chars, is looser.)
List<PasswordRequirement> pageBlinkPasswordRequirements(L l) => [
  PasswordRequirement.minLength(12),
  PasswordRequirement.maxLength(50),
  PasswordRequirement.containsLowercase(),
  PasswordRequirement.containsNumber(),
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

  @override
  void initState() {
    super.initState();
    client.auth.authInfoListenable.addListener(_updateSignedInState);
    _isSignedIn = client.auth.isAuthenticated;
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
  }

  @override
  Widget build(BuildContext context) {
    if (_isSignedIn) return widget.child;
    final colors = Theme.of(context).colorScheme;
    final l = context.l;

    final signIn = _localized(
      l,
      SignInWidget(
        client: client,
        emailSignInWidget: EmailSignInWidget(
          client: client,
          passwordRequirements: pageBlinkPasswordRequirements(l),
        ),
        onAuthenticated: () {
          context.showSnackBar(
            message: l.userAuthenticated,
            backgroundColor: colors.primaryContainer,
            foregroundColor: colors.onPrimaryContainer,
          );
        },
        onError: (error) {
          context.showSnackBar(
            message: l.authFailed(error),
            backgroundColor: colors.errorContainer,
            foregroundColor: colors.onErrorContainer,
          );
        },
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
            final pad = mobile ? 16.0 : (desktop ? 32.0 : 24.0);
            final card = _SignInCard(
              compact: mobile,
              signIn: signIn,
            );
            final hero = _Hero(
              size: mobile
                  ? _HeroSize.mobile
                  : (desktop ? _HeroSize.desktop : _HeroSize.tablet),
              showPreview: desktop,
            );
            return SingleChildScrollView(
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
                          if (mobile) ...[
                            hero,
                            const SizedBox(height: 24),
                            card,
                          ] else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(child: hero),
                                SizedBox(width: desktop ? 48 : 32),
                                SizedBox(
                                  width: desktop ? 420 : 380,
                                  child: card,
                                ),
                              ],
                            ),
                          const SizedBox(height: 24),
                          const _Footer(),
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

  /// The sign-in widget ships English texts; give it Korean ones when needed.
  Widget _localized(L l, Widget child) => l.isKorean
      ? SignInLocalizationProvider(
          basic: _koBasic,
          email: _koEmail,
          passwordRequirementTexts: _koPassword,
          child: child,
        )
      : child;
}

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

enum _HeroSize { desktop, tablet, mobile }

class _Hero extends StatelessWidget {
  const _Hero({required this.size, required this.showPreview});

  final _HeroSize size;
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
      _HeroSize.mobile => ko ? 30.0 : 32.0,
    };
    final bullets = [
      (
        Icons.sticky_note_2_outlined,
        l.landingFeatureBoardTitle,
        l.landingFeatureBoardBody,
        false,
      ),
      (Icons.bolt, l.landingFeatureCiteTitle, l.landingFeatureCiteBody, true),
      (
        Icons.groups_outlined,
        l.landingFeatureShareTitle,
        l.landingFeatureShareBody,
        false,
      ),
      if (desktop)
        (
          Icons.shield_outlined,
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
                l.landingHeadline,
                style: theme.headlineMedium?.copyWith(
                  fontSize: headlineSize,
                  height: 1.15,
                ),
              ),
            ),
            const SizedBox(height: 16),
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
      return SizedBox(
        height: 36,
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
            Icon(Icons.bolt, size: 12, color: pb.accent),
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

class _SignInCard extends StatelessWidget {
  const _SignInCard({required this.compact, required this.signIn});

  final bool compact;
  final Widget signIn;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final pb = context.pb;
    final theme = Theme.of(context).textTheme;
    return GlassPanel(
      strong: true,
      child: Padding(
        padding: EdgeInsets.all(compact ? 20 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.signInTitle,
              style: theme.titleLarge?.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 4),
            Text(
              l.signInSubtitle,
              style: theme.bodyMedium?.copyWith(color: pb.inkMuted),
            ),
            const SizedBox(height: 20),
            Material(
              type: MaterialType.transparency,
              child: SizedBox(width: double.infinity, child: signIn),
            ),
            const SizedBox(height: 16),
            Text(
              l.signInHelper,
              style: theme.bodySmall?.copyWith(
                color: pb.inkMuted,
                height: 1.45,
              ),
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
