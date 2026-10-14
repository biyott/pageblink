import 'package:flutter/material.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../app/l10n.dart';
import '../../app/local_pdfs.dart';
import '../../client.dart';
import '../notes/note_editor_screen.dart';

/// Blink: opens the cited PDF right at the cited page.
/// Falls back to the quoted passage when the original isn't on this device.
class PageViewerScreen extends StatelessWidget {
  const PageViewerScreen({super.key, required this.citation});

  final Citation citation;

  @override
  Widget build(BuildContext context) {
    if (citation.kind == 'note') return _NoteCitation(citation);
    return Scaffold(
      appBar: AppBar(
        title: Text('${citation.documentTitle} · p.${citation.page}'),
      ),
      body: FutureBuilder(
        future: LocalPdfs.fetch(citation.documentId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final bytes = snapshot.data;
          if (bytes == null) return _QuoteView(citation);
          return Column(
            children: [
              _QuoteBanner(citation.quote),
              Expanded(
                child: PdfViewer(
                  PdfDocumentRefData(
                    bytes,
                    sourceName: 'doc-${citation.documentId}',
                  ),
                  initialPageNumber: citation.page,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QuoteBanner extends StatelessWidget {
  const _QuoteBanner(this.quote);
  final String quote;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: colors.secondaryContainer,
      padding: const EdgeInsets.all(12),
      child: Text('“$quote”', maxLines: 3, overflow: TextOverflow.ellipsis),
    );
  }
}

class _QuoteView extends StatelessWidget {
  const _QuoteView(this.citation);
  final Citation citation;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text(
        context.l.originalMissing,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 16),
      Text('“${citation.quote}”', style: Theme.of(context).textTheme.bodyLarge),
    ],
  );
}

/// Notes open in the editor with the cited passage highlighted on top.
class _NoteCitation extends StatelessWidget {
  const _NoteCitation(this.citation);
  final Citation citation;

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: client.document.get(citation.documentId),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final note = snapshot.data;
      if (note == null) {
        return Scaffold(appBar: AppBar(), body: _QuoteView(citation));
      }
      return NoteEditorScreen(note: note, highlight: citation.quote);
    },
  );
}
