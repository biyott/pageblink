import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/app/app_icons.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/features/documents/documents_screen.dart';

Document _doc(String status) => Document(
  id: 1,
  ownerId: UuidValue.fromString('00000000-0000-4000-8000-000000000001'),
  kind: 'note',
  title: 'Groceries',
  body: 'milk',
  contentHash: 'h',
  version: 1,
  pageCount: 1,
  status: status,
  lastError: status == 'failed' ? 'boom' : null,
  embeddingModel: 'm',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Future<void> _pump(
  WidgetTester t,
  String status, {
  VoidCallback? onTap,
  VoidCallback? onLongPress,
  VoidCallback? onRetry,
  VoidCallback? onReindex,
  VoidCallback? onDelete,
}) => t.pumpWidget(
  MaterialApp(
    theme: buildPbTheme(Brightness.light),
    // The indexing dot pulses forever; pumpAndSettle needs it still.
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 280,
          height: 250,
          child: DocumentCard(
            _doc(status),
            const [],
            onTap: onTap,
            onLongPress: onLongPress,
            onRetry: onRetry,
            onReindex: onReindex,
            onDelete: onDelete,
          ),
        ),
      ),
    ),
  ),
);

Future<void> _openMenu(WidgetTester t) async {
  await t.tap(find.byIcon(AppIcons.more));
  await t.pumpAndSettle();
}

void main() {
  for (final status in ['ready', 'indexing']) {
    testWidgets('$status: menu offers re-index and calls it', (t) async {
      var reindexed = 0;
      var opened = 0;
      await _pump(
        t,
        status,
        onTap: () => opened++,
        onReindex: () => reindexed++,
      );
      await _openMenu(t);
      expect(find.text('Re-index'), findsOneWidget);
      await t.tap(find.text('Re-index'));
      await t.pumpAndSettle();
      expect(reindexed, 1);
      expect(opened, 0, reason: 'menu must not open the card');
    });
  }

  testWidgets('failed: retry button and menu both work', (t) async {
    var retried = 0;
    var reindexed = 0;
    await _pump(
      t,
      'failed',
      onRetry: () => retried++,
      onReindex: () => reindexed++,
    );
    expect(find.byType(OutlinedButton), findsNothing);
    await t.tap(find.widgetWithText(TextButton, 'Retry'));
    expect(retried, 1);
    await _openMenu(t);
    await t.tap(find.text('Re-index').last);
    await t.pumpAndSettle();
    expect(reindexed, 1);
  });

  testWidgets('long press still deletes; menu delete too', (t) async {
    var longPressed = 0;
    var deleted = 0;
    await _pump(
      t,
      'ready',
      onLongPress: () => longPressed++,
      onDelete: () => deleted++,
    );
    await t.longPress(find.text('Groceries'));
    expect(longPressed, 1);
    await _openMenu(t);
    await t.tap(find.text('Delete'));
    await t.pumpAndSettle();
    expect(deleted, 1);
  });

  testWidgets('re-indexing card: status says so, no link, menu disabled', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        theme: buildPbTheme(Brightness.light),
        home: Scaffold(
          body: SizedBox(
            width: 280,
            height: 250,
            child: DocumentCard(
              _doc('failed'),
              const [],
              reindexing: true,
              onRetry: () {},
              onReindex: null,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Re-indexing'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Retry'), findsNothing);
    await t.tap(find.byIcon(AppIcons.more));
    await t.pump(const Duration(milliseconds: 300));
    final item = t.widget<PopupMenuItem<dynamic>>(
      find.ancestor(
        of: find.text('Re-index'),
        matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
      ),
    );
    expect(item.enabled, isFalse);
  });

  testWidgets('busy (no onReindex): menu item is disabled', (t) async {
    await _pump(t, 'ready', onReindex: null);
    await _openMenu(t);
    final item = t.widget<PopupMenuItem<dynamic>>(
      find.ancestor(
        of: find.text('Re-index'),
        matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
      ),
    );
    expect(item.enabled, isFalse);
  });
}
