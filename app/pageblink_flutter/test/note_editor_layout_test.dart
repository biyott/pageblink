import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_flutter/app/app_icons.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/features/notes/note_editor_screen.dart';

/// Toolbar vs body: above on desktops at any width, above on wide touch
/// windows, below (keyboard bar) only on narrow touch devices.
Future<bool> _toolbarAboveBody(
  WidgetTester t, {
  required double width,
  required TargetPlatform platform,
}) async {
  t.view.physicalSize = Size(width, 900);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: buildPbTheme(Brightness.light).copyWith(platform: platform),
      home: Scaffold(body: NoteEditorView(embedded: true, onClose: () {})),
    ),
  );
  await t.pump();
  final bar = t.getCenter(find.byIcon(AppIcons.bold)).dy;
  final body = t.getTopLeft(find.byType(TextField).last).dy;
  return bar < body;
}

void main() {
  testWidgets('desktop, wide window: toolbar above body', (t) async {
    expect(
      await _toolbarAboveBody(t, width: 1400, platform: TargetPlatform.macOS),
      isTrue,
    );
  });

  testWidgets('desktop, narrow/zoomed window: toolbar still above body', (
    t,
  ) async {
    expect(
      await _toolbarAboveBody(t, width: 480, platform: TargetPlatform.macOS),
      isTrue,
    );
  });

  testWidgets('phone: toolbar below body (above the keyboard)', (t) async {
    expect(
      await _toolbarAboveBody(t, width: 380, platform: TargetPlatform.android),
      isFalse,
    );
  });

  testWidgets('tablet (touch, >=600): toolbar above body', (t) async {
    expect(
      await _toolbarAboveBody(t, width: 900, platform: TargetPlatform.android),
      isTrue,
    );
  });
}
