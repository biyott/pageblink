import 'package:flutter/material.dart';

import '../../app/app_icons.dart';
import '../../app/l10n.dart';
import '../../app/theme.dart';

/// Thin bar above a cited note / PDF page: `⚡1 · Evidence for the answer`,
/// the step buttons between the answer's citations of the same document
/// (`<` `n/m` `>`, only with [count] > 1) and a close button that hides the
/// highlight. The number is a symbol, not a color: one violet for all.
///
/// [text] replaces the default label (the quote itself, when the passage was
/// not found in the text).
class CiteBar extends StatelessWidget {
  const CiteBar({
    super.key,
    this.number,
    this.text,
    this.position = 1,
    this.count = 1,
    this.onPrevious,
    this.onNext,
    required this.onDismiss,
  });

  final int? number;
  final String? text;

  /// 1-based position among [count] citations.
  final int position, count;
  final VoidCallback? onPrevious, onNext;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final pb = context.pb;
    final style = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: pb.onAccentContainer,
    );
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.only(left: 12, right: 4),
      decoration: BoxDecoration(
        color: pb.accentContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(AppIcons.citationMarker, size: 14, color: pb.onAccentContainer),
          if (number != null) ...[
            const SizedBox(width: 2),
            Text('$number', key: const ValueKey('cite-number'), style: style),
          ],
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text == null ? l.citeEvidence : '“$text”',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style.copyWith(
                fontWeight: text == null ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
          if (count > 1) ...[
            _Button(
              key: const ValueKey('cite-previous'),
              icon: AppIcons.previous,
              tooltip: l.citePrevious,
              color: pb.onAccentContainer,
              onTap: onPrevious,
            ),
            Semantics(
              label: l.sourceNofM(position, count),
              excludeSemantics: true,
              child: Text(
                '$position/$count',
                key: const ValueKey('cite-position'),
                style: style.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            _Button(
              key: const ValueKey('cite-next'),
              icon: AppIcons.next,
              tooltip: l.citeNext,
              color: pb.onAccentContainer,
              onTap: onNext,
            ),
          ],
          _Button(
            key: const ValueKey('cite-dismiss'),
            icon: AppIcons.close,
            tooltip: l.citeDismiss,
            color: pb.onAccentContainer,
            onTap: onDismiss,
          ),
        ],
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    icon: Icon(icon, size: 18),
    color: color,
    disabledColor: color.withValues(alpha: 0.35),
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints.tightFor(width: 36, height: 36),
    padding: EdgeInsets.zero,
  );
}
