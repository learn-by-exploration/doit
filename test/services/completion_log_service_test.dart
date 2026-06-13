// Tests for [CompletionLogService] — append + dedupe + list.

import 'package:common_games/services/completion_log_service.dart';
import 'package:common_games/services/db.dart';
import 'package:common_games/services/db/schema.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _init() async {
  await AppDatabaseService.instance.closeForTesting();
  await AppDatabaseService.instance.init(
    overrideDb: AppDatabase(NativeDatabase.memory()),
  );
  await AppDatabaseService.instance.ready;
}

Future<void> _tearDown() => AppDatabaseService.instance.closeForTesting();

void main() {
  setUp(_init);
  tearDown(_tearDown);

  group('CompletionLogService', () {
    test('append inserts a new row and returns its id', () async {
      final id = await CompletionLogService.instance.append(
        habitId: 'h1',
        day: DateTime(2026, 6, 5),
        source: CompletionSource.manual,
        proofModeAtTime: 'soft',
      );
      expect(id, isNotEmpty);
      final rows = await CompletionLogService.instance.listForHabit('h1');
      expect(rows.length, 1);
      expect(rows.first.habitId, 'h1');
      expect(rows.first.source, 'manual');
    });

    test('append on the same (habit, day) is idempotent', () async {
      final id1 = await CompletionLogService.instance.append(
        habitId: 'h1',
        day: DateTime(2026, 6, 5),
        source: CompletionSource.manual,
        proofModeAtTime: 'soft',
      );
      final id2 = await CompletionLogService.instance.append(
        habitId: 'h1',
        day: DateTime(2026, 6, 5),
        source: CompletionSource.notification,
        proofModeAtTime: 'soft',
      );
      expect(id1, id2);
      final rows = await CompletionLogService.instance.listForHabit('h1');
      expect(rows.length, 1);
    });

    test('append on different days inserts two rows', () async {
      await CompletionLogService.instance.append(
        habitId: 'h1',
        day: DateTime(2026, 6, 5),
        source: CompletionSource.manual,
        proofModeAtTime: 'soft',
      );
      await CompletionLogService.instance.append(
        habitId: 'h1',
        day: DateTime(2026, 6, 6),
        source: CompletionSource.manual,
        proofModeAtTime: 'soft',
      );
      final rows = await CompletionLogService.instance.listForHabit('h1');
      expect(rows.length, 2);
    });

    test('listInRange filters by closed day range', () async {
      for (final d in [3, 4, 5, 6, 7, 8]) {
        await CompletionLogService.instance.append(
          habitId: 'h1',
          day: DateTime(2026, 6, d),
          source: CompletionSource.manual,
          proofModeAtTime: 'soft',
        );
      }
      final rows = await CompletionLogService.instance.listInRange(
        'h1',
        from: DateTime(2026, 6, 5),
        to: DateTime(2026, 6, 7),
      );
      expect(rows.length, 3);
      expect(rows.map((r) => r.dayMillis), [
        DateTime(2026, 6, 5).millisecondsSinceEpoch,
        DateTime(2026, 6, 6).millisecondsSinceEpoch,
        DateTime(2026, 6, 7).millisecondsSinceEpoch,
      ]);
    });

    test('listRestDaysInMonth filters by source and month', () async {
      await CompletionLogService.instance.append(
        habitId: 'h1',
        day: DateTime(2026, 6, 5),
        source: CompletionSource.manual,
        proofModeAtTime: 'soft',
      );
      await CompletionLogService.instance.append(
        habitId: 'h1',
        day: DateTime(2026, 6, 6),
        source: CompletionSource.restDay,
        proofModeAtTime: 'soft',
      );
      await CompletionLogService.instance.append(
        habitId: 'h1',
        day: DateTime(2026, 7),
        source: CompletionSource.restDay,
        proofModeAtTime: 'soft',
      );
      final rest = await CompletionLogService.instance.listRestDaysInMonth(
        'h1',
        year: 2026,
        month: 6,
      );
      expect(rest.length, 1);
      expect(rest.first.dayMillis, DateTime(2026, 6, 6).millisecondsSinceEpoch);
    });

    test('deleteById removes the row', () async {
      final id = await CompletionLogService.instance.append(
        habitId: 'h1',
        day: DateTime(2026, 6, 5),
        source: CompletionSource.manual,
        proofModeAtTime: 'soft',
      );
      await CompletionLogService.instance.deleteById(id);
      final rows = await CompletionLogService.instance.listForHabit('h1');
      expect(rows, isEmpty);
    });

    test('deleteAll wipes the log', () async {
      await CompletionLogService.instance.append(
        habitId: 'h1',
        day: DateTime(2026, 6, 5),
        source: CompletionSource.manual,
        proofModeAtTime: 'soft',
      );
      await CompletionLogService.instance.append(
        habitId: 'h1',
        day: DateTime(2026, 6, 6),
        source: CompletionSource.manual,
        proofModeAtTime: 'soft',
      );
      await CompletionLogService.instance.deleteAll();
      final rows = await CompletionLogService.instance.listForHabit('h1');
      expect(rows, isEmpty);
    });

    test('source enum round-trips through the column', () async {
      for (final src in CompletionSource.values) {
        await CompletionLogService.instance.append(
          habitId: 'h${src.name}',
          day: DateTime(2026, 6, 5),
          source: src,
          proofModeAtTime: 'soft',
        );
      }
      for (final src in CompletionSource.values) {
        final rows = await CompletionLogService.instance.listForHabit(
          'h${src.name}',
        );
        expect(rows.length, 1);
        expect(rows.first.source, _expectedSourceTag(src));
      }
    });
  });
}

String _expectedSourceTag(CompletionSource s) {
  return switch (s) {
    CompletionSource.manual => 'manual',
    CompletionSource.notification => 'notification',
    CompletionSource.mission => 'mission',
    CompletionSource.restDay => 'rest_day',
  };
}
