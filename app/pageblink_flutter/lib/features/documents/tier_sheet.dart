import 'package:flutter/material.dart';
import 'package:pageblink_client/pageblink_client.dart';

import '../../app/app_icons.dart';
import '../../app/l10n.dart';

/// Result of [chooseUploadTier] when the sheet was dismissed.
const tierCancelled = -1;

/// "Where should it go?" sheet. Returns null for the personal cloud, a
/// project id, or [tierCancelled]. Shared by the board (new note, picker
/// upload) and the shell's drop handler.
Future<int?> chooseUploadTier(
  BuildContext context,
  List<Project> projects,
) async {
  final l = context.l;
  final result = await showModalBottomSheet<int?>(
    context: context,
    useRootNavigator: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(title: Text(l.whereToPut)),
          ListTile(
            enabled: false,
            leading: const Icon(AppIcons.tierDevice),
            title: Text(l.cloakTitle),
            subtitle: Text(l.cloakSubtitle),
          ),
          ListTile(
            leading: const Icon(AppIcons.tierCloud),
            title: Text(l.myCloud),
            subtitle: Text(l.onlyYou),
            onTap: () => Navigator.pop(context, 0),
          ),
          for (final p in projects)
            ListTile(
              leading: const Icon(AppIcons.tierShared),
              title: Text(l.sharedVision(p.name)),
              subtitle: Text(l.shareWithMembers),
              onTap: () => Navigator.pop(context, p.id),
            ),
        ],
      ),
    ),
  );
  if (result == null) return tierCancelled;
  return result == 0 ? null : result;
}
