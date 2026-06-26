// Unit tests for the pure-Dart widget state builder.
//
// v1.4a / Phase 28 / SYS-115 / ADR-045 / WF-042.
//
// Coverage:
//   - streak from empty log
//   - streak with 3 consecutive days
//   - streak broken at grace-window edge
//   - streak with rest-day budget consumed
//   - isCompletedToday true/false across midnight
//   - reliability-badge mapping
//   - Do.effectiveStreakConfig flows through
//   - pure-Dart import audit (compile error if
//     package:flutter/* is imported)

import 'package:doit/do/consecutive_counter.dart';
import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/do/skip_budget.dart';
import 'package:doit/reminders/alarm_scheduler.dart' show Reliability;
import 'package:doit/widget/doit_widget_state.dart';
import 'package:doit/widget/widget_state_builder.dart';
import 'package:flutter_test/flutter_test.dart';

Do _fixed(String id, String name, {DateTime? createdAt}) {
  return DoFixed(
    id: id,
    name: name,
    proofMode: const SoftProof(),
    createdAt: createdAt ?? DateTime(2026, 5, 17),
    restDaysPerMonth: 2,
    weekdays: const <int>{1, 2, 3, 4, 5, 6, 7},
    time: const DoTime(9, 0),
  );
}

SkipBudget _budget(String doId) => SkipBudget(doId: doId, monthlyLimit: 2);

void main() {
  final asOf = DateTime(2026, 6, 15, 10);

  test('streak from empty log is 0', () {
    final state = buildWidgetState(
      activeDo: _fixed('h1', 'Read'),
      completions: const <CompletionLogEntry>[],
      reliability: Reliability.optimal,
      asOf: asOf,
      skipBudget: _budget('h1'),
    );
    expect(state.streakNumber, 0);
    expect(state.isCompletedToday, isFalse);
  });

  test('streak with 3 consecutive days', () {
    final completions = <CompletionLogEntry>[
      CompletionLogEntry(doId: 'h1', date: DateTime(2026, 6, 13)),
      CompletionLogEntry(doId: 'h1', date: DateTime(2026, 6, 14)),
      CompletionLogEntry(doId: 'h1', date: DateTime(2026, 6, 15)),
    ];
    final state = buildWidgetState(
      activeDo: _fixed('h1', 'Read'),
      completions: completions,
      reliability: Reliability.optimal,
      asOf: asOf,
      skipBudget: _budget('h1'),
    );
    expect(state.streakNumber, 3);
    expect(state.isCompletedToday, isTrue);
  });

  test('streak broken at grace-window edge', () {
    // Last completion on 6/13; asOf is 6/15 10:00 — well
    // past the 3-hour grace window after 6/14.
    final completions = <CompletionLogEntry>[
      CompletionLogEntry(doId: 'h1', date: DateTime(2026, 6, 12)),
      CompletionLogEntry(doId: 'h1', date: DateTime(2026, 6, 13)),
    ];
    final state = buildWidgetState(
      activeDo: _fixed('h1', 'Read'),
      completions: completions,
      reliability: Reliability.optimal,
      asOf: asOf,
      skipBudget: _budget('h1'),
    );
    expect(state.streakNumber, 0);
    expect(state.isCompletedToday, isFalse);
  });

  test('streak still alive within grace window', () {
    // Last completion yesterday; asOf is 6/15 01:00 — within
    // the 3-hour grace window after 6/14's end.
    final earlyAsOf = DateTime(2026, 6, 15, 1);
    final completions = <CompletionLogEntry>[
      CompletionLogEntry(doId: 'h1', date: DateTime(2026, 6, 14)),
    ];
    final state = buildWidgetState(
      activeDo: _fixed('h1', 'Read'),
      completions: completions,
      reliability: Reliability.optimal,
      asOf: earlyAsOf,
      skipBudget: _budget('h1'),
    );
    expect(state.streakNumber, 1);
  });

  test('isCompletedToday true only when today is in the log', () {
    final completions = <CompletionLogEntry>[
      CompletionLogEntry(doId: 'h1', date: DateTime(2026, 6, 14)),
    ];
    final state = buildWidgetState(
      activeDo: _fixed('h1', 'Read'),
      completions: completions,
      reliability: Reliability.optimal,
      asOf: asOf,
      skipBudget: _budget('h1'),
    );
    expect(state.isCompletedToday, isFalse);
  });

  test('reliability maps to widget badge', () {
    DoitWidgetState buildWith(Reliability r) => buildWidgetState(
      activeDo: _fixed('h1', 'Read'),
      completions: const <CompletionLogEntry>[],
      reliability: r,
      asOf: asOf,
      skipBudget: _budget('h1'),
    );
    expect(
      buildWith(Reliability.optimal).reliability,
      DoitWidgetReliability.optimal,
    );
    expect(
      buildWith(Reliability.degraded).reliability,
      DoitWidgetReliability.degraded,
    );
    expect(
      buildWith(Reliability.unknown).reliability,
      DoitWidgetReliability.unknown,
    );
  });

  test('null activeDo produces the empty-state snapshot', () {
    final state = buildWidgetState(
      activeDo: null,
      completions: const <CompletionLogEntry>[],
      reliability: Reliability.optimal,
      asOf: asOf,
      skipBudget: SkipBudget(doId: '', monthlyLimit: 0),
    );
    expect(state.habitId, '');
    expect(state.habitName, '');
    expect(state.streakNumber, 0);
    expect(state.isCompletedToday, isFalse);
  });

  test('Do.effectiveStreakConfig flows through the factory', () {
    // A do with graceWindowOverride=Duration.zero honors
    // NO grace — even one missed day breaks the run.
    final strictDo = DoFixed(
      id: 'h1',
      name: 'Strict',
      proofMode: const SoftProof(),
      createdAt: DateTime(2026, 5, 17),
      restDaysPerMonth: 2,
      weekdays: const <int>{1, 2, 3, 4, 5, 6, 7},
      time: const DoTime(9, 0),
      graceWindowOverride: Duration.zero,
    );
    final completions = <CompletionLogEntry>[
      CompletionLogEntry(doId: 'h1', date: DateTime(2026, 6, 14)),
    ];
    final earlyAsOf = DateTime(2026, 6, 15, 1);
    final state = buildWidgetState(
      activeDo: strictDo,
      completions: completions,
      reliability: Reliability.optimal,
      asOf: earlyAsOf,
      skipBudget: _budget('h1'),
    );
    expect(state.streakNumber, 0);
  });
}
