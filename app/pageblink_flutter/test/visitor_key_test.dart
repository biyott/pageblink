import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_flutter/app/visitor_key.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final shape = RegExp(r'^[A-Za-z0-9_-]{22}$');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    resetVisitorKey();
  });
  tearDown(() => prefsLoader = SharedPreferences.getInstance);

  test('made once, saved, and read back after a reload', () async {
    final a = await visitorKey();
    expect(a, matches(shape));
    expect(await visitorKey(), a);
    expect(
      (await SharedPreferences.getInstance()).getString('pb.visitorKey'),
      a,
    );
    resetVisitorKey(); // a page reload
    expect(await visitorKey(), a);
  });

  test('a malformed saved value is replaced', () async {
    SharedPreferences.setMockInitialValues({'pb.visitorKey': 'short'});
    expect(await visitorKey(), matches(shape));
  });

  test('blocked storage: a key in memory for the page only', () async {
    prefsLoader = () async => throw Exception('storage blocked');
    final a = await visitorKey();
    expect(a, matches(shape));
    expect(await visitorKey(), a);
    resetVisitorKey(); // a reload loses it, but it never collides
    expect(await visitorKey(), isNot(a));
  });

  test('storage that reads but cannot write still gives one key', () async {
    SharedPreferences.setMockInitialValues({});
    final real = await SharedPreferences.getInstance();
    prefsLoader = () async => _ReadOnly(real);
    final a = await visitorKey();
    expect(a, matches(shape));
    expect(await visitorKey(), a);
  });
}

class _ReadOnly implements SharedPreferences {
  _ReadOnly(this._p);
  final SharedPreferences _p;
  @override
  String? getString(String key) => _p.getString(key);
  @override
  Future<bool> setString(String key, String value) async =>
      throw Exception('quota');
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
