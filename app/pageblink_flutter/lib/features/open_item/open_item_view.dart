import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pageblink_client/pageblink_client.dart';

import '../../app/open_item_controller.dart';
import '../../app/pane_header.dart';
import '../../app/theme.dart';
import '../../client.dart';
import '../notes/note_editor_screen.dart';
import '../viewer/page_viewer_screen.dart';

/// Opens [item] in the layout. Tablet/desktop: in the center pane, with the
/// sidebar and Ask panel still visible. Phones: pushed on the current tab's
/// navigator, so the bottom bar stays — except cited notes, which open in the
/// Notes tab when [inNotesTab] is set.
Future<void> openItem(
  BuildContext context,
  OpenItem item, {
  bool inNotesTab = false,
}) async {
  final controller = OpenItemScope.maybeOf(context);
  if (controller != null && controller.wide) return controller.open(item);
  if (inNotesTab && item.isNote && controller?.openInNotesTab != null) {
    return controller!.openInNotesTab!(item);
  }
  await Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => OpenItemPage(item: item)));
}

/// The content of an opened item: note editor, cited note, or PDF page.
class OpenItemView extends StatelessWidget {
  const OpenItemView({
    super.key,
    required this.item,
    required this.embedded,
    required this.onClose,
    this.controller,
  });

  final OpenItem item;
  final bool embedded;
  final VoidCallback onClose;
  final OpenItemController? controller;

  @override
  Widget build(BuildContext context) {
    final c = item.citation;
    if (c == null) {
      return NoteEditorView(
        note: item.note,
        projectId: item.projectId,
        highlight: item.highlight,
        embedded: embedded,
        onClose: onClose,
        controller: controller,
      );
    }
    if (c.kind == 'note') {
      return _CitedNote(
        citation: c,
        embedded: embedded,
        onClose: onClose,
        controller: controller,
      );
    }
    return PdfPageView(
      documentId: c.documentId,
      title: c.documentTitle,
      page: c.page,
      quote: c.quote,
      embedded: embedded,
      onClose: onClose,
    );
  }
}

/// A cited note opens in the editor with the cited passage on top.
class _CitedNote extends StatefulWidget {
  const _CitedNote({
    required this.citation,
    required this.embedded,
    required this.onClose,
    required this.controller,
  });

  final Citation citation;
  final bool embedded;
  final VoidCallback onClose;
  final OpenItemController? controller;

  @override
  State<_CitedNote> createState() => _CitedNoteState();
}

class _CitedNoteState extends State<_CitedNote> {
  late final Future<Document?> _note = client.document
      .get(widget.citation.documentId)
      .then<Document?>((d) => d)
      .catchError((_) => null as Document?);

  @override
  Widget build(BuildContext context) => FutureBuilder<Document?>(
    future: _note,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      final note = snapshot.data;
      if (note == null) {
        return Column(
          children: [
            PaneHeader(
              embedded: widget.embedded,
              onBack: widget.onClose,
              onClose: widget.onClose,
              title: Text(widget.citation.documentTitle),
            ),
            Expanded(child: QuoteView(widget.citation.quote)),
          ],
        );
      }
      return NoteEditorView(
        note: note,
        highlight: widget.citation.quote,
        embedded: widget.embedded,
        onClose: widget.onClose,
        controller: widget.controller,
      );
    },
  );
}

/// Full-page route used on phones (inside the active tab's navigator).
class OpenItemPage extends StatelessWidget {
  const OpenItemPage({super.key, required this.item});

  final OpenItem item;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: OpenItemView(
        item: item,
        embedded: false,
        controller: OpenItemScope.maybeOf(context),
        onClose: () => Navigator.of(context).pop(),
      ),
    ),
  );
}

/// The center pane on tablet/desktop: glass surface, Esc closes.
class OpenItemPane extends StatelessWidget {
  const OpenItemPane({
    super.key,
    required this.item,
    required this.controller,
  });

  final OpenItem item;
  final OpenItemController controller;

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): controller.close,
    },
    child: Focus(
      autofocus: true,
      child: GlassPanel(
        strong: true,
        child: Material(
          type: MaterialType.transparency,
          child: OpenItemView(
            item: item,
            embedded: true,
            controller: controller,
            onClose: controller.close,
          ),
        ),
      ),
    ),
  );
}
