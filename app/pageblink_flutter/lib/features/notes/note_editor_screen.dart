import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:pageblink_client/pageblink_client.dart';

import '../../app/l10n.dart';
import '../../client.dart';

/// Keep-style note editor: title + Markdown body, a small formatting toolbar
/// and a preview toggle. Saves (and re-indexes for questions) on close.
class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({
    super.key,
    this.note,
    this.projectId,
    this.highlight,
  });

  final Document? note;
  final int? projectId;

  /// A cited passage to show above the note (opened from an answer).
  final String? highlight;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final _title = TextEditingController(text: widget.note?.title ?? '');
  late final _body = TextEditingController(text: widget.note?.body ?? '');
  late bool _preview = widget.note != null;
  bool _saving = false;

  bool get _changed =>
      _title.text != (widget.note?.title ?? '') ||
      _body.text != (widget.note?.body ?? '');

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _saveAndClose() async {
    if (_saving) return;
    if (!_changed || _body.text.trim().isEmpty) {
      Navigator.pop(context);
      return;
    }
    final l = context.l;
    setState(() => _saving = true);
    try {
      final saved = await client.document.saveNote(
        widget.note?.id,
        _title.text,
        _body.text,
        widget.note?.projectId ?? widget.projectId,
      );
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.saveFailed(e))));
      }
    }
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _saveAndClose();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _saveAndClose,
          ),
          actions: [
            IconButton(
              tooltip: _preview ? context.l.edit : context.l.preview,
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
                tooltip: context.l.save,
                icon: const Icon(Icons.check),
                onPressed: _saveAndClose,
              ),
          ],
        ),
        body: Column(
          children: [
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
      ),
    );
  }
}
