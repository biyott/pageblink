import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

import '../app/app_icons.dart';

/// [EmailSignInWidget] with our own login form; every other screen of the
/// flow (sign up, verify, reset) still comes from the package.
///
/// The package's login form has no `textInputAction`/`onSubmitted` (Enter did
/// nothing) and no `autofillHints`/`AutofillGroup` (password managers could
/// not fill or save), and it exposes neither. The controller is public, so the
/// login screen is rebuilt on top of it. Needs an external [controller].
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
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => c.currentScreen == EmailFlowScreen.login
          ? EmailLoginForm(controller: c)
          : EmailSignInWidget(controller: c),
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
    final scheme = Theme.of(context).colorScheme;
    final field = OutlineInputBorder(borderRadius: BorderRadius.circular(8));
    const padding = EdgeInsets.fromLTRB(12, 14, 12, 14);

    return ListenableBuilder(
      listenable: Listenable.merge([
        _c,
        _c.emailController,
        _c.passwordController,
      ]),
      builder: (context, _) => AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              texts.title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _c.emailController,
              readOnly: _c.isLoading,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
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
              decoration: InputDecoration(
                labelText: texts.emailLabel,
                contentPadding: padding,
                border: field,
                errorText: _c.error is InvalidEmailException
                    ? _c.errorMessage
                    : null,
              ),
            ),
            const SizedBox(height: 16),
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
              decoration: InputDecoration(
                labelText: texts.passwordLabel,
                contentPadding: padding,
                border: field,
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure ? AppIcons.showPassword : AppIcons.hidePassword,
                    color: Colors.grey[400],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
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
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                foregroundColor: scheme.onPrimary,
                backgroundColor: scheme.primary,
                shape: const StadiumBorder(),
                fixedSize: const Size(double.infinity, 48),
              ),
              onPressed: _c.isLoading || !_canSubmit ? null : _submit,
              child: _c.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(texts.signIn),
            ),
            const SizedBox(height: 8),
            Wrap(
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
          ],
        ),
      ),
    );
  }
}
