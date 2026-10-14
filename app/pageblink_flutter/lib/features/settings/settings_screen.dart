import 'package:flutter/material.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

import '../../app/l10n.dart';
import '../../app/locale_controller.dart';
import '../../client.dart';

/// Language preference and sign-out.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _system = 'system';

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
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
            leading: const Icon(Icons.logout),
            title: Text(l.signOut),
            onTap: () async {
              Navigator.pop(context);
              await client.auth.signOutDevice();
            },
          ),
        ],
      ),
    );
  }
}
