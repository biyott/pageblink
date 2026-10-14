import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user's language choice. `null` follows the system (Korean if the
/// device/browser prefers Korean, English otherwise); otherwise a fixed locale.
class LocaleController extends ValueNotifier<Locale?> {
  LocaleController() : super(null);

  static const _key = 'pageblink.locale';

  /// Restores the saved choice. Safe to call before `runApp`.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_key);
      value = (code == 'en' || code == 'ko') ? Locale(code!) : null;
    } catch (_) {
      // Unreadable storage: keep following the system.
    }
  }

  Future<void> choose(Locale? locale) async {
    value = locale;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (locale == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, locale.languageCode);
      }
    } catch (_) {
      // The choice still applies for this session.
    }
  }
}

final localeController = LocaleController();
