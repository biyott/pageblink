import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A random per-browser key. The shared demo accounts use it to keep one
/// visitor's Ask conversations apart from another's (the server stores only
/// its hash). Other accounts send it too and the server ignores it.
const _prefsKey = 'pb.visitorKey';
final _valid = RegExp(r'^[A-Za-z0-9_-]{16,64}$');

/// Where the key (and the notice flag) are saved; tests make it throw.
Future<SharedPreferences> Function() prefsLoader =
    SharedPreferences.getInstance;

String? _memory;

/// Tests only: forget the key held in memory.
@visibleForTesting
void resetVisitorKey() => _memory = null;

String _generate() {
  final r = Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

/// The saved key, made on first use. When storage is blocked (private mode)
/// the key lives in memory for the page: a reload then starts a new
/// conversation list, but never mixes with another visitor's.
Future<String> visitorKey() async {
  final held = _memory;
  if (held != null) return held;
  String key;
  try {
    final prefs = await prefsLoader();
    final saved = prefs.getString(_prefsKey);
    if (saved != null && _valid.hasMatch(saved)) return _memory = saved;
    key = _generate();
    await prefs.setString(_prefsKey, key);
  } catch (_) {
    return _memory ??= _generate();
  }
  return _memory = key;
}
