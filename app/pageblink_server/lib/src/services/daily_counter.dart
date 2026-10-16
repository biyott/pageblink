/// Counts uses per KST day (resets at 00:00 KST). In memory only: a restart
/// or a second instance starts from zero again, so the real daily total can
/// exceed [limit] (plan 014 L5). Needs a DB counter if that ever matters.
/// Also the paid-LLM fallback cap, with the same limits.
class DailyCounter {
  final int limit;
  final DateTime Function() _now;
  String _day = '';
  int _used = 0;

  DailyCounter(this.limit, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  void _roll() {
    final kst = _now().toUtc().add(const Duration(hours: 9));
    final day = '${kst.year}-${kst.month}-${kst.day}';
    if (day != _day) {
      _day = day;
      _used = 0;
    }
  }

  int get used {
    _roll();
    return _used;
  }

  int get remaining => (limit - used).clamp(0, limit);

  /// Takes one use; false when the day's limit is already reached.
  bool tryConsume() {
    _roll();
    if (_used >= limit) return false;
    _used++;
    return true;
  }
}
