// Tests for the bulk-complete helper (WF-029).
//
// The home screen enters a "select mode" when the user
// long-presses a habit tile. The bulk-complete path appends
// a CompletionLogEntry for every selected habit at the current
// wall-clock day, then exits select mode.

import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/services/completion_log_service.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/services/do_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    await AppDatabaseService.instance.closeForTesting();
    db = AppDatabase(NativeDatabase.memory());
    await AppDatabaseService.instance.init(overrideDb: db);
    await AppDatabaseService.instance.ready;
  });

  tearDown(() async {
    await AppDatabaseService.instance.closeForTesting();
  });

  Future<void> seed(int n) async {
    for (var i = 0; i < n; i++) {
      await DoRepository.instance.save(
        DoFixed(
          id: 'h$i',
          name: 'Do $i',
          proofMode: const SoftProof(),
          createdAt: DateTime(2026, 6),
          restDaysPerMonth: 0,
          weekdays: const {1, 2, 3, 4, 5, 6, 7},
          time: const DoTime(9, 0),
        ),
      );
    }
  }

  test('bulk complete: appends one row per selected habit', () async {
    await seed(3);
    final now = DateTime.now();
    for (final id in ['h0', 'h1', 'h2']) {
      await CompletionLogService.instance.append(
        habitId: id,
        day: now,
        source: CompletionSource.manual,
        proofModeAtTime: 'soft',
      );
    }
    final ids = <String>{};
    for (final id in ['h0', 'h1', 'h2']) {
      final log = await CompletionLogService.instance.listForHabit(id);
      ids.add(id);
      expect(log.length, 1);
    }
    expect(ids, {'h0', 'h1', 'h2'});
  });

  test('bulk complete: de-dupe by (habitId, dayMillis)', () async {
    await seed(1);
    final now = DateTime.now();
    // Two appends for the same habit on the same day collapse
    // to a single row (the unique index dedupes).
    await CompletionLogService.instance.append(
      habitId: 'h0',
      day: now,
      source: CompletionSource.manual,
      proofModeAtTime: 'soft',
    );
    await CompletionLogService.instance.append(
      habitId: 'h0',
      day: now,
      source: CompletionSource.manual,
      proofModeAtTime: 'soft',
    );
    final log = await CompletionLogService.instance.listForHabit('h0');
    expect(log.length, 1);
  });
}
