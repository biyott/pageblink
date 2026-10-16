import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../app/l10n.dart';
import '../../app/local_pdfs.dart';
import '../../app/pane_header.dart';
import '../../app/theme.dart';
import 'cite_bar.dart';
import 'pdf_cite.dart';

/// Blink: shows the cited PDF right at the cited page, with the cited passage
/// painted on the page (a rounded fill with a thin bar under each line) and
/// scrolled to the middle of the view. When the passage cannot be found in the
/// page text, the page opens as before with the quote in a banner.
/// Falls back to the quoted passage when the original isn't available.
class PdfPageView extends StatefulWidget {
  const PdfPageView({
    super.key,
    required this.documentId,
    required this.title,
    required this.page,
    required this.quote,
    this.number,
    this.related = const [],
    required this.embedded,
    required this.onClose,
  });

  final int documentId;
  final String title;
  final int page;
  final String quote;

  /// The citation number (`⚡n` on the bar).
  final int? number;

  /// Citations of the same document in the same answer: the bar steps through
  /// them (to another page too).
  final List<Citation> related;
  final bool embedded;
  final VoidCallback onClose;

  @override
  State<PdfPageView> createState() => _PdfPageViewState();
}

class _PdfPageViewState extends State<PdfPageView> {
  late final Future<Uint8List?> _bytes = LocalPdfs.fetch(widget.documentId);
  final _controller = PdfViewerController();
  late final _params = PdfViewerParams(
    onViewerReady: (_, _) {
      _ready = true;
      _locate();
    },
    pagePaintCallbacks: [_paintCite],
  );
  PdfDocumentRef? _ref;

  /// The citations the bar steps through (this one included) and the current.
  late final List<({int? number, int page, String quote})> _cites = _list();
  late int _at = _cites.indexWhere(
    (c) => c.page == widget.page && c.quote == widget.quote,
  );

  bool _ready = false;
  bool _on = true; // highlight not dismissed
  bool? _found; // null: not looked up yet
  List<PdfRect>? _lines; // PDF page coordinates, on [_linesPage]
  int _linesPage = 0;
  int _token = 0; // drops a locate that a newer one overtook

  Color _fill = Colors.transparent, _edge = Colors.transparent;

  List<({int? number, int page, String quote})> _list() {
    final out = [
      for (final c in widget.related)
        if (c.quote.trim().isNotEmpty)
          (number: c.index as int?, page: c.page, quote: c.quote),
    ]..sort((a, b) => (a.number ?? 0).compareTo(b.number ?? 0));
    if (widget.quote.trim().isEmpty) return const [];
    if (!out.any(
      (c) => c.page == widget.page && c.quote == widget.quote,
    )) {
      out.add((number: widget.number, page: widget.page, quote: widget.quote));
    }
    return out;
  }

  ({int? number, int page, String quote})? get _cur =>
      _at >= 0 && _at < _cites.length ? _cites[_at] : null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pb = context.pb;
    if (_fill != pb.citePdfFill || _edge != pb.citePdfEdge) {
      _fill = pb.citePdfFill;
      _edge = pb.citePdfEdge;
      if (_ready) _controller.invalidate();
    }
  }

  /// Finds the current citation in its page's text and brings it into view.
  /// Nothing is found / loaded: no highlight, the banner shows the quote.
  Future<void> _locate() async {
    final cite = _cur;
    final token = ++_token;
    if (cite == null || !_on || !_ready) return;
    List<PdfRect>? lines;
    PdfPage? page;
    try {
      final doc = _controller.document;
      if (cite.page < 1 || cite.page > doc.pages.length) return;
      page = doc.pages[cite.page - 1];
      final text = await page.loadStructuredText();
      lines = pdfCiteLines(text.fullText, text.charRects, cite.quote);
    } catch (e) {
      debugPrint('cite locate failed: $e');
    }
    if (!mounted || token != _token) return;
    setState(() {
      _lines = lines;
      _found = lines != null;
      _linesPage = cite.page;
    });
    _controller.invalidate();
    if (lines == null || page == null) return;
    final box = pdfLinesBounds(lines)!;
    final area = _controller.calcRectForRectInsidePage(
      pageNumber: cite.page,
      rect: box,
    );
    final whole = _controller.calcRectForRectInsidePage(
      pageNumber: cite.page,
      rect: PdfRect(0, page.height, page.width, 0),
    );
    final view = _controller.viewSize, zoom = _controller.currentZoom;
    // Centered; top-aligned (with some air) when it does not fit the view.
    final dy = area.height * zoom > view.height * 0.8
        ? area.top + (view.height / 2 - 32) / zoom
        : area.center.dy;
    final reduced = MediaQuery.disableAnimationsOf(context);
    await _controller.goTo(
      _controller.calcMatrixFor(Offset(whole.center.dx, dy)),
      duration: reduced ? Duration.zero : const Duration(milliseconds: 220),
    );
  }

  /// [PdfViewerParams.pagePaintCallbacks]: the lines of the cited passage as
  /// one filled path (a translucent fill is not doubled where boxes overlap),
  /// plus a bar under each line. Drawn in page-document coordinates, so the bar
  /// is divided by the zoom to stay ~1.5 px on screen.
  void _paintCite(Canvas canvas, Rect pageRect, PdfPage page) {
    final lines = _lines;
    if (!_on || lines == null || page.pageNumber != _linesPage) return;
    final zoom = _controller.isReady ? _controller.currentZoom : 1.0;
    final bar = 1.5 / zoom, padX = 2 / zoom, padY = 2.5 / zoom;
    final path = Path();
    final bars = <Rect>[];
    for (final l in lines) {
      final box = l
          .toRect(page: page, scaledPageSize: pageRect.size)
          .translate(pageRect.left, pageRect.top);
      final r = Rect.fromLTRB(
        box.left - padX,
        box.top - padY,
        box.right + padX,
        box.bottom + padY,
      );
      path.addRRect(RRect.fromRectAndRadius(r, Radius.circular(3 / zoom)));
      bars.add(Rect.fromLTRB(r.left, r.bottom - bar, r.right, r.bottom));
    }
    canvas.drawPath(path, Paint()..color = _fill);
    final barPaint = Paint()..color = _edge;
    for (final b in bars) {
      canvas.drawRect(b, barPaint);
    }
  }

  void _dismiss() {
    setState(() {
      _on = false;
      _lines = null;
    });
    if (_ready) _controller.invalidate();
  }

  Future<void> _step(int d) async {
    final i = _at + d;
    if (i < 0 || i >= _cites.length) return;
    final to = _cites[i];
    final samePage = to.page == _linesPage;
    setState(() {
      _at = i;
      _lines = null;
      _found = null;
    });
    if (!samePage && _ready) {
      await _controller.goToPage(pageNumber: to.page);
    }
    _locate();
  }

  Widget _bar() {
    final cite = _cur;
    if (cite == null || !_on) return const SizedBox(width: double.infinity);
    // Not found in the page text: the quote itself in a banner, as before.
    return _found != false
        ? CiteBar(
            number: cite.number == null || cite.number == 0
                ? null
                : cite.number,
            position: _at + 1,
            count: _cites.length,
            onPrevious: _at > 0 ? () => _step(-1) : null,
            onNext: _at < _cites.length - 1 ? () => _step(1) : null,
            onDismiss: _dismiss,
          )
        : QuoteBanner(cite.quote);
  }

  @override
  void dispose() {
    _token++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Column(
      children: [
        PaneHeader(
          embedded: widget.embedded,
          onBack: widget.onClose,
          onClose: widget.onClose,
          title: Text(
            '${widget.title} · ${l.pageN(_cur?.page ?? widget.page)}',
          ),
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
              final ref = _ref ??= PdfDocumentRefData(
                bytes,
                sourceName: 'doc-${widget.documentId}',
              );
              return Column(
                children: [
                  _fold(
                    reduced: reduced,
                    child: SizedBox(
                      width: double.infinity,
                      child: _bar(),
                    ),
                  ),
                  Expanded(
                    child: PdfViewer(
                      ref,
                      controller: _controller,
                      initialPageNumber: widget.page,
                      params: _params,
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

/// Folds [child]'s height when it changes (not at all when motion is reduced:
/// `AnimatedSize` with a zero duration asserts in layout).
Widget _fold({required bool reduced, required Widget child}) => reduced
    ? child
    : AnimatedSize(
        duration: const Duration(milliseconds: 160),
        alignment: Alignment.topCenter,
        child: child,
      );

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
