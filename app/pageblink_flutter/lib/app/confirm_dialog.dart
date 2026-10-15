import 'package:flutter/material.dart';

import 'l10n.dart';

/// Cancel / Delete confirmation with a danger-colored confirm button.
/// True only when the user chose to delete.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final l = context.l;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) {
      final scheme = Theme.of(dialog).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(l.delete),
          ),
        ],
      );
    },
  );
  return ok == true;
}
