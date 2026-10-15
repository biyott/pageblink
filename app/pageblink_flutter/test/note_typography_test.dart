import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_flutter/features/notes/note_editor_screen.dart';

void main() {
  test('noteSizes follows the 018 table by breakpoint', () {
    expect(noteSizes(375), (
      title: 24,
      bodyHeight: 1.65,
      h1: 22,
      h2: 19,
      h3: 17,
    ));
    expect(noteSizes(599).title, 24);
    expect(noteSizes(600), (
      title: 26,
      bodyHeight: 1.7,
      h1: 24,
      h2: 20,
      h3: 18,
    ));
    expect(noteSizes(1023).title, 26);
    expect(noteSizes(1024), (
      title: 28,
      bodyHeight: 1.7,
      h1: 24,
      h2: 20,
      h3: 18,
    ));
    expect(noteSizes(1920).title, 28);
  });
}
