import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

import '../app/app_icons.dart';
import '../app/l10n.dart';
import '../app/theme.dart';
import 'auth_spacing.dart';

// The sign-up and password-reset screens of the package flow, rebuilt on the
// public [EmailAuthController] for the same reasons as `EmailLoginForm`
// (Enter submits, password managers get `autofillHints` + an `AutofillGroup`).
// Flow, enable rules and texts follow the package's `email/forms/*.dart`; see
// docs/research/020-login-enter-key-and-password-manager.md.

// No `border:` here: the pill border and the focus ring come from the theme's
// `inputDecorationTheme`, so a field keeps its shape when focused.
const _fieldPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 16);

/// Decoration shared by every field of the sign-in flow.
InputDecoration authDecoration(
  String label, {
  String? errorText,
  Widget? suffixIcon,
}) => InputDecoration(
  labelText: label,
  contentPadding: _fieldPadding,
  errorText: errorText,
  suffixIcon: suffixIcon,
);

/// Helper text above the fields (14 / 1.55: Korean wants 1.5+).
TextStyle? _helperStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.55);

/// Leaving the form unsubmitted: drop the autofill context first, otherwise
/// the group's dispose would "commit" it and Chrome could offer to save a
/// password that was never set (same pattern as the login form).
void _goTo(EmailAuthController c, EmailFlowScreen screen) {
  TextInput.finishAutofillContext(shouldSave: false);
  c.navigateTo(screen);
}

/// Title, fields, primary button and a bottom row inside an [AutofillGroup].
///
/// [commitOnDispose] is true only for the screens whose success signs the
/// user in (the group's dispose then lets the browser save the new password);
/// the intermediate screens cancel, so moving on never triggers a save.
class AuthFormFrame extends StatelessWidget {
  const AuthFormFrame({
    super.key,
    required this.title,
    required this.children,
    required this.buttonLabel,
    required this.onPressed,
    required this.isLoading,
    this.bottom,
    this.commitOnDispose = false,
  });

  final String title;
  final List<Widget> children;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? bottom;
  final bool commitOnDispose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AutofillGroup(
      onDisposeAction: commitOnDispose
          ? AutofillContextAction.commit
          : AutofillContextAction.cancel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l.isKorean ? keepAll(title) : title,
            style: theme.textTheme.headlineSmall?.copyWith(height: 1.3),
          ),
          const SizedBox(height: AuthSpacing.title),
          ...children,
          const SizedBox(height: AuthSpacing.action),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              foregroundColor: scheme.onPrimary,
              backgroundColor: scheme.primary,
              shape: const StadiumBorder(),
              // minimum, not fixed: the button grows with the text scale.
              minimumSize: const Size.fromHeight(AuthSpacing.buttonHeight),
              textStyle: theme.textTheme.labelLarge?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: isLoading ? null : onPressed,
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(buttonLabel),
          ),
          if (bottom != null) ...[
            const SizedBox(height: AuthSpacing.secondary),
            bottom!,
          ],
        ],
      ),
    );
  }
}

/// Email field shared by "start sign-up" and "request reset": Enter submits.
class _EmailField extends StatelessWidget {
  const _EmailField({
    required this.controller,
    required this.onSubmit,
    this.readOnly,
  });

  final EmailAuthController controller;
  final VoidCallback onSubmit;

  /// Defaults to `controller.isLoading`.
  final bool? readOnly;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final isInvalid = c.error is InvalidEmailException;
    return TextField(
      controller: c.emailController,
      readOnly: readOnly ?? c.isLoading,
      autofocus: readOnly == null,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.username, AutofillHints.email],
      inputFormatters: [
        FilteringTextInputFormatter.deny(RegExp(r'[\s()<>[\]\\,;:]')),
        TextInputFormatter.withFunction(
          (_, v) => v.copyWith(text: v.text.toLowerCase()),
        ),
      ],
      // Overriding this (instead of onSubmitted) keeps the focus in the field.
      onEditingComplete: onSubmit,
      scrollPadding: AuthSpacing.scrollPadding,
      decoration: authDecoration(
        context.emailSignInTexts.emailLabel,
        errorText: isInvalid ? c.errorMessage : null,
      ),
    );
  }
}

TextButton _link(String label, VoidCallback onPressed) => TextButton(
  onPressed: onPressed,
  child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
);

Widget _backTo(String label, VoidCallback onPressed) =>
    Center(child: _link(label, onPressed));

/// Sign-up step 1: email only (the package shows terms only when callbacks
/// are given, and PageBlink gives none).
class EmailStartRegistrationForm extends StatelessWidget {
  const EmailStartRegistrationForm({super.key, required this.controller});

  final EmailAuthController controller;

  EmailAuthController get _c => controller;

  bool get _canSubmit =>
      _c.emailController.text.isNotEmpty && _c.state == EmailAuthState.idle;

  void _submit() {
    if (_canSubmit) unawaited(_c.startRegistration());
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.emailSignInTexts;
    return ListenableBuilder(
      listenable: Listenable.merge([_c, _c.emailController]),
      builder: (context, _) => AuthFormFrame(
        title: texts.signUpTitle,
        isLoading: _c.isLoading,
        buttonLabel: texts.continueAction,
        onPressed: _canSubmit ? _submit : null,
        bottom: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(texts.alreadyHaveAnAccount),
            _link(texts.signIn, () => _goTo(_c, EmailFlowScreen.login)),
          ],
        ),
        children: [_EmailField(controller: _c, onSubmit: _submit)],
      ),
    );
  }
}

/// Password reset step 1: email, then a code is mailed.
class EmailRequestResetForm extends StatelessWidget {
  const EmailRequestResetForm({super.key, required this.controller});

  final EmailAuthController controller;

  EmailAuthController get _c => controller;

  bool get _canSubmit =>
      _c.emailController.text.isNotEmpty && _c.state == EmailAuthState.idle;

  void _submit() {
    if (_canSubmit) unawaited(_c.startPasswordReset());
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.emailSignInTexts;
    return ListenableBuilder(
      listenable: Listenable.merge([_c, _c.emailController]),
      builder: (context, _) => AuthFormFrame(
        title: texts.resetPasswordTitle,
        isLoading: _c.isLoading,
        buttonLabel: texts.requestPasswordReset,
        onPressed: _canSubmit ? _submit : null,
        bottom: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(texts.dontHaveAnAccount),
            _link(
              texts.signUp,
              () => _goTo(_c, EmailFlowScreen.startRegistration),
            ),
          ],
        ),
        children: [
          Text(texts.resetPasswordDescription, style: _helperStyle(context)),
          const SizedBox(height: AuthSpacing.field),
          _EmailField(controller: _c, onSubmit: _submit),
          _backTo(
            texts.backToSignIn,
            () => _goTo(_c, EmailFlowScreen.login),
          ),
        ],
      ),
    );
  }
}

/// Verification code step for both flows ([onVerify] is
/// `verifyRegistrationCode` or `verifyPasswordResetCode`).
class EmailVerifyCodeForm extends StatelessWidget {
  const EmailVerifyCodeForm({
    super.key,
    required this.controller,
    required this.title,
    required this.onVerify,
    this.config = const VerificationCodeConfig(),
  });

  final EmailAuthController controller;
  final String title;
  final Future<void> Function() onVerify;
  final VerificationCodeConfig config;

  EmailAuthController get _c => controller;

  // Not gated on `state == idle`: after a wrong code the state stays `error`
  // (the code controller has no listener resetting it) and the user must be
  // able to retry, as with the package's always-enabled verify button.
  void _submit() {
    if (!_c.isLoading && _c.verificationCodeController.text.isNotEmpty) {
      unawaited(onVerify());
    }
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.emailSignInTexts;
    final casing = config.allowedLetterCase.name;
    final allowed = config.allowedCharactersPattern ?? RegExp(r'[1-9]');
    return ListenableBuilder(
      listenable: Listenable.merge([_c, _c.verificationCodeController]),
      builder: (context, _) => AuthFormFrame(
        title: title,
        isLoading: _c.isLoading,
        buttonLabel: texts.verify,
        onPressed: _c.verificationCodeController.text.isEmpty ? null : _submit,
        bottom: _backTo(
          texts.backToSignIn,
          () => _goTo(_c, EmailFlowScreen.login),
        ),
        children: [
          Text(texts.verificationMessage, style: _helperStyle(context)),
          const SizedBox(height: AuthSpacing.field),
          TextField(
            controller: _c.verificationCodeController,
            readOnly: _c.isLoading,
            autofocus: true,
            keyboardType: config.keyboardType,
            textInputAction: TextInputAction.done,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(letterSpacing: 6),
            autofillHints: const [AutofillHints.oneTimeCode],
            maxLength: config.length,
            inputFormatters: [
              TextInputFormatter.withFunction(
                (_, v) => v.copyWith(
                  text: switch (casing) {
                    'lowercase' => v.text.toLowerCase(),
                    'uppercase' => v.text.toUpperCase(),
                    _ => v.text,
                  },
                ),
              ),
              FilteringTextInputFormatter.allow(allowed),
            ],
            // The package submits as soon as the last character is typed.
            onChanged: (v) {
              if (v.length == config.length) _submit();
            },
            onEditingComplete: _submit,
            scrollPadding: AuthSpacing.scrollPadding,
            decoration: const InputDecoration(
              contentPadding: _fieldPadding,
              counterText: '',
            ),
          ),
          _ResendButton(
            controller: _c,
            countdown: config.resendCountdownDuration,
          ),
        ],
      ),
    );
  }
}

/// "Send a new code" with the package's countdown (its own widget is private
/// and has a hardcoded English label).
class _ResendButton extends StatefulWidget {
  const _ResendButton({required this.controller, required this.countdown});

  final EmailAuthController controller;
  final Duration countdown;

  @override
  State<_ResendButton> createState() => _ResendButtonState();
}

class _ResendButtonState extends State<_ResendButton> {
  Timer? _timer;
  int _left = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _left = widget.countdown.inSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _left <= 0) return t.cancel();
      setState(() => _left--);
    });
  }

  Future<void> _resend() async {
    if (_left > 0 || _busy) return;
    setState(() => _busy = true);
    try {
      // Errors are reported by the controller (onError + error state).
      await widget.controller.resendVerificationCode();
      if (mounted) _start();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = context.l.resendCode;
    final time = _left >= 60
        ? '${_left ~/ 60}:${(_left % 60).toString().padLeft(2, '0')}'
        : '$_left';
    // Right under the code field (offset 0): a TextButton already has
    // ~14px of its own padding above the label.
    return TextButton(
      onPressed: _left == 0 && !_busy ? _resend : null,
      child: Text(_left > 0 ? '$label ($time)' : label),
    );
  }
}

/// Password step for both flows ([onSubmit] is `finishRegistration` or
/// `finishPasswordReset`). Shows the email read-only so the browser can pair
/// the new password with it (the package form has no username field).
class EmailSetPasswordForm extends StatefulWidget {
  const EmailSetPasswordForm({
    super.key,
    required this.controller,
    required this.title,
    required this.passwordLabel,
    required this.buttonLabel,
    required this.onSubmit,
    required this.backLabel,
    required this.backScreen,
  });

  final EmailAuthController controller;
  final String title;
  final String passwordLabel;
  final String buttonLabel;
  final Future<void> Function() onSubmit;
  final String backLabel;
  final EmailFlowScreen backScreen;

  @override
  State<EmailSetPasswordForm> createState() => _EmailSetPasswordFormState();
}

class _EmailSetPasswordFormState extends State<EmailSetPasswordForm> {
  bool _obscure = true;

  EmailAuthController get _c => widget.controller;

  bool get _canSubmit =>
      _c.passwordRequirements.isValid(_c.passwordController.text) &&
      !_c.isLoading &&
      _c.state != EmailAuthState.authenticated;

  void _submit() {
    if (_canSubmit) unawaited(widget.onSubmit());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_c, _c.passwordController]),
      builder: (context, _) => AuthFormFrame(
        title: widget.title,
        isLoading: _c.isLoading,
        buttonLabel: widget.buttonLabel,
        onPressed: _canSubmit ? _submit : null,
        commitOnDispose: true,
        bottom: _backTo(
          widget.backLabel,
          () => _goTo(_c, widget.backScreen),
        ),
        children: [
          // ponytail: display-only; remove if the browser pairs without it.
          _EmailField(controller: _c, onSubmit: () {}, readOnly: true),
          const SizedBox(height: AuthSpacing.field),
          TextField(
            controller: _c.passwordController,
            readOnly: _c.isLoading,
            autofocus: true,
            obscureText: _obscure,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                PasswordRequirement.allowedCharacters,
              ),
            ],
            onEditingComplete: _submit,
            scrollPadding: AuthSpacing.scrollPadding,
            decoration: authDecoration(
              widget.passwordLabel,
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure ? AppIcons.showPassword : AppIcons.hidePassword,
                  color: Colors.grey[400],
                ),
              ),
            ),
          ),
          if (_c.passwordRequirements.isNotEmpty)
            _PasswordChecklist(
              password: _c.passwordController.text,
              requirements: _c.passwordRequirements,
            ),
        ],
      ),
    );
  }
}

/// The package's `PasswordRequirements` checklist is not exported; same look.
class _PasswordChecklist extends StatelessWidget {
  const _PasswordChecklist({
    required this.password,
    required this.requirements,
  });

  final String password;
  final List<PasswordRequirement> requirements;

  @override
  Widget build(BuildContext context) {
    // The theme's onSurfaceVariant is `inkMuted` (Colors.grey was 2.7:1 on a
    // white card). Pb is optional so plain-MaterialApp tests keep working.
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final ok = theme.extension<Pb>()?.success ?? Colors.green;
    final base =
        theme.textTheme.bodySmall?.copyWith(
          color: muted,
          fontSize: 13,
          height: 1.5,
        ) ??
        TextStyle(fontSize: 13, height: 1.5, color: muted);
    final texts = context.passwordRequirementTexts;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in requirements)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 16),
              child: Row(
                children: [
                  Icon(
                    r.validator(password) ? AppIcons.check : AppIcons.close,
                    size: 16,
                    color: r.validator(password) ? ok : muted,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      PasswordRequirement.localized(r, texts),
                      style: password.isNotEmpty && r.validator(password)
                          ? base.copyWith(color: ok)
                          : base,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
