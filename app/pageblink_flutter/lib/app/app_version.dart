/// Shown at the bottom of Settings. [_versionName] is the pubspec `version`
/// without the build number (change both together). The deploy build adds the
/// git short hash: `--dart-define=APP_BUILD=<hash>` in the `flutter_build`
/// script of `pageblink_server/pubspec.yaml`. Without it (local runs, tests)
/// the line is just the version.
const _versionName = '1.0.0';
const _build = String.fromEnvironment('APP_BUILD');
const appVersion = _build == '' ? _versionName : '$_versionName · $_build';
