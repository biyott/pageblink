import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pageblink_client/pageblink_client.dart';

import '../../app/l10n.dart';
import '../../app/visitor_key.dart';
import '../../client.dart';
import '../demo/demo.dart' show demoLimitText;

/// One question and its streaming (or restored) answer.
class AskTurn {
  AskTurn(this.question);

  /// A stored turn. [failed] is the text for a turn that ended in an error.
  AskTurn.fromMessage(
    AskMessageView m, {
    required String failed,
    String? Function(String? modelId)? labelOf,
  }) : question = m.question,
       seq = m.seq {
    answer.write(m.answer);
    for (final c in m.citations) {
      citations[c.index] = c;
    }
    modelId = m.modelId;
    modelLabel = labelOf?.call(m.modelId) ?? m.modelId;
    done = true;
    switch (m.status) {
      case 'error':
        error = failed;
      case 'interrupted':
        cutOff = true;
      case 'streaming':
        pending = true;
    }
  }

  final String question;
  int? seq;
  final answer = StringBuffer();
  final citations = <int, Citation>{};
  String? modelId;
  String? modelLabel;
  String? error;
  bool done = false;

  /// Restored: the answer stopped part-way (reload or lost connection).
  bool cutOff = false;

  /// Restored while the server was still finishing it.
  bool pending = false;
}

// ── Server calls (tests replace them) ─────────────────────────────────────

/// What `ask.ask` is called with.
typedef AskRequest = ({
  String question,
  List<int> projectIds,
  bool includePersonal,
  String? modelId,
  String locale,
  int? sessionId,
  String? visitorKey,
});

@visibleForTesting
Future<AskHistoryStatus> Function()? historyStatusCall;
@visibleForTesting
Future<AskRestore> Function(String? visitorKey)? askRestoreCall;
@visibleForTesting
Future<AskSessionView?> Function(int sessionId, String? visitorKey)?
askOpenCall;
@visibleForTesting
Future<void> Function(int sessionId, String? visitorKey)? askHideCall;
@visibleForTesting
Stream<AnswerEvent> Function(AskRequest request)? askStreamCall;

Stream<AnswerEvent> _askStream(AskRequest r) {
  final hook = askStreamCall;
  if (hook != null) return hook(r);
  // History off: the very call the app always made.
  if (r.sessionId == null) {
    return client.ask.ask(
      r.question,
      r.projectIds,
      r.includePersonal,
      r.modelId,
      r.locale,
    );
  }
  return client.ask.ask(
    r.question,
    r.projectIds,
    r.includePersonal,
    r.modelId,
    r.locale,
    r.sessionId,
    r.visitorKey,
  );
}

// ── History status (like demoStatus) ──────────────────────────────────────

/// How long to wait for `historyStatus()`; a slow server means "off".
const historyStatusTimeout = Duration(seconds: 8);

/// Null until the shell has asked, and when the call failed: everything new
/// stays hidden then.
final historyStatus = ValueNotifier<AskHistoryStatus?>(null);

Future<AskHistoryStatus?>? _statusLoad;
var _statusEpoch = 0;

/// A new signed-in session starts: forget the previous one's status.
void resetHistoryStatus() {
  _statusEpoch++;
  _statusLoad = null;
  historyStatus.value = null;
}

/// Reads the status once per session (shared by the Ask screen and the
/// settings). Never throws; a failure is kept as "off" until the next reset.
Future<AskHistoryStatus?> ensureHistoryStatus() =>
    _statusLoad ??= _loadStatus();

Future<AskHistoryStatus?> _loadStatus() async {
  final epoch = _statusEpoch;
  try {
    final s = await (historyStatusCall ?? client.askHistory.historyStatus)()
        .timeout(historyStatusTimeout);
    if (epoch == _statusEpoch) historyStatus.value = s;
    return s;
  } catch (e) {
    debugPrint('ask history unavailable: $e');
    return null;
  }
}

// ── The "kept on the server" notice ───────────────────────────────────────

const _noticeKey = 'pb.askNoticeDismissed';
bool _noticeMemory = false;

/// Tests only.
@visibleForTesting
void resetNotice() => _noticeMemory = false;

Future<bool> noticeDismissed() async {
  if (_noticeMemory) return true;
  try {
    final prefs = await prefsLoader();
    return prefs.getBool(_noticeKey) ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> dismissNotice() async {
  _noticeMemory = true;
  try {
    final prefs = await prefsLoader();
    await prefs.setBool(_noticeKey, true);
  } catch (_) {
    // Kept in memory for this page.
  }
}

// ── The conversation ──────────────────────────────────────────────────────

/// A short note under the conversation bar.
enum AskHint { busy, expired, notFound, loadFailed }

/// 0 plain, 1 close to the limit, 2 reached.
typedef AskLevel = int;

/// The Ask conversation: its turns, the server conversation id and counter,
/// and the recent list. With history off it is just the old in-memory list.
class AskChat extends ChangeNotifier {
  final turns = <AskTurn>[];

  /// 0 = the next question starts a conversation.
  int sessionId = 0;
  int? count;
  int? limit;
  List<AskSessionSummary> recent = const [];
  AskHint? hint;

  /// Strings and model names for turns built here; set by the screen.
  L l = L.en;
  String? Function(String? modelId)? labelOf;

  /// A refused question's text goes back to the input box.
  ValueChanged<String>? onGiveBack;

  /// Set when a question moved the counter into a higher [level]; the screen
  /// announces it once and clears it.
  AskLevel? announce;

  StreamSubscription<AnswerEvent>? _sub;
  Timer? _poll;
  var _gen = 0;
  var _disposed = false;

  AskHistoryStatus? get status => historyStatus.value;
  bool get on => status?.enabled ?? false;
  bool get streaming => turns.isNotEmpty && !turns.last.done;
  int? get _limit => limit ?? (on ? status?.questionLimit : null);

  bool get limitReached {
    final n = count, m = _limit;
    return on && n != null && m != null && m > 0 && n >= m;
  }

  AskLevel get level {
    final n = count, m = _limit;
    if (!on || n == null || m == null || m <= 0) return 0;
    if (n >= m) return 2;
    return m - n <= 2 ? 1 : 0;
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _gen++;
    _sub?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  /// Screen opened: learn whether history is on, then restore.
  Future<void> start() async {
    final s = await ensureHistoryStatus();
    if (_disposed || s == null || !s.enabled) {
      notifyListeners();
      return;
    }
    final gen = _gen;
    try {
      final r = await (askRestoreCall ?? client.askHistory.restore)(
        await visitorKey(),
      );
      if (_disposed || gen != _gen) return;
      recent = r.recent;
      if (turns.isEmpty && r.current != null) _apply(r.current!);
    } catch (e) {
      debugPrint('ask restore failed: $e');
      if (!_disposed && gen == _gen) hint = AskHint.loadFailed;
    }
    notifyListeners();
  }

  /// Shows [v] as the conversation.
  void _apply(AskSessionView v, {bool poll = true}) {
    _poll?.cancel();
    sessionId = v.id;
    count = v.questionCount;
    limit = v.questionLimit;
    hint = null;
    turns
      ..clear()
      ..addAll([
        for (final m in v.messages)
          AskTurn.fromMessage(m, failed: l.askFailed, labelOf: labelOf),
      ]);
    if (poll && turns.isNotEmpty && turns.last.pending) _pollOpen(v.id, 1);
  }

  /// The server was still finishing the last answer when we reloaded: read
  /// again every 2 s, five times, then call it cut off.
  void _pollOpen(int id, int attempt) {
    _poll = Timer(const Duration(seconds: 2), () async {
      if (_disposed || sessionId != id) return;
      final gen = _gen;
      try {
        final v = await (askOpenCall ?? client.askHistory.open)(
          id,
          await visitorKey(),
        );
        if (_disposed || gen != _gen) return;
        if (v != null) {
          _apply(v, poll: false);
          if (turns.isEmpty || !turns.last.pending) return notifyListeners();
        }
      } catch (_) {
        // Try again below.
      }
      if (attempt >= 5) {
        if (turns.isNotEmpty) {
          turns.last
            ..pending = false
            ..cutOff = true;
        }
      } else {
        _pollOpen(id, attempt + 1);
      }
      notifyListeners();
    });
  }

  void newChat() {
    _gen++;
    _sub?.cancel();
    _sub = null;
    _poll?.cancel();
    turns.clear();
    sessionId = 0;
    count = null;
    limit = null;
    hint = null;
    notifyListeners();
  }

  /// Re-reads the recent list (the sheet is opening).
  Future<void> refreshRecent() async {
    if (!on) return;
    try {
      final r = await (askRestoreCall ?? client.askHistory.restore)(
        await visitorKey(),
      );
      if (_disposed) return;
      recent = r.recent;
      notifyListeners();
    } catch (e) {
      debugPrint('ask recent failed: $e');
    }
  }

  Future<void> openSession(int id) async {
    final gen = ++_gen;
    _sub?.cancel();
    _sub = null;
    try {
      final v = await (askOpenCall ?? client.askHistory.open)(
        id,
        await visitorKey(),
      );
      if (_disposed || gen != _gen) return;
      if (v == null) {
        hint = AskHint.notFound;
        notifyListeners();
        await refreshRecent();
        return;
      }
      _apply(v);
    } catch (e) {
      debugPrint('ask open failed: $e');
      if (_disposed || gen != _gen) return;
      hint = AskHint.loadFailed;
    }
    notifyListeners();
  }

  /// "Remove from list": the server only hides it.
  Future<void> hideSession(int id) async {
    try {
      await (askHideCall ?? client.askHistory.hide)(id, await visitorKey());
    } catch (e) {
      debugPrint('ask hide failed: $e');
      return;
    }
    recent = [
      for (final s in recent)
        if (s.id != id) s,
    ];
    if (id == sessionId) {
      newChat();
    } else {
      notifyListeners();
    }
  }

  void ask(
    String question, {
    required List<int> projectIds,
    required bool includePersonal,
    required String? modelId,
    required String locale,
  }) {
    hint = null;
    final turn = AskTurn(question);
    turns.add(turn);
    notifyListeners();
    unawaited(
      _send(turn, (
        question: question,
        projectIds: projectIds,
        includePersonal: includePersonal,
        modelId: modelId,
        locale: locale,
        sessionId: null,
        visitorKey: null,
      ), canRetry: true),
    );
  }

  Future<void> _send(
    AskTurn turn,
    AskRequest base, {
    required bool canRetry,
    bool fresh = false,
  }) async {
    final gen = _gen;
    final failed = l.askFailed;
    var request = base;
    if (on) {
      final key = await visitorKey();
      if (_disposed || gen != _gen) return;
      request = (
        question: base.question,
        projectIds: base.projectIds,
        includePersonal: base.includePersonal,
        modelId: base.modelId,
        locale: base.locale,
        sessionId: fresh ? 0 : sessionId,
        visitorKey: key,
      );
    }
    void drop() {
      turns.remove(turn);
      onGiveBack?.call(turn.question);
    }

    _sub = _askStream(request).listen(
      (event) {
        if (gen != _gen) return;
        switch (event.type) {
          case 'session':
            final before = level;
            sessionId = event.sessionId ?? sessionId;
            count = event.questionCount ?? count;
            limit = event.questionLimit ?? limit;
            turn.seq = count;
            if (level > before) announce = level;
          case 'token':
            turn.answer.write(event.text ?? '');
          case 'citation':
            final c = event.citation;
            if (c != null) turn.citations[c.index] = c;
          case 'model':
            // The model that actually answered (may differ after rotation).
            final id = event.text;
            turn.modelId = id;
            turn.modelLabel = labelOf?.call(id) ?? id;
          case 'error':
            turn.error = event.text;
          case 'done':
            turn.done = true;
        }
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('ask failed: $e');
        if (gen != _gen) return;
        if (e is AskLimitException) {
          switch (e.reason) {
            case AskLimitReason.expired:
              if (canRetry && request.sessionId != 0) {
                // Gone or past the window: start over once with the same text.
                turns.clear();
                sessionId = 0;
                count = null;
                limit = null;
                hint = AskHint.expired;
                final again = AskTurn(turn.question);
                turns.add(again);
                notifyListeners();
                unawaited(_send(again, base, canRetry: false, fresh: true));
                return;
              }
              turn
                ..error = failed
                ..done = true;
            case AskLimitReason.busy:
              hint = AskHint.busy;
              drop();
            case AskLimitReason.questionLimit:
              final m = e.limit ?? _limit;
              limit = m;
              count = m;
              drop();
          }
        } else {
          turn
            ..error = e is DemoLimitException ? demoLimitText(l, e) : failed
            ..done = true;
        }
        notifyListeners();
      },
      onDone: () {
        if (gen != _gen) return;
        turn.done = true;
        notifyListeners();
      },
    );
  }
}
