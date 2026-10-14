import 'package:flutter/material.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../app/local_pdfs.dart';

/// Blink: opens the cited PDF right at the cited page.
/// Falls back to the quoted passage when the original isn't on this device.
class PageViewerScreen extends StatelessWidget {
  const PageViewerScreen({super.key, required this.citation});

  final Citation citation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${citation.documentTitle} · p.${citation.page}'),
      ),
      body: FutureBuilder(
        future: LocalPdfs.load(citation.documentId),
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
        '원본 PDF가 이 기기에 없어 인용 구절만 보여 드려요.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 16),
      Text('“${citation.quote}”', style: Theme.of(context).textTheme.bodyLarge),
    ],
  );
}
