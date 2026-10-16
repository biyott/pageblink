import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

import '../app/app_icons.dart';
import '../app/l10n.dart';
import 'auth_spacing.dart';
import 'email_register_forms.dart';

/// [EmailSignInWidget] with our own forms for every screen of the flow
/// (login here, sign-up / verify / password in `email_register_forms.dart`).
///
/// The package's forms have no `textInputAction`/`onSubmitted` (Enter did
/// nothing) and no `autofillHints`/`AutofillGroup` (password managers could
/// not fill or save), and they expose neither. The controller is public, so
/// the screens are rebuilt on top of it. Needs an external [controller].
/// Mirrors `EmailSignInWidget._buildScreen`; recheck it on package upgrades.
class PageBlinkEmailSignIn extends EmailSignInWidget {
  const PageBlinkEmailSignIn({
    super.key,
    required EmailAuthController super.controller,
  });

  @override
  State<EmailSignInWidget> createState() => _PageBlinkEmailSignInState();
}

class _PageBlinkEmailSignInState extends State<PageBlinkEmailSignIn> {
  @override
  Widget build(BuildContext context) {
    final c = widget.controller!;
    final texts = context.emailSignInTexts;
    final code = widget.verificationCodeConfig;
    return ListenableBuilder(
      listenable: c,
      // The key gives every screen a fresh state (and autofill group).
      builder: (context, _) => KeyedSubtree(
        key: ValueKey(c.currentScreen),
        child: switch (c.currentScreen) {
          EmailFlowScreen.login => EmailLoginForm(controller: c),
          EmailFlowScreen.startRegistration => EmailStartRegistrationForm(
            controller: c,
          ),
          EmailFlowScreen.verifyRegistration => EmailVerifyCodeForm(
            controller: c,
            title: texts.verifyAccountTitle,
            onVerify: c.verifyRegistrationCode,
            config: code,
          ),
          EmailFlowScreen.completeRegistration => EmailSetPasswordForm(
            controller: c,
            title: texts.setAccountPasswordTitle,
            passwordLabel: texts.passwordLabel,
            buttonLabel: texts.signUp,
            onSubmit: c.finishRegistration,
            backLabel: texts.backToSignUp,
            backScreen: EmailFlowScreen.startRegistration,
          ),
          EmailFlowScreen.requestPasswordReset => EmailRequestResetForm(
            controller: c,
          ),
          EmailFlowScreen.verifyPasswordReset => EmailVerifyCodeForm(
            controller: c,
            title: texts.verifyResetCodeTitle,
            onVerify: c.verifyPasswordResetCode,
            config: code,
          ),
          EmailFlowScreen.completePasswordReset => EmailSetPasswordForm(
            controller: c,
            title: texts.setNewPasswordTitle,
            passwordLabel: texts.newPasswordLabel,
            buttonLabel: texts.resetPassword,
            onSubmit: c.finishPasswordReset,
            backLabel: texts.backToSignIn,
            backScreen: EmailFlowScreen.login,
          ),
        },
      ),
    );
  }
}

/// Email + password login: Enter submits, browser/OS password managers can
/// fill and (after a successful sign-in) save the credentials.
class EmailLoginForm extends StatefulWidget {
  const EmailLoginForm({super.key, required this.controller});

  final EmailAuthController controller;

  @override
  State<EmailLoginForm> createState() => _EmailLoginFormState();
}

class _EmailLoginFormState extends State<EmailLoginForm> {
  final _passwordFocus = FocusNode();
  bool _obscure = true;

  EmailAuthController get _c => widget.controller;

  // Same enable rule as the package's login button.
  bool get _canSubmit =>
      _c.emailController.text.isNotEmpty &&
      _c.passwordController.text.isNotEmpty &&
      _c.state == EmailAuthState.idle;

  @override
  void dispose() {
    _passwordFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (_canSubmit) _c.login();
  }

  /// Leaving the form unsubmitted: drop the autofill context, otherwise the
  /// group's dispose would "commit" it and Chrome could offer to save a
  /// password that was never verified. (A successful sign-in unmounts the
  /// form with the context intact, so the group's dispose saves it then.)
  void _goTo(EmailFlowScreen screen) {
    TextInput.finishAutofillContext(shouldSave: false);
    _c.navigateTo(screen);
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.emailSignInTexts;

    return ListenableBuilder(
      listenable: Listenable.merge([
        _c,
        _c.emailController,
        _c.passwordController,
      ]),
      // Same frame (title, button, spacing) as every other step of the flow.
      // Commit on dispose: a successful sign-in saves the credentials.
      builder: (context, _) => AuthFormFrame(
        title: texts.title,
        isLoading: _c.isLoading,
        buttonLabel: texts.signIn,
        onPressed: _canSubmit ? _submit : null,
        commitOnDispose: true,
        bottom: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(texts.dontHaveAnAccount),
            TextButton(
              onPressed: () => _goTo(EmailFlowScreen.startRegistration),
              child: Text(
                texts.signUp,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        children: [
          TextField(
            controller: _c.emailController,
            readOnly: _c.isLoading,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp(r'[\s()<>[\]\\,;:]')),
              TextInputFormatter.withFunction(
                (_, v) => v.copyWith(text: v.text.toLowerCase()),
              ),
            ],
            // Autofill often fills both: Enter then submits right away.
            onEditingComplete: () => _c.passwordController.text.isEmpty
                ? _passwordFocus.requestFocus()
                : _submit(),
            scrollPadding: AuthSpacing.scrollPadding,
            decoration: authDecoration(
              texts.emailLabel,
              errorText: _c.error is InvalidEmailException
                  ? _c.errorMessage
                  : null,
            ),
          ),
          const SizedBox(height: AuthSpacing.field),
          TextField(
            controller: _c.passwordController,
            focusNode: _passwordFocus,
            readOnly: _c.isLoading,
            obscureText: _obscure,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            // Overriding this (instead of onSubmitted) also keeps the focus
            // in the field after a failed attempt.
            onEditingComplete: _submit,
            scrollPadding: AuthSpacing.scrollPadding,
            decoration: authDecoration(
              texts.passwordLabel,
              suffixIcon: IconButton(
                // The name says what a press does (and a tooltip for the
                // mouse); the icon is the picture of the state.
                tooltip: _obscure
                    ? context.l.showPassword
                    : context.l.hidePassword,
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure ? AppIcons.showPassword : AppIcons.hidePassword,
                  // onSurfaceVariant = inkMuted in the app theme.
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          // Offset 0: the TextButton's own padding already separates it.
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _goTo(EmailFlowScreen.requestPasswordReset),
              child: Text(
                texts.forgotPassword,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
