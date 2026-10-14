import 'package:flutter/material.dart';

import 'l10n.dart';
import 'theme.dart';

/// Top bar of an opened note or PDF. Embedded in the center pane it reads
/// "← Notes / Title" with a close button; as a full page (phones) it is a
/// back arrow and the title.
class PaneHeader extends StatelessWidget {
  const PaneHeader({
    super.key,
    required this.title,
    required this.embedded,
    required this.onBack,
    this.onClose,
    this.actions = const [],
  });

  final Widget title;
  final bool embedded;
  final VoidCallback onBack;
  final VoidCallback? onClose;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final pb = context.pb;
    final style = Theme.of(context).textTheme.titleMedium;
    return Container(
      height: 56,
      padding: EdgeInsets.only(left: embedded ? 8 : 4, right: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: pb.hairline)),
      ),
      child: Row(
        children: [
          if (embedded) ...[
            TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text(l.tabNotes),
              style: TextButton.styleFrom(foregroundColor: pb.inkMuted),
            ),
            Text('/', style: style?.copyWith(color: pb.inkMuted)),
            const SizedBox(width: 10),
          ] else
            IconButton(
              tooltip: l.back,
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack,
            ),
          Expanded(
            child: DefaultTextStyle.merge(
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              child: title,
            ),
          ),
          ...actions,
          if (embedded && onClose != null)
            IconButton(
              tooltip: l.closeEsc,
              icon: const Icon(Icons.close),
              onPressed: onClose,
            ),
        ],
      ),
    );
  }
}
