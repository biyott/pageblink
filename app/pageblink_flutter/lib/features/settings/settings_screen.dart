import 'package:flutter/material.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

import '../../app/l10n.dart';
import '../../app/locale_controller.dart';
import '../../app/pane_header.dart';
import '../../client.dart';
import '../../app/app_icons.dart';

/// Language preference and sign-out. Opens like a note: in the center pane
/// ([embedded]) or as a page on phones.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.embedded,
    required this.onClose,
  });

  final bool embedded;
  final VoidCallback onClose;

  static const _system = 'system';

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Column(
      children: [
        PaneHeader(
          embedded: embedded,
          onBack: onClose,
          onClose: onClose,
          backLabel: l.back,
          title: Text(l.settings),
        ),
        Expanded(
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  l.language,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              ValueListenableBuilder<Locale?>(
                valueListenable: localeController,
                builder: (context, locale, _) => RadioGroup<String>(
                  groupValue: locale?.languageCode ?? _system,
                  onChanged: (code) => localeController.choose(
                    code == null || code == _system ? null : Locale(code),
                  ),
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        value: _system,
                        title: Text(l.languageSystem),
                      ),
                      RadioListTile<String>(
                        value: 'en',
                        title: Text(l.languageEnglish),
                      ),
                      RadioListTile<String>(
                        value: 'ko',
                        title: Text(l.languageKorean),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 32),
              ListTile(
                leading: const Icon(AppIcons.signOut),
                title: Text(l.signOut),
                // No pop needed: signing out replaces the whole HomeShell.
                onTap: () => client.auth.signOutDevice(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
