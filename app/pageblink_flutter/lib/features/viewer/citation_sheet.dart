import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pageblink_client/pageblink_client.dart';

import '../../app/l10n.dart';
import '../../app/theme.dart';
import '../../app/app_icons.dart';

/// Mobile "Blink": a bottom sheet previewing the cited passage, with a
/// button that hands the citation to [onOpen] (note in the Notes tab, PDF in
/// the current tab). Shown above the bottom bar, on the root navigator.
Future<void> showCitationSheet(
  BuildContext context,
  List<Citation> citations,
  int index, {
  required void Function(Citation) onOpen,
}) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  barrierColor: context.pb.scrim,
  builder: (_) =>
      _CitationSheet(citations: citations, initial: index, onOpen: onOpen),
);

class _CitationSheet extends StatefulWidget {
  const _CitationSheet({
    required this.citations,
    required this.initial,
    required this.onOpen,
  });

  final List<Citation> citations;
  final int initial;
  final void Function(Citation) onOpen;

  @override
  State<_CitationSheet> createState() => _CitationSheetState();
}

class _CitationSheetState extends State<_CitationSheet> {
  late int _i = widget.initial.clamp(0, widget.citations.length - 1);

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final pb = context.pb;
    final text = Theme.of(context).textTheme;
    final c = widget.citations[_i];
    final total = widget.citations.length;
    final isNote = c.kind == 'note';
    final height = MediaQuery.sizeOf(context).height * 0.62;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: height,
          color: pb.sheet,
          padding: EdgeInsets.fromLTRB(
            20,
            10,
            20,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: pb.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.citedInAnswer.toUpperCase(),
                      style: text.labelSmall?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: pb.inkMuted,
                      ),
                    ),
                  ),
                  Container(
                    // 44 high: the two steps are 44px touch targets.
                    decoration: BoxDecoration(
                      color: pb.accentContainer,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        _Step(
                          icon: AppIcons.previous,
                          tooltip: l.citePrevious,
                          onTap: _i > 0 ? () => setState(() => _i--) : null,
                        ),
                        Text(
                          l.sourceNofM(_i + 1, total),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: pb.onAccentContainer,
                          ),
                        ),
                        _Step(
                          icon: AppIcons.next,
                          tooltip: l.citeNext,
                          onTap: _i < total - 1
                              ? () => setState(() => _i++)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: pb.tile,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isNote ? AppIcons.note : AppIcons.pdf,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.documentTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium,
                        ),
                        Text(
                          isNote
                              ? l.kindNote
                              : '${l.kindPdf} · ${l.pageN(c.page)}',
                          style: text.bodySmall?.copyWith(color: pb.inkMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: pb.tile,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(10),
                    // The cited passage as the editor shows it: a soft block
                    // with the violet rail on its left, theme colors only.
                    child: Container(
                      key: const ValueKey('sheet-quote'),
                      decoration: BoxDecoration(
                        color: pb.citeFill,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              width: 3,
                              decoration: BoxDecoration(
                                color: pb.citeEdge,
                                borderRadius: const BorderRadius.horizontal(
                                  left: Radius.circular(8),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Text(
                                  c.quote,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.6,
                                    color: pb.ink,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onOpen(c);
                  },
                  child: Text(l.openFullPage),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = context.pb.onAccentContainer;
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      color: color,
      disabledColor: color.withValues(alpha: 0.38),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
    );
  }
}
