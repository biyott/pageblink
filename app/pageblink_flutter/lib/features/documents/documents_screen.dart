import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pageblink_client/pageblink_client.dart';

import '../../app/local_pdfs.dart';
import '../../client.dart';
import 'pdf_text.dart';

/// Lists personal and project documents and uploads new PDFs.
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy == null ? _upload : null,
        icon: const Icon(Icons.upload_file),
        label: const Text('PDF 올리기'),
      ),
      body: Column(
        children: [
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
                  children: const [_Message('아직 문서가 없어요.\nPDF를 올리고 질문해 보세요.')],
                ),
                _ => ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) =>
                      _DocumentTile(docs[i], widget.projects),
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile(this.document, this.projects);

  final Document document;
  final List<Project> projects;

  @override
  Widget build(BuildContext context) {
    final project = projects
        .where((p) => p.id == document.projectId)
        .firstOrNull;
    final (icon, tier) = document.projectId == null
        ? (Icons.cloud_outlined, '내 클라우드')
        : (Icons.groups_outlined, project?.name ?? '공유 프로젝트');
    final status = switch (document.status) {
      'ready' => null,
      'indexing' => '색인 중',
      'failed' => '실패',
      _ => document.status,
    };
    return ListTile(
      leading: const Icon(Icons.picture_as_pdf_outlined),
      title: Text(document.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text('$tier · ${document.pageCount}쪽'),
        ],
      ),
      trailing: status == null ? null : Chip(label: Text(status)),
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
