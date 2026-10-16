import 'package:flutter/material.dart';
import 'package:pageblink_client/pageblink_client.dart';

import '../../app/app_icons.dart';
import '../../app/l10n.dart';
import '../../app/theme.dart';
import 'demo.dart';

/// Thin strip above the signed-in shell while the session is the demo
/// account: mode, new items left, a Sign up action and an (i) with the
/// shared-account notice. Not "read only": the demo account really writes.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key, required this.status});

  final DemoStatus status;

  void _about(BuildContext context) {
    final l = context.l;
    showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l.demoBanner),
        content: Text(l.demoPrivacyNote),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(l.ok),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialog);
              demoSignUp();
            },
            child: Text(l.demoSignUp),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final pb = context.pb;
    final text = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontSize: 13,
      height: 1.3,
      color: pb.onAccentContainer,
    );
    final left = status.createRemaining;
    return Material(
      color: pb.accentContainer,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: pb.hairline)),
        ),
        child: SafeArea(
          bottom: false,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: l.demoBanner,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (left != null)
                            TextSpan(
                              text:
                                  ' · ${l.demoCreateLeft(left, status.createLimit)}',
                            ),
                        ],
                      ),
                      style: text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: l.demoAbout,
                    icon: const Icon(AppIcons.info, size: 18),
                    color: pb.onAccentContainer,
                    onPressed: () => _about(context),
                  ),
                  TextButton(
                    onPressed: demoSignUp,
                    style: TextButton.styleFrom(
                      foregroundColor: pb.onAccentContainer,
                      minimumSize: const Size(48, 44),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Text(l.demoSignUp),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary (outlined) button of the sign-in card. Shown by the caller only
/// when the server said the demo is on. Tapping again after a failure retries.
class DemoSignInButton extends StatelessWidget {
  const DemoSignInButton({
    super.key,
    required this.busy,
    required this.failed,
    required this.onPressed,
  });

  final bool busy;
  final bool failed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final pb = context.pb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          enabled: !busy,
          label: l.demoButtonLabel,
          excludeSemantics: true,
          onTap: busy ? null : onPressed,
          child: OutlinedButton.icon(
            onPressed: busy ? null : onPressed,
            icon: busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(AppIcons.demo, size: 18),
            label: Text(busy ? l.demoOpening : l.demoButton),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              backgroundColor: pb.glassStrong,
              foregroundColor: pb.ink,
              side: BorderSide(color: pb.hairline),
            ),
          ),
        ),
        if (failed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              liveRegion: true,
              child: Text(
                l.demoSignInFailed,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
