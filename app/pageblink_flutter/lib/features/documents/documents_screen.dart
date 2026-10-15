import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pageblink_client/pageblink_client.dart';

import '../../app/l10n.dart';
import '../../app/local_pdfs.dart';
import '../../app/theme.dart';
import '../../client.dart';
import '../../app/open_item_controller.dart';
import '../open_item/open_item_view.dart';
import 'pdf_text.dart';

/// Keep-style board of notes and PDFs (personal and project).
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key, required this.projects});

  final List<Project> projects;

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<Document>? _documents;
  String? _busy;
  String? _error;
  _Filter _filter = _Filter.all;
  String _query = '';

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
      final docs = await client.document.list();
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

  Future<void> _upload() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (picked.isEmpty || !mounted) return;
    final file = picked.first;
    final l = context.l;

    final projectId = await _chooseTier();
    if (projectId == _cancelled || !mounted) return;

    setState(() => _busy = l.reading(file.name));
    try {
      final bytes = await file.readAsBytes();
      final pages = await extractPages(bytes, file.name);
      setState(() => _busy = l.indexingFile(file.name, pages.length));
      final title = file.name.replaceAll(
        RegExp(r'\.pdf$', caseSensitive: false),
        '',
      );
      final document = await client.document.upload(
        title,
        pages,
        contentHash(bytes),
        projectId,
      );
      await LocalPdfs.save(document.id!, bytes);
      setState(() => _busy = l.storingOriginal(file.name));
      await _storeOriginal(document.id!, bytes);
      if (document.status == 'failed') {
        _snack(
          l.indexingError(document.lastError).isEmpty
              ? l.indexingFailed
              : l.indexingError(document.lastError),
        );
      }
    } catch (e) {
      _snack(l.uploadFailed(e));
    } finally {
      if (mounted) setState(() => _busy = null);
      await _refresh();
    }
  }

  /// Uploads the original so citations open on any device. Non-fatal.
  Future<void> _storeOriginal(int documentId, Uint8List bytes) async {
    final l = context.l;
    try {
      final description = await client.document.pdfUploadDescription(
        documentId,
      );
      final ok = await FileUploader(
        description,
      ).uploadByteData(ByteData.sublistView(bytes));
      if (ok) await client.document.confirmPdfUpload(documentId);
    } catch (e) {
      _snack(l.originalSkipped(e));
    }
  }

  Future<void> _reindex(Document document) async {
    final l = context.l;
    setState(() => _busy = l.reindexing(document.title));
    try {
      final result = await client.document.reindex(document.id!);
      _snack(
        result.status == 'ready'
            ? l.indexed(result.title)
            : (result.lastError == null
                  ? l.indexingFailed
                  : l.indexingError(result.lastError)),
      );
    } catch (e) {
      _snack(l.reindexFailed(e));
    } finally {
      if (mounted) setState(() => _busy = null);
      await _refresh();
    }
  }

  Future<void> _reindexFailed() async {
    final l = context.l;
    setState(() => _busy = l.reindexingFailedItems);
    try {
      final ready = await client.document.reindexFailed();
      _snack(l.reindexedCount(ready));
    } catch (e) {
      _snack(l.reindexFailed(e));
    } finally {
      if (mounted) setState(() => _busy = null);
      await _refresh();
    }
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
      await client.document.delete(document.id!);
    } catch (e) {
      _snack(l.deleteFailed(e));
    }
    await _refresh();
  }

  Future<void> _openNote(Document? note) async {
    int? projectId;
    if (note == null && widget.projects.isNotEmpty) {
      final chosen = await _chooseTier();
      if (chosen == _cancelled || !mounted) return;
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

  static const _cancelled = -1;

  /// Returns null for personal cloud, a project id, or [_cancelled].
  Future<int?> _chooseTier() async {
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
              leading: const Icon(Icons.visibility_off_outlined),
              title: Text(l.cloakTitle),
              subtitle: Text(l.cloakSubtitle),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: Text(l.myCloud),
              subtitle: Text(l.onlyYou),
              onTap: () => Navigator.pop(context, 0),
            ),
            for (final p in widget.projects)
              ListTile(
                leading: const Icon(Icons.groups_outlined),
                title: Text(l.sharedVision(p.name)),
                subtitle: Text(l.shareWithMembers),
                onTap: () => Navigator.pop(context, p.id),
              ),
          ],
        ),
      ),
    );
    if (result == null) return _cancelled;
    return result == 0 ? null : result;
  }

  void _snack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  List<Document> _visible(List<Document> docs) {
    final q = _query.trim().toLowerCase();
    return [
      for (final d in docs)
        if (switch (_filter) {
              _Filter.all => true,
              _Filter.notes => d.kind == 'note',
              _Filter.pdfs => d.kind != 'note',
              _Filter.attention => d.status == 'failed',
            } &&
            (q.isEmpty ||
                d.title.toLowerCase().contains(q) ||
                (d.body ?? '').toLowerCase().contains(q)))
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
    Widget filter(_Filter f, String label, int n, {bool warn = false}) {
      final selected = _filter == f;
      final scheme = Theme.of(context).colorScheme;
      return ChoiceChip(
        selected: selected,
        showCheckmark: selected,
        avatar: warn
            ? Icon(Icons.error_outline, size: 16, color: pb.warn)
            : null,
        label: Text(warn ? l.needsAttention(n) : '$label $n'),
        backgroundColor: warn ? pb.warnContainer : null,
        side: warn
            ? BorderSide(color: pb.warnBorder)
            : (selected
                  ? BorderSide(color: scheme.primary.withValues(alpha: 0.55))
                  : null),
        labelStyle: warn ? TextStyle(color: pb.warn) : null,
        onSelected: (_) => setState(
          () => _filter = selected && f != _Filter.all ? _Filter.all : f,
        ),
      );
    }

    final search = TextField(
      onChanged: (v) => setState(() => _query = v),
      decoration: InputDecoration(
        hintText: l.searchHint,
        prefixIcon: const Icon(Icons.search),
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
                  icon: const Icon(Icons.add),
                  label: Text(l.newNote),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _busy == null ? _upload : null,
                  icon: const Icon(Icons.upload_outlined),
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
          const SizedBox(height: 16),
          Text(
            l.recent.toUpperCase(),
            style: theme.labelSmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: pb.inkMuted,
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
                  onPressed: _busy == null ? _upload : null,
                  child: const Icon(Icons.picture_as_pdf_outlined),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'note',
                  onPressed: () => _openNote(null),
                  icon: const Icon(Icons.edit_note),
                  label: Text(l.newNote),
                ),
              ],
            ),
      body: Column(
        children: [
          if (docs != null) _header(context, docs, wide),
          if (_busy == null &&
              (docs?.any((d) => d.status == 'failed') ?? false))
            MaterialBanner(
              backgroundColor: context.pb.warnContainer,
              leading: const Icon(Icons.sync_problem),
              content: Text(
                '${l.failedBanner(docs!.where((d) => d.status == 'failed').length)}\n'
                '${l.indexingError(docs.firstWhere((d) => d.status == 'failed').lastError)}',
              ),
              actions: [
                TextButton(
                  onPressed: _reindexFailed,
                  child: Text(l.reindexAll),
                ),
              ],
            ),
          if (_busy != null) ...[
            const LinearProgressIndicator(),
            Padding(padding: const EdgeInsets.all(8), child: Text(_busy!)),
          ],
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
                _ => GridView.builder(
                  padding: EdgeInsets.fromLTRB(
                    wide ? 0 : 12,
                    12,
                    wide ? 0 : 12,
                    140,
                  ),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 280,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    mainAxisExtent: 250,
                  ),
                  itemCount: _visible(docs).length,
                  itemBuilder: (context, i) {
                    final d = _visible(docs)[i];
                    return _DocumentCard(
                      d,
                      widget.projects,
                      onTap: d.kind == 'note'
                          ? () => _openNote(d)
                          : (d.status == 'ready' ? () => _openPdf(d) : null),
                      onLongPress: () => _delete(d),
                      onRetry: d.status == 'failed' ? () => _reindex(d) : null,
                    );
                  },
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

class _DocumentCard extends StatelessWidget {
  const _DocumentCard(
    this.document,
    this.projects, {
    this.onTap,
    this.onLongPress,
    this.onRetry,
  });

  final Document document;
  final List<Project> projects;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l;
    final pb = context.pb;
    final isNote = document.kind == 'note';
    final failed = document.status == 'failed';
    final project = projects
        .where((p) => p.id == document.projectId)
        .firstOrNull;
    final (tierIcon, tier) = document.projectId == null
        ? (Icons.cloud_outlined, l.myCloud)
        : (Icons.groups_outlined, project?.name ?? l.shared);
    final status = switch (document.status) {
      'ready' || 'failed' => null,
      'indexing' => l.indexing,
      _ => document.status,
    };
    final preview = isNote
        ? (document.body ?? '')
              .replaceAll(RegExp(r'[#*_>`]|- \[[ x]\] '), '')
              .trim()
        : '';
    final meta = isNote
        ? l.noteMeta(l.ago(document.updatedAt.toLocal()))
        : l.pdfMeta(document.pageCount);
    return Card(
      clipBehavior: Clip.antiAlias,
      color: failed
          ? pb.warnTint
          : (isNote ? pb.noteColor(document.id) : pb.pdfPaper),
      shadowColor: pb.ink.withValues(alpha: 0.06),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: failed
            ? BorderSide(color: pb.warnBorder, width: 1.5)
            : BorderSide(color: pb.ink.withValues(alpha: 0.10)),
      ),
      child: InkWell(
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
                      isNote
                          ? Icons.sticky_note_2_outlined
                          : Icons.picture_as_pdf_outlined,
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
                ],
              ),
              const SizedBox(height: 10),
              Text(
                document.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: failed
                    ? Align(
                        alignment: Alignment.topLeft,
                        child: _FailedBlock(
                          message: document.lastError == null
                              ? l.indexingFailed
                              : l.indexingError(document.lastError),
                          onRetry: onRetry,
                        ),
                      )
                    : Text(
                        preview,
                        overflow: TextOverflow.fade,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
              ),
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
                  const Spacer(),
                  if (status != null)
                    Text(
                      status,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: pb.warn,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Failed-index status block: amber container, reason, Re-index pill.
class _FailedBlock extends StatelessWidget {
  const _FailedBlock({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    final l = context.l;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: pb.warnContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, size: 16, color: pb.warn),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l.indexingFailed,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: pb.warn,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Tooltip(
            message: message,
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(l.reindex),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                foregroundColor: pb.warn,
                side: BorderSide(color: pb.warnBorder),
                shape: const StadiumBorder(),
              ),
            ),
          ),
        ],
      ),
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
