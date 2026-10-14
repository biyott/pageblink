import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:pageblink_client/pageblink_client.dart';

import '../../app/l10n.dart';
import '../../app/open_item_controller.dart';
import '../../app/pane_header.dart';
import '../../client.dart';

/// Keep-style note editor: title + Markdown body, a small formatting toolbar
/// and a preview toggle. Saves (and re-indexes for questions) on close.
///
/// Embedded in the center pane ([embedded]) it has a "← Notes / title"
/// header with a close button; otherwise it is a full page with a back arrow.
class NoteEditorView extends StatefulWidget {
  const NoteEditorView({
    super.key,
    this.note,
    this.projectId,
    this.highlight,
    required this.embedded,
    required this.onClose,
    this.controller,
  });

  final Document? note;
  final int? projectId;

  /// A cited passage to show above the note (opened from an answer).
  final String? highlight;

  final bool embedded;

  /// Called after the pending edits were saved (or there was nothing to save).
  final VoidCallback onClose;

  /// Lets the shell save this editor before it is replaced or closed.
  final OpenItemController? controller;

  @override
  State<NoteEditorView> createState() => _NoteEditorViewState();
}

class _NoteEditorViewState extends State<NoteEditorView> {
  late final _title = TextEditingController(text: widget.note?.title ?? '');
  late final _body = TextEditingController(text: widget.note?.body ?? '');
  late bool _preview = widget.note != null;
  late int? _id = widget.note?.id;
  late String _savedTitle = widget.note?.title ?? '';
  late String _savedBody = widget.note?.body ?? '';
  bool _saving = false;

  bool get _changed => _title.text != _savedTitle || _body.text != _savedBody;

  @override
  void initState() {
    super.initState();
    widget.controller?.flushHandler = _flush;
  }

  @override
  void dispose() {
    final c = widget.controller;
    if (c != null && c.flushHandler == _flush) c.flushHandler = null;
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  /// Saves pending edits. False (with a snackbar) if saving failed.
  Future<bool> _flush() async {
    if (_saving) return false;
    if (!_changed || _body.text.trim().isEmpty) return true;
    final l = context.l;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final saved = await client.document.saveNote(
        _id,
        _title.text,
        _body.text,
        widget.note?.projectId ?? widget.projectId,
      );
      _id = saved.id;
      _savedTitle = _title.text;
      _savedBody = _body.text;
      boardRefresh.value++;
      if (mounted) setState(() => _saving = false);
      return true;
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l.saveFailed(e))));
      return false;
    }
  }

  Future<void> _saveAndClose() async {
    if (await _flush() && mounted) widget.onClose();
  }

  /// Wraps the selection (or inserts at the cursor) with Markdown syntax.
  void _wrap(String before, [String after = '']) {
    final sel = _body.selection;
    final text = _body.text;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final selected = text.substring(start, end);
    _body.value = TextEditingValue(
      text: text.replaceRange(start, end, '$before$selected$after'),
      selection: TextSelection.collapsed(
        offset: start + before.length + selected.length,
      ),
    );
    setState(() => _preview = false);
  }

  /// Prefixes the current line (heading, list, checkbox).
  void _linePrefix(String prefix) {
    final text = _body.text;
    final cursor = _body.selection.isValid
        ? _body.selection.start
        : text.length;
    final lineStart = text.lastIndexOf('\n', cursor > 0 ? cursor - 1 : 0) + 1;
    _body.value = TextEditingValue(
      text: text.replaceRange(lineStart, lineStart, prefix),
      selection: TextSelection.collapsed(offset: cursor + prefix.length),
    );
    setState(() => _preview = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return PopScope(
      // Embedded: back is handled by the shell. Full page: save first.
      canPop: widget.embedded,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _saveAndClose();
      },
      child: Column(
        children: [
          PaneHeader(
            embedded: widget.embedded,
            onBack: _saveAndClose,
            onClose: _saveAndClose,
            title: ValueListenableBuilder(
              valueListenable: _title,
              builder: (context, value, _) => Text(
                value.text.trim().isNotEmpty
                    ? value.text.trim()
                    : (widget.note == null ? l.newNote : l.titleHint),
              ),
            ),
            actions: [
              IconButton(
                tooltip: _preview ? l.edit : l.preview,
                icon: Icon(
                  _preview ? Icons.edit_outlined : Icons.visibility_outlined,
                ),
                onPressed: () => setState(() => _preview = !_preview),
              ),
              if (_saving)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  tooltip: l.save,
                  icon: const Icon(Icons.check),
                  onPressed: _saveAndClose,
                ),
            ],
          ),
          if (widget.highlight != null)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.secondaryContainer,
              padding: const EdgeInsets.all(12),
              child: Text(
                '⚡ “${widget.highlight}”',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _title,
              style: Theme.of(context).textTheme.titleLarge,
              decoration: InputDecoration(
                hintText: context.l.titleHint,
                border: InputBorder.none,
              ),
            ),
          ),
          Expanded(
            child: _preview
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: GptMarkdown(_body.text),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _body,
                      autofocus: widget.note == null,
                      maxLines: null,
                      expands: true,
                      keyboardType: TextInputType.multiline,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: InputDecoration(
                        hintText: context.l.noteHint,
                        border: InputBorder.none,
                      ),
                    ),
                  ),
          ),
          if (!_preview)
            SafeArea(
              top: false,
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainer,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: context.l.fmtHeading,
                        icon: const Icon(Icons.title),
                        onPressed: () => _linePrefix('## '),
                      ),
                      IconButton(
                        tooltip: context.l.fmtBold,
                        icon: const Icon(Icons.format_bold),
                        onPressed: () => _wrap('**', '**'),
                      ),
                      IconButton(
                        tooltip: context.l.fmtItalic,
                        icon: const Icon(Icons.format_italic),
                        onPressed: () => _wrap('_', '_'),
                      ),
                      IconButton(
                        tooltip: context.l.fmtList,
                        icon: const Icon(Icons.format_list_bulleted),
                        onPressed: () => _linePrefix('- '),
                      ),
                      IconButton(
                        tooltip: context.l.fmtCheckbox,
                        icon: const Icon(Icons.check_box_outlined),
                        onPressed: () => _linePrefix('- [ ] '),
                      ),
                      IconButton(
                        tooltip: context.l.fmtQuote,
                        icon: const Icon(Icons.format_quote),
                        onPressed: () => _linePrefix('> '),
                      ),
                      IconButton(
                        tooltip: context.l.fmtCode,
                        icon: const Icon(Icons.code),
                        onPressed: () => _wrap('`', '`'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
