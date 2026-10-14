import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../app/l10n.dart';
import '../../app/local_pdfs.dart';
import '../../app/pane_header.dart';

/// Blink: shows the cited PDF right at the cited page.
/// Falls back to the quoted passage when the original isn't available.
class PdfPageView extends StatefulWidget {
  const PdfPageView({
    super.key,
    required this.documentId,
    required this.title,
    required this.page,
    required this.quote,
    required this.embedded,
    required this.onClose,
  });

  final int documentId;
  final String title;
  final int page;
  final String quote;
  final bool embedded;
  final VoidCallback onClose;

  @override
  State<PdfPageView> createState() => _PdfPageViewState();
}

class _PdfPageViewState extends State<PdfPageView> {
  late final Future<Uint8List?> _bytes = LocalPdfs.fetch(widget.documentId);

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Column(
      children: [
        PaneHeader(
          embedded: widget.embedded,
          onBack: widget.onClose,
          onClose: widget.onClose,
          title: Text('${widget.title} · ${l.pageN(widget.page)}'),
        ),
        Expanded(
          child: FutureBuilder<Uint8List?>(
            future: _bytes,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final bytes = snapshot.data;
              if (bytes == null) return QuoteView(widget.quote);
              return Column(
                children: [
                  if (widget.quote.isNotEmpty) QuoteBanner(widget.quote),
                  Expanded(
                    child: PdfViewer(
                      PdfDocumentRefData(
                        bytes,
                        sourceName: 'doc-${widget.documentId}',
                      ),
                      initialPageNumber: widget.page,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class QuoteBanner extends StatelessWidget {
  const QuoteBanner(this.quote, {super.key});
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

/// Shown when the original PDF (or cited note) isn't available.
class QuoteView extends StatelessWidget {
  const QuoteView(this.quote, {super.key});
  final String quote;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text(
        context.l.originalMissing,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      if (quote.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('“$quote”', style: Theme.of(context).textTheme.bodyLarge),
      ],
    ],
  );
}
