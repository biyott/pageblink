import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pageblink_client/pageblink_client.dart';

import '../../app/local_pdfs.dart';
import '../../app/theme.dart';
import '../../client.dart';
import '../notes/note_editor_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final docs = await client.document.list();
      if (mounted) {
        setState(() {
          _documents = docs;
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

    final projectId = await _chooseTier();
    if (projectId == _cancelled || !mounted) return;

    setState(() => _busy = '${file.name} 읽는 중…');
    try {
      final bytes = await file.readAsBytes();
      final pages = await extractPages(bytes, file.name);
      setState(() => _busy = '${file.name} 색인 중… (${pages.length}쪽)');
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
      setState(() => _busy = '${file.name} 원본 저장 중…');
      await _storeOriginal(document.id!, bytes);
      if (document.status == 'failed') {
        _snack('색인에 실패했습니다. 서버 로그를 확인해 주세요.');
      }
    } catch (e) {
      _snack('업로드 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = null);
      await _refresh();
    }
  }

  /// Uploads the original so citations open on any device. Non-fatal.
  Future<void> _storeOriginal(int documentId, Uint8List bytes) async {
    try {
      final description = await client.document.pdfUploadDescription(
        documentId,
      );
      final ok = await FileUploader(
        description,
      ).uploadByteData(ByteData.sublistView(bytes));
      if (ok) await client.document.confirmPdfUpload(documentId);
    } catch (e) {
      _snack('원본 저장은 건너뛰었어요 (이 기기에서는 열람 가능): $e');
    }
  }

  Future<void> _reindex(Document document) async {
    setState(() => _busy = '${document.title} 다시 색인 중…');
    try {
      final result = await client.document.reindex(document.id!);
      _snack(
        result.status == 'ready'
            ? '색인 완료: ${result.title}'
            : (result.lastError ?? '색인 실패'),
      );
    } catch (e) {
      _snack('다시 색인 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = null);
      await _refresh();
    }
  }

  Future<void> _reindexFailed() async {
    setState(() => _busy = '실패한 항목 다시 색인 중…');
    try {
      final ready = await client.document.reindexFailed();
      _snack('$ready개 색인 완료');
    } catch (e) {
      _snack('다시 색인 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = null);
      await _refresh();
    }
  }

  Future<void> _delete(Document document) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제할까요?'),
        content: Text(document.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await client.document.delete(document.id!);
    } catch (e) {
      _snack('삭제 실패: $e');
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
    final saved = await Navigator.push<Document>(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(note: note, projectId: projectId),
      ),
    );
    if (saved != null) await _refresh();
  }

  static const _cancelled = -1;

  /// Returns null for personal cloud, a project id, or [_cancelled].
  Future<int?> _chooseTier() async {
    final result = await showModalBottomSheet<int?>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('어디에 둘까요?')),
            const ListTile(
              enabled: false,
              leading: Icon(Icons.visibility_off_outlined),
              title: Text('Cloak · 이 기기에만'),
              subtitle: Text('오프라인 전용 문서 — 곧 지원'),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('내 클라우드'),
              subtitle: const Text('나만 볼 수 있어요'),
              onTap: () => Navigator.pop(context, 0),
            ),
            for (final p in widget.projects)
              ListTile(
                leading: const Icon(Icons.groups_outlined),
                title: Text('Shared Vision · ${p.name}'),
                subtitle: const Text('프로젝트 멤버와 공유'),
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

  @override
  Widget build(BuildContext context) {
    final docs = _documents;
    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'pdf',
            tooltip: 'PDF 올리기',
            onPressed: _busy == null ? _upload : null,
            child: const Icon(Icons.picture_as_pdf_outlined),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'note',
            onPressed: () => _openNote(null),
            icon: const Icon(Icons.edit_note),
            label: const Text('새 노트'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_busy == null &&
              (docs?.any((d) => d.status == 'failed') ?? false))
            MaterialBanner(
              leading: const Icon(Icons.sync_problem),
              content: Text(
                '색인 실패 ${docs!.where((d) => d.status == 'failed').length}개 — 질문 검색에서 빠져 있어요.\n'
                '${docs.firstWhere((d) => d.status == 'failed').lastError ?? ''}',
              ),
              actions: [
                TextButton(
                  onPressed: _reindexFailed,
                  child: const Text('모두 다시 색인'),
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
                [] => ListView(
                  children: const [
                    _Message('아직 노트가 없어요.\n메모를 쓰거나 PDF를 올리고 질문해 보세요.'),
                  ],
                ),
                _ => GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 140),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 260,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, i) => _DocumentCard(
                    docs[i],
                    widget.projects,
                    onTap: docs[i].kind == 'note'
                        ? () => _openNote(docs[i])
                        : null,
                    onLongPress: () => _delete(docs[i]),
                    onRetry: docs[i].status == 'failed'
                        ? () => _reindex(docs[i])
                        : null,
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
    final isNote = document.kind == 'note';
    final project = projects
        .where((p) => p.id == document.projectId)
        .firstOrNull;
    final (tierIcon, tier) = document.projectId == null
        ? (Icons.cloud_outlined, '내 클라우드')
        : (Icons.groups_outlined, project?.name ?? '공유');
    final status = switch (document.status) {
      'ready' => null,
      'indexing' => '색인 중',
      'failed' => '색인 실패',
      _ => document.status,
    };
    final preview = isNote
        ? (document.body ?? '')
              .replaceAll(RegExp(r'[#*_>`]|- \[[ x]\] '), '')
              .trim()
        : 'PDF · ${document.pageCount}쪽';
    final pb = context.pb;
    final failed = document.status == 'failed';
    return Card(
      clipBehavior: Clip.antiAlias,
      color: isNote ? pb.noteColor(document.id) : pb.pdfPaper,
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
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isNote
                        ? Icons.sticky_note_2_outlined
                        : Icons.picture_as_pdf_outlined,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      document.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  preview,
                  overflow: TextOverflow.fade,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              Row(
                children: [
                  Icon(tierIcon, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      tier,
                      style: theme.textTheme.labelSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onRetry != null)
                    Tooltip(
                      message: document.lastError ?? '다시 색인',
                      child: InkWell(
                        onTap: onRetry,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.refresh,
                              size: 14,
                              color: theme.colorScheme.error,
                            ),
                            Text(
                              ' 다시 색인',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: context.pb.warn,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (status != null)
                    Text(
                      status,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.error,
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
