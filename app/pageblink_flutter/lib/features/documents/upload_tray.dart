import 'package:flutter/material.dart';

import '../../app/app_icons.dart';
import '../../app/l10n.dart';
import '../../app/pb_interactive.dart';
import '../../app/theme.dart';
import 'upload_controller.dart';
import 'upload_service.dart';

/// Per-file progress of the shell's [UploadController]: reading, indexing,
/// saving the original; cancel (queued), retry (failed), done. The caller
/// positions it (pane bottom-right on wide layouts, above the nav on phones).
class UploadTray extends StatelessWidget {
  const UploadTray({super.key, this.width = 340});

  final double? width;

  @override
  Widget build(BuildContext context) {
    final controller = UploadScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final rows = controller.rows;
        if (rows.isEmpty || controller.hidden) return const SizedBox.shrink();
        return _TrayPanel(controller: controller, rows: rows, width: width);
      },
    );
  }
}

class _TrayPanel extends StatelessWidget {
  const _TrayPanel({
    required this.controller,
    required this.rows,
    required this.width,
  });

  final UploadController controller;
  final List<TrayRow> rows;
  final double? width;

  String _header(L l) {
    final files = rows.where((r) => r.rejected == null).toList();
    final failed = rows.where((r) => r.state == RowState.failed).length;
    final done = rows.where((r) => r.state == RowState.done).length;
    if (controller.hasActive) {
      final finished = files.where((r) => !r.active).length;
      final i = (finished + 1).clamp(1, files.length);
      return failed > 0
          ? l.trayAddingIssues(files.length, failed)
          : l.trayAdding(files.length, i);
    }
    return failed == 0 ? l.trayDone(done) : l.trayPartial(done, failed);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final pb = context.pb;
    final text = Theme.of(context).textTheme;
    final collapsed = controller.collapsed;
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: pb.sheet,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: pb.hairline),
          boxShadow: [
            BoxShadow(
              color: pb.ink.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 44,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _header(l),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleSmall?.copyWith(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: collapsed ? l.expandTray : l.collapse,
                        iconSize: 18,
                        onPressed: controller.toggleCollapsed,
                        icon: AnimatedRotation(
                          turns: collapsed ? 0.5 : 0,
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 140),
                          child: const Icon(AppIcons.expand),
                        ),
                      ),
                      IconButton(
                        tooltip: l.dismiss,
                        iconSize: 18,
                        onPressed: controller.close,
                        icon: const Icon(AppIcons.close),
                      ),
                    ],
                  ),
                ),
              ),
              if (!collapsed)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 4 * 66),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final row in rows)
                          _RowView(
                            key: ObjectKey(row),
                            row: row,
                            controller: controller,
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowView extends StatelessWidget {
  const _RowView({super.key, required this.row, required this.controller});

  final TrayRow row;
  final UploadController controller;

  String _status(L l) {
    final o = row.outcome;
    return switch (row.state) {
      RowState.waiting => l.stageWaiting,
      RowState.reading => l.stageReading,
      RowState.indexing => l.stageIndexing(row.pages),
      RowState.storing => l.stageStoring,
      RowState.done =>
        o?.kind == UploadKind.duplicate
            ? l.stageDuplicate
            : l.stageDone(row.document?.pageCount ?? row.pages),
      RowState.failed =>
        row.rejected != null
            ? l.onlyPdf(row.rejected!.ext)
            : (o == null ? '' : uploadReasonText(l, o)),
      RowState.cancelled => '',
    };
  }

  /// 0 = reading, 1 = indexing, 2 = storing; segments before it are full.
  int get _segment => switch (row.state) {
    RowState.waiting || RowState.reading => 0,
    RowState.indexing => 1,
    _ => 2,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final pb = context.pb;
    final text = Theme.of(context).textTheme;
    final failed = row.state == RowState.failed;
    final done = row.state == RowState.done;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final Widget action;
    if (row.canCancel) {
      action = _IconAction(
        tooltip: l.cancel,
        icon: AppIcons.close,
        onPressed: () => controller.cancel(row),
      );
    } else if (row.active) {
      action = const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else if (done) {
      action = Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(AppIcons.done, size: 18, color: pb.success),
      );
    } else {
      action = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (row.canRetry)
            TextButton(
              onPressed: () => controller.retry(row),
              style: TextButton.styleFrom(
                foregroundColor: pb.linkInk,
                minimumSize: Size(0, pbTarget(context)),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(l.retry),
            ),
          _IconAction(
            tooltip: l.dismiss,
            icon: AppIcons.close,
            onPressed: () => controller.dismiss(row),
          ),
        ],
      );
    }
    final showBar = row.rejected == null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: failed ? pb.warnContainer : pb.tile,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  failed ? AppIcons.fileWarning : AppIcons.pdf,
                  size: 18,
                  color: failed ? pb.warn : pb.ink,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    Text(
                      _status(l),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: failed ? pb.warnText : pb.inkMuted,
                      ),
                    ),
                    if (failed && row.outcome?.detail != null)
                      SelectableText(
                        l.diagnostic(row.outcome!.detail!),
                        maxLines: 2,
                        style: text.bodySmall?.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: pb.inkMuted,
                        ),
                      ),
                  ],
                ),
              ),
              action,
            ],
          ),
          if (showBar)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 3),
                    Expanded(
                      child: AnimatedContainer(
                        duration: reduced
                            ? Duration.zero
                            : const Duration(milliseconds: 240),
                        curve: Curves.easeOut,
                        height: 3.5,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: done
                              ? pb.success
                              : failed
                              ? pb.warn.withValues(alpha: 0.35)
                              : i < _segment
                              ? pb.accent
                              : i == _segment && row.state != RowState.waiting
                              ? pb.accent.withValues(alpha: 0.55)
                              : pb.ink.withValues(alpha: 0.10),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    iconSize: 18,
    onPressed: onPressed,
    icon: Icon(icon),
  );
}
