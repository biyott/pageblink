import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pageblink_client/pageblink_client.dart';

import '../../app/l10n.dart';
import '../../app/text_norm.dart';
import '../../app/theme.dart';
import '../../client.dart';
import '../../app/open_item_controller.dart';
import '../demo/demo.dart';
import '../open_item/open_item_view.dart';
import 'index_status.dart';
import 'note_color_picker.dart';
import 'tier_sheet.dart';
import 'upload_controller.dart';
import 'upload_service.dart';
import '../../app/app_icons.dart';

/// The server calls the board makes; replaceable in tests (`client` is a
/// global). Closures read `client` only when called.
class BoardApi {
  const BoardApi({
    required this.list,
    required this.reindex,
    required this.delete,
    required this.setNoteColor,
  });

  factory BoardApi.live() => BoardApi(
    list: () => client.document.list(),
    reindex: (id) => client.document.reindex(id),
    delete: (id) => client.document.delete(id),
    setNoteColor: (id, colorIndex) =>
        client.document.setNoteColor(id, colorIndex),
  );

  final Future<List<Document>> Function() list;
  final Future<Document> Function(int id) reindex;
  final Future<void> Function(int id) delete;

  /// null clears the color (automatic).
  final Future<Document> Function(int id, int? colorIndex) setNoteColor;
}

/// Keep-style board of notes and PDFs (personal and project).
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({
    super.key,
    required this.projects,
    @visibleForTesting this.pickPdfs,
    @visibleForTesting this.boardApi,
  });

  final List<Project> projects;

  /// Test hooks: replace the native picker and the server calls.
  final Future<List<PickedPdf>> Function()? pickPdfs;
  final BoardApi? boardApi;

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<Document>? _documents;
  String? _error;
  _Filter _filter = _Filter.all;
  String _query = '';

  /// Cards being re-indexed right now (each locks only itself).
  final _reindexing = <int>{};
  bool _retryingAll = false;

  /// Cards that just arrived from an upload (they flash).
  static final _noFlash = ValueNotifier<Set<int>>(const {});

  BoardApi get _api => widget.boardApi ?? BoardApi.live();

  @override
  void initState() {
    super.initState();
    _refresh();
    boardRefresh.addListener(_refresh);
  }

  @override
  void dispose() {
    boardRefresh.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final docs = await _api.list();
      if (mounted) {
        setState(() {
          _documents = docs;
          documentsNotifier.value = docs;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// File picker -> [PickedPdf] (the service knows no platform file type).
  static Future<List<PickedPdf>> _pickPdfs() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    return [
      for (final f in picked)
        PickedPdf(name: f.name, size: f.lengthSync(), read: f.readAsBytes),
    ];
  }

  /// Picker -> where to put it -> the shell's upload queue (progress shows in
  /// the tray, so this stays usable while files upload).
  Future<void> _upload() async {
    if (await demoBlocksCreate(context) || !mounted) return;
    final picked = await (widget.pickPdfs ?? _pickPdfs)();
    if (picked.isEmpty || !mounted) return;
    final uploads = UploadScope.maybeOf(context);
    if (uploads == null) return;
    final projectId = await chooseUploadTier(context, widget.projects);
    if (projectId == tierCancelled || !mounted) return;
    uploads.enqueue(picked, projectId: projectId);
  }

  /// Re-indexes one card. Returns whether it is `ready` afterwards; the user
  /// sees fixed texts only (raw errors go to the log).
  Future<bool> _reindexOne(Document document, {bool announce = true}) async {
    final id = document.id!;
    if (!_reindexing.add(id)) return false;
    final l = context.l;
    setState(() {});
    var ready = false;
    try {
      final result = await _api.reindex(id);
      ready = result.status == 'ready';
      if (announce) {
        _snack(
          ready
              ? l.indexed(result.title)
              : (result.lastError == null
                    ? l.indexingFailed
                    : l.indexingError(result.lastError)),
        );
      }
    } catch (e) {
      debugPrint('reindex failed: $e');
      if (announce) {
        if (e is DemoLimitException) {
          _demoLimit(l, e);
        } else {
          _snack(l.reindexFailed);
        }
      }
    } finally {
      _reindexing.remove(id);
      if (mounted) setState(() {});
      await _refresh();
    }
    return ready;
  }

  Future<void> _reindex(Document document) => _reindexOne(document);

  /// Retries every failure a retry can fix, one after another.
  Future<void> _retryFailed() async {
    if (_retryingAll) return;
    final l = context.l;
    final targets = [
      ...?_documents?.where(
        (d) => isRetryableFailure(d) && !_reindexing.contains(d.id),
      ),
    ];
    if (targets.isEmpty) return;
    setState(() => _retryingAll = true);
    var ok = 0;
    try {
      for (final d in targets) {
        if (await _reindexOne(d, announce: false)) ok++;
        if (!mounted) return;
      }
    } finally {
      if (mounted) setState(() => _retryingAll = false);
    }
    final left = targets.length - ok;
    _snack(left == 0 ? l.reindexedCount(ok) : l.retryResult(ok, left));
  }

  Future<void> _delete(Document document) async {
    final l = context.l;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.deleteQuestion),
        content: Text(document.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.delete(document.id!);
    } catch (e) {
      debugPrint('delete failed: $e');
      if (e is DemoLimitException) {
        _demoLimit(l, e);
      } else {
        _snack(l.deleteFailed);
      }
    }
    await _refresh();
  }

  Future<void> _setNoteColor(Document document, int? colorIndex) async {
    final l = context.l;
    try {
      await _api.setNoteColor(document.id!, colorIndex);
    } catch (e) {
      debugPrint('set note color failed: $e');
      if (e is DemoLimitException) {
        _demoLimit(l, e);
      } else {
        _snack(l.colorFailed);
      }
    }
    await _refresh();
  }

  Future<void> _openNote(Document? note) async {
    if (note == null && (await demoBlocksCreate(context) || !mounted)) return;
    int? projectId;
    if (note == null && widget.projects.isNotEmpty) {
      final chosen = await chooseUploadTier(context, widget.projects);
      if (chosen == tierCancelled || !mounted) return;
      projectId = chosen;
    }
    if (!mounted) return;
    await openItem(
      context,
      OpenItem.note(note: note, projectId: projectId),
    );
  }

  /// PDFs open at their first page, in the same place notes do.
  Future<void> _openPdf(Document pdf) => openItem(
    context,
    OpenItem.citation(
      Citation(
        index: 0,
        documentId: pdf.id!,
        documentTitle: pdf.title,
        page: 1,
        quote: '',
      ),
    ),
  );

  void _demoLimit(L l, DemoLimitException e) {
    if (mounted) showDemoLimit(ScaffoldMessenger.of(context), l, e);
  }

  void _snack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  List<Document> _visible(List<Document> docs) {
    final q = nfc(_query.trim()).toLowerCase();
    return [
      for (final d in docs)
        if (switch (_filter) {
              _Filter.all => true,
              _Filter.notes => d.kind == 'note',
              _Filter.pdfs => d.kind != 'note',
              _Filter.attention => d.status == 'failed',
            } &&
            (q.isEmpty ||
                nfc(d.title).toLowerCase().contains(q) ||
                nfc(d.body ?? '').toLowerCase().contains(q)))
          d,
    ];
  }

  Widget _header(BuildContext context, List<Document> docs, bool wide) {
    final l = context.l;
    final pb = context.pb;
    final theme = Theme.of(context).textTheme;
    final notes = docs.where((d) => d.kind == 'note').length;
    final pdfs = docs.length - notes;
    final failed = docs.where((d) => d.status == 'failed').length;
    final retryable = docs.where(isRetryableFailure).length;
    Widget filter(_Filter f, String label, int n, {bool warn = false}) {
      final selected = _filter == f;
      final scheme = Theme.of(context).colorScheme;
      return ChoiceChip(
        selected: selected,
        showCheckmark: selected,
        // Failures are calm here: neutral chip, one warn dot (§2.4).
        avatar: warn
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: pb.warn,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox.square(dimension: 7),
              )
            : null,
        label: Text(warn ? l.needsAttention(n) : '$label $n'),
        side: selected
            ? BorderSide(color: scheme.primary.withValues(alpha: 0.55))
            : null,
        onSelected: (_) => setState(
          () => _filter = selected && f != _Filter.all ? _Filter.all : f,
        ),
      );
    }

    final search = TextField(
      onChanged: (v) => setState(() => _query = v),
      decoration: InputDecoration(
        hintText: l.searchHint,
        prefixIcon: const Icon(AppIcons.search),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: pb.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: pb.hairline),
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        wide ? 0 : 12,
        wide ? 0 : 8,
        wide ? 0 : 12,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.tabNotes,
            style: theme.headlineMedium?.copyWith(
              fontSize: wide ? 32 : 28,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.boardCount(notes, pdfs),
            style: theme.bodyMedium?.copyWith(color: pb.inkMuted),
          ),
          const SizedBox(height: 16),
          if (wide)
            Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () => _openNote(null),
                  icon: const Icon(AppIcons.add),
                  label: Text(l.newNote),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _upload,
                  icon: const Icon(AppIcons.upload),
                  label: Text(l.uploadPdf),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    backgroundColor: pb.glassStrong,
                    foregroundColor: pb.ink,
                    side: BorderSide(color: pb.hairline),
                  ),
                ),
              ],
            )
          else
            search,
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              filter(_Filter.all, l.filterAll, docs.length),
              filter(_Filter.notes, l.filterNotes, notes),
              filter(_Filter.pdfs, l.filterPdfs, pdfs),
              if (failed > 0) filter(_Filter.attention, '', failed, warn: true),
            ],
          ),
          const SizedBox(height: 8),
          // Fixed height: the retry link appears here without moving the grid.
          SizedBox(
            height: 32,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.recent.toUpperCase(),
                    style: theme.labelSmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: pb.inkMuted,
                    ),
                  ),
                ),
                if (_retryingAll)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox.square(
                        dimension: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: pb.inkMuted,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l.retrying,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: pb.inkMuted,
                        ),
                      ),
                    ],
                  )
                else if (retryable > 0)
                  _InlineLink(
                    icon: AppIcons.refresh,
                    label: l.retryFailed(retryable),
                    onPressed: _retryFailed,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docs = _documents;
    final l = context.l;
    final wide = MediaQuery.sizeOf(context).width >= 600;
    final flash = UploadScope.maybeOf(context)?.flash ?? _noFlash;
    return Scaffold(
      floatingActionButton: wide
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: 'pdf',
                  tooltip: l.uploadPdf,
                  onPressed: _upload,
                  child: const Icon(AppIcons.pdf),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'note',
                  onPressed: () => _openNote(null),
                  icon: const Icon(AppIcons.newNote),
                  label: Text(l.newNote),
                ),
              ],
            ),
      body: Column(
        children: [
          if (docs != null) _header(context, docs, wide),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: switch (docs) {
                null when _error != null => ListView(
                  children: [_Message(_error!)],
                ),
                null => const Center(child: CircularProgressIndicator()),
                [] => ListView(children: [_Message(l.emptyNotes)]),
                _ when _visible(docs).isEmpty => ListView(
                  children: [_Message(l.noMatches)],
                ),
                _ => ValueListenableBuilder<Set<int>>(
                  valueListenable: flash,
                  builder: (context, flashing, _) => GridView.builder(
                    padding: EdgeInsets.fromLTRB(
                      wide ? 0 : 12,
                      12,
                      wide ? 0 : 12,
                      140,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 280,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          mainAxisExtent: 250,
                        ),
                    itemCount: _visible(docs).length,
                    itemBuilder: (context, i) {
                      final d = _visible(docs)[i];
                      final busy = _reindexing.contains(d.id);
                      return DocumentCard(
                        d,
                        widget.projects,
                        key: ValueKey(d.id),
                        onTap: d.kind == 'note'
                            ? () => _openNote(d)
                            : (d.status == 'ready' ? () => _openPdf(d) : null),
                        onLongPress: () => _delete(d),
                        onDelete: () => _delete(d),
                        onSetColor: (c) => _setNoteColor(d, c),
                        // Any status: also rescues a doc stuck in 'indexing'.
                        // Only this card is locked while it runs.
                        onReindex: busy ? null : () => _reindex(d),
                        onRetry: busy || !isRetryableFailure(d)
                            ? null
                            : () => _reindex(d),
                        reindexing: busy,
                        highlight: flashing.contains(d.id),
                      );
                    },
                  ),
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum _Filter { all, notes, pdfs, attention }

/// Latest board contents, shared so the desktop sidebar can show tier counts.
final documentsNotifier = ValueNotifier<List<Document>>(const []);

enum _CardAction { reindex, color, delete }

/// The card's `⋯` menu. "Color" opens the picker: a bottom sheet on phones, a
/// popover anchored to the `⋯` button on wider layouts.
class _CardMenu extends StatefulWidget {
  const _CardMenu({
    required this.document,
    required this.onReindex,
    required this.onDelete,
    required this.onSetColor,
  });

  final Document document;
  final VoidCallback? onReindex;
  final VoidCallback? onDelete;

  /// null hides the "Color" entry.
  final ValueChanged<int?>? onSetColor;

  @override
  State<_CardMenu> createState() => _CardMenuState();
}

class _CardMenuState extends State<_CardMenu> {
  final _popover = MenuController();

  void _color() {
    final pick = widget.onSetColor!;
    if (MediaQuery.sizeOf(context).width < noteColorSheetBreakpoint) {
      showNoteColorSheet(context, widget.document.colorIndex, pick);
    } else {
      _popover.open();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final pb = context.pb;
    return MenuAnchor(
      controller: _popover,
      style: noteColorMenuStyle(pb),
      menuChildren: [
        NoteColorPopover(
          current: widget.document.colorIndex,
          onPick: (c) => widget.onSetColor?.call(c),
        ),
      ],
      child: PopupMenuButton<_CardAction>(
        tooltip: l.moreActions,
        icon: Icon(AppIcons.more, size: 18, color: pb.inkMuted),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        onSelected: (action) {
          switch (action) {
            case _CardAction.reindex:
              widget.onReindex?.call();
            case _CardAction.color:
              _color();
            case _CardAction.delete:
              widget.onDelete?.call();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: _CardAction.reindex,
            enabled: widget.onReindex != null,
            child: Text(l.reindex),
          ),
          if (widget.onSetColor != null)
            PopupMenuItem(value: _CardAction.color, child: Text(l.noteColor)),
          PopupMenuItem(
            value: _CardAction.delete,
            enabled: widget.onDelete != null,
            child: Text(l.delete),
          ),
        ],
      ),
    );
  }
}

@visibleForTesting
class DocumentCard extends StatelessWidget {
  const DocumentCard(
    this.document,
    this.projects, {
    super.key,
    this.onTap,
    this.onLongPress,
    this.onRetry,
    this.onReindex,
    this.onDelete,
    this.onSetColor,
    this.reindexing = false,
    this.highlight = false,
    this.now,
  });

  final Document document;
  final List<Project> projects;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// The status line's "Retry" link; null hides it.
  final VoidCallback? onRetry;

  /// Menu entry; null disables it (this card is re-indexing).
  final VoidCallback? onReindex;
  final VoidCallback? onDelete;

  /// Menu entry "Color" (notes only); null hides it. Called with the picked
  /// color index, or null for Auto.
  final ValueChanged<int?>? onSetColor;

  /// A re-index of this card is running: "Re-indexing", no link.
  final bool reindexing;

  /// Just arrived from an upload: flashes a ring (1.54 s).
  final bool highlight;

  /// Clock for the indexing wording phases; tests replace it.
  final DateTime Function()? now;

  /// Paints [gradient] under the ink so splashes stay visible; the card's
  /// flat color shows through when there is none.
  static Widget _gradient(Gradient? gradient, Widget child) => gradient == null
      ? child
      : Ink(
          decoration: BoxDecoration(gradient: gradient),
          child: child,
        );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l;
    final pb = context.pb;
    final isNote = document.kind == 'note';
    final project = projects
        .where((p) => p.id == document.projectId)
        .firstOrNull;
    final (tierIcon, tier) = document.projectId == null
        ? (AppIcons.tierCloud, l.myCloud)
        : (AppIcons.tierShared, project?.name ?? l.shared);
    final line = indexLine(l, document, reindexing: reindexing);
    final preview = isNote
        ? (document.body ?? '')
              .replaceAll(RegExp(r'[#*_>`]|- \[[ x]\] '), '')
              .trim()
        : '';
    final meta = isNote
        ? l.noteMeta(l.ago(document.updatedAt.toLocal()))
        : l.pdfMeta(document.pageCount);
    // PDFs have no preview: the body shows what is going on instead.
    final Widget body;
    if (isNote) {
      body = Text(
        preview,
        overflow: TextOverflow.fade,
        style: theme.textTheme.bodySmall?.copyWith(fontSize: 13, height: 1.5),
      );
    } else if (line != null && line.pulse) {
      body = const _Skeleton();
    } else if (line?.reason != null) {
      body = Text(
        line!.reason!,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(fontSize: 13, height: 1.4),
      );
    } else {
      body = const SizedBox.shrink();
    }
    final gradient = isNote ? pb.noteGradient(document.colorIndex) : null;
    final card = Card(
      clipBehavior: Clip.antiAlias,
      // The card keeps its own color in every state (§2.1).
      color: !isNote
          ? pb.pdfPaper
          : gradient != null
          ? Colors.transparent
          : pb.noteColor(document.id, colorIndex: document.colorIndex),
      shadowColor: pb.ink.withValues(alpha: 0.06),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: pb.ink.withValues(alpha: 0.10)),
      ),
      child: _gradient(
        gradient,
        InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: pb.tile,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isNote ? AppIcons.note : AppIcons.pdf,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: pb.inkMuted,
                        ),
                      ),
                    ),
                    _CardMenu(
                      document: document,
                      onReindex: onReindex,
                      onDelete: onDelete,
                      onSetColor: isNote ? onSetColor : null,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  document.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(child: body),
                if (line != null)
                  _StatusLine(
                    document: document,
                    reindexing: reindexing,
                    showReasonTip: isNote,
                    onRetry: onRetry,
                    now: now,
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: pb.chipBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(tierIcon, size: 14),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 110),
                            child: Text(
                              tier,
                              style: theme.textTheme.labelSmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!highlight) return card;
    return Stack(
      children: [
        card,
        const Positioned.fill(child: IgnorePointer(child: _FlashRing())),
      ],
    );
  }
}

/// One status line under a card: dot or icon + label, then a "Retry" link
/// when a retry can help. Re-evaluates the indexing wording when the 20 s and
/// 3 min marks pass.
class _StatusLine extends StatefulWidget {
  const _StatusLine({
    required this.document,
    required this.reindexing,
    required this.showReasonTip,
    required this.onRetry,
    required this.now,
  });

  final Document document;
  final bool reindexing;
  final bool showReasonTip;
  final VoidCallback? onRetry;
  final DateTime Function()? now;

  @override
  State<_StatusLine> createState() => _StatusLineState();
}

class _StatusLineState extends State<_StatusLine> {
  Timer? _timer;

  DateTime get _now => (widget.now ?? DateTime.now)();
  Duration get _elapsed => _now.difference(widget.document.updatedAt);

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(_StatusLine old) {
    super.didUpdateWidget(old);
    _arm();
  }

  /// Wakes once at the next wording threshold (no polling).
  void _arm() {
    _timer?.cancel();
    _timer = null;
    final d = widget.document;
    if (widget.reindexing || d.status == 'ready' || d.status == 'failed') {
      return;
    }
    final e = _elapsed;
    final next = e < indexingLongAfter
        ? indexingLongAfter - e
        : e < indexingVeryLongAfter
        ? indexingVeryLongAfter - e
        : null;
    if (next == null) return;
    _timer = Timer(next + const Duration(milliseconds: 1), () {
      if (mounted) {
        setState(() {});
        _arm();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final pb = context.pb;
    final line = indexLine(
      l,
      widget.document,
      elapsed: _elapsed,
      reindexing: widget.reindexing,
    );
    if (line == null) return const SizedBox.shrink();
    final (labelColor, weight) = switch (line.tone) {
      IndexTone.warn => (pb.warnText, FontWeight.w600),
      IndexTone.neutral => (pb.ink, FontWeight.w600),
      IndexTone.calm => (pb.inkMuted, FontWeight.w500),
    };
    Widget label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (line.pulse)
          const _PulseDot()
        else
          Icon(
            line.icon,
            size: 14,
            color: line.tone == IndexTone.warn ? pb.warn : pb.inkMuted,
          ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            line.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: weight,
              height: 1.3,
              letterSpacing: 0,
              color: labelColor,
            ),
          ),
        ),
      ],
    );
    // The reason is a tooltip on the label only; the link keeps its own tap.
    if (widget.showReasonTip && line.reason != null) {
      label = Tooltip(
        message: line.reason!,
        triggerMode: TooltipTriggerMode.tap,
        child: label,
      );
    }
    final showLink = line.canRetry && widget.onRetry != null;
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Align(widthFactor: 1, child: label),
          ),
          if (showLink)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ' · ',
                  style: TextStyle(fontSize: 12, color: pb.inkMuted),
                ),
                _InlineLink(label: l.retry, onPressed: widget.onRetry!),
              ],
            ),
        ],
      ),
    );
  }
}

/// A small text link (`linkInk`, no padding tricks): shrink-wrapped tap
/// target so it fits a 32 px line instead of growing to 48 (UP-07).
class _InlineLink extends StatelessWidget {
  const _InlineLink({required this.label, required this.onPressed, this.icon});

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      foregroundColor: context.pb.linkInk,
      minimumSize: const Size(0, 32),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      textStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
    );
    return icon == null
        ? TextButton(onPressed: onPressed, style: style, child: Text(label))
        : TextButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: 14),
            label: Text(label),
          );
  }
}

/// Opacity 1.0 <-> 0.35 on a 1100 ms cycle; static with reduced motion.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.builder});

  final Widget Function(BuildContext context, double opacity) builder;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
      _c.value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) => widget.builder(
      context,
      1 - 0.65 * Curves.easeInOut.transform(_c.value),
    ),
  );
}

class _PulseDot extends StatelessWidget {
  const _PulseDot();

  @override
  Widget build(BuildContext context) {
    final accent = context.pb.accent;
    return _Pulse(
      builder: (context, o) => SizedBox.square(
        dimension: 16,
        child: Stack(
          alignment: Alignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.22 * o),
              ),
              child: const SizedBox.square(dimension: 16),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: o),
              ),
              child: const SizedBox.square(dimension: 8),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three thin bars where a PDF's text preview would be (78 / 90 / 55 %).
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    final base = context.pb.ink;
    return Align(
      alignment: Alignment.topLeft,
      child: _Pulse(
        builder: (context, o) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, w) in const [0.78, 0.90, 0.55].indexed) ...[
              if (i > 0) const SizedBox(height: 8),
              FractionallySizedBox(
                widthFactor: w,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: base.withValues(alpha: 0.10 * (0.4 + 0.6 * o)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const SizedBox(height: 8, width: double.infinity),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ring + glow that fades in and out twice over 1540 ms (a new card). With
/// reduced motion it holds steady and fades at the end.
class _FlashRing extends StatefulWidget {
  const _FlashRing();

  @override
  State<_FlashRing> createState() => _FlashRingState();
}

class _FlashRingState extends State<_FlashRing>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1540),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.pb.accent;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_c.value);
        final a = reduced
            ? (_c.value < 0.9 ? 0.9 : 0.9 * (1 - (_c.value - 0.9) / 0.1))
            : 0.9 * (0.5 - 0.5 * math.cos(t * 4 * math.pi));
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accent.withValues(alpha: a),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.35 * a),
                blurRadius: 14,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(48),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyLarge,
    ),
  );
}
