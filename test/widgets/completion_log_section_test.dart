// Tests for the WF-025 "edit completion log" section.
//
// The section renders the most-recent N completions for a
// habit as a list with a delete (undo) action per row. The
// tests pin:
//   1. Empty log renders an empty-state copy.
//   2. Non-empty log renders each row with a delete icon.
//   3. Tapping the delete icon opens a confirm dialog.
//   4. Cancel keeps the row.
//   5. Confirm deletes the row and shows a "Completion
//      removed." snackbar.

import 'package:doit/services/completion_log_service.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart' show AppDatabase;
import 'package:doit/widgets/completion_log_section.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _habitId = 'h_existing';

Future<void> _seed(WidgetTester tester) async {
  await AppDatabaseService.instance.closeForTesting();
  await AppDatabaseService.instance.init(
    overrideDb: AppDatabase(NativeDatabase.memory()),
  );
  addTearDown(AppDatabaseService.instance.closeForTesting);
  CompletionLogService.instance;
}

Future<String> _append({
  required DateTime day,
  String source = 'manual',
}) async {
  return CompletionLogService.instance.append(
    habitId: _habitId,
    day: day,
    source: _switchSource(source),
    proofModeAtTime: 'soft',
  );
}

CompletionSource _switchSource(String s) {
  return switch (s) {
    'manual' => CompletionSource.manual,
    'notification' => CompletionSource.notification,
    'mission' => CompletionSource.mission,
    'rest_day' => CompletionSource.restDay,
    _ => CompletionSource.manual,
  };
}

Widget _host() => const MaterialApp(
  home: Scaffold(body: CompletionLogSection(habitId: _habitId)),
);

void main() {
  testWidgets('renders empty-state copy when the log is empty', (tester) async {
    await _seed(tester);
    await tester.pumpWidget(_host());
    await tester.pump();
    expect(
      find.byKey(const ValueKey('completion_log.section')),
      findsOneWidget,
    );
    expect(find.text('No completions yet.'), findsOneWidget);
  });

  testWidgets('renders a delete icon for each row, newest-first', (
    tester,
  ) async {
    await _seed(tester);
    // Seed in non-chronological order; expect newest-first.
    final idA = await _append(day: DateTime(2026, 6, 10));
    final idB = await _append(day: DateTime(2026, 6, 20));
    final idC = await _append(day: DateTime(2026, 6, 15));
    await tester.pumpWidget(_host());
    await tester.pump();
    expect(find.byKey(ValueKey('completion_log.delete.$idA')), findsOneWidget);
    expect(find.byKey(ValueKey('completion_log.delete.$idB')), findsOneWidget);
    expect(find.byKey(ValueKey('completion_log.delete.$idC')), findsOneWidget);
    // Newest-first means idB (2026-06-20) appears before
    // idA (2026-06-10) in the widget tree.
    final bPos = tester.getTopLeft(
      find.byKey(ValueKey('completion_log.delete.$idB')),
    );
    final aPos = tester.getTopLeft(
      find.byKey(ValueKey('completion_log.delete.$idA')),
    );
    expect(bPos.dy, lessThan(aPos.dy));
  });

  testWidgets('tapping delete opens a confirm dialog', (tester) async {
    await _seed(tester);
    final id = await _append(day: DateTime(2026, 6, 10));
    await tester.pumpWidget(_host());
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('completion_log.delete.$id')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const ValueKey('completion_log.delete.confirm')),
      findsOneWidget,
    );
    expect(find.text('Delete this completion?'), findsOneWidget);
  });

  testWidgets('Cancel keeps the row intact', (tester) async {
    await _seed(tester);
    final id = await _append(day: DateTime(2026, 6, 10));
    await tester.pumpWidget(_host());
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('completion_log.delete.$id')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(
      find.byKey(const ValueKey('completion_log.delete.cancel')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final rows = await CompletionLogService.instance.listForHabit(_habitId);
    expect(rows.length, 1);
    expect(rows.first.id, id);
  });

  testWidgets('Confirm deletes the row and shows a confirmation snackbar', (
    tester,
  ) async {
    await _seed(tester);
    final idKeep = await _append(day: DateTime(2026, 6, 10));
    final idDelete = await _append(day: DateTime(2026, 6, 15));
    await tester.pumpWidget(_host());
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('completion_log.delete.$idDelete')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(
      find.byKey(const ValueKey('completion_log.delete.confirm_button')),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    final rows = await CompletionLogService.instance.listForHabit(_habitId);
    expect(rows.length, 1);
    expect(rows.first.id, idKeep);
    expect(find.text('Completion removed.'), findsOneWidget);
  });
}
