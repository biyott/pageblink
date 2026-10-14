import 'package:flutter/widgets.dart';
import 'package:pageblink_client/pageblink_client.dart';

/// Bumped whenever a note was saved, so the board refreshes itself.
final boardRefresh = ValueNotifier<int>(0);

/// Something opened in the layout: a note (new, existing, or cited) or a PDF
/// page. Each instance is its own widget key, so re-opening starts fresh.
class OpenItem {
  /// A note to edit ([note] null = a new note in [projectId]'s tier).
  OpenItem.note({this.note, this.projectId, this.highlight}) : citation = null;

  /// An Ask citation: a cited note (with quote banner) or a PDF page.
  OpenItem.citation(Citation this.citation)
    : note = null,
      projectId = null,
      highlight = null;

  final Document? note;
  final int? projectId;
  final String? highlight;
  final Citation? citation;

  bool get isNote => citation == null || citation!.kind == 'note';
}

/// Holds the item open in the center pane (wide layouts) and the hook that
/// saves a note being edited before it is replaced or closed.
class OpenItemController extends ChangeNotifier {
  OpenItem? _item;
  OpenItem? get item => _item;

  /// True for tablet/desktop: items open in the center pane.
  bool wide = false;

  /// Set by the shell on phones: opens a note in the Notes tab's navigator.
  Future<void> Function(OpenItem item)? openInNotesTab;

  /// Registered by the live note editor: saves pending edits, false on failure.
  Future<bool> Function()? flushHandler;

  /// Saves pending edits in the open editor. False if saving failed.
  Future<bool> flush() async => await flushHandler?.call() ?? true;

  /// Opens [next] in the center pane, replacing (and saving) the current one.
  Future<void> open(OpenItem next) async {
    if (!await flush()) return;
    _item = next;
    notifyListeners();
  }

  /// Saves and closes the pane.
  Future<void> close() async {
    if (_item == null) return;
    if (!await flush()) return;
    _item = null;
    notifyListeners();
  }
}

class OpenItemScope extends InheritedNotifier<OpenItemController> {
  const OpenItemScope({
    super.key,
    required OpenItemController controller,
    required super.child,
  }) : super(notifier: controller);

  static OpenItemController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<OpenItemScope>()?.notifier;
}
