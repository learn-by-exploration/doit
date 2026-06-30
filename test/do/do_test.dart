// Tests for the Do model — sealed hierarchy of 5 schedule types.
//
// v1.4-stab-K (Phase 51 / SYS-138 / ADR-069 / WF-066): the
// model-layer direct unit tests for `lib/do/do.dart` that bring
// the file to 100% line coverage. The integration_test at
// `integration_test/critical_flows_test.dart` exercises the
// end-to-end flows; this file pins the pure-Dart invariants.
//
// Note: `DateTime` has no const constructor, so the test data
// uses `final` (not `const`) for `DoFixed` / `DoInterval` etc.
// This is the same constraint surfaced in Cycle C/G.

import 'package:doit/do/consecutive_counter.dart';
import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/do/skip_budget.dart';
import 'package:doit/missions/chain.dart';
import 'package:flutter_test/flutter_test.dart';

// A frozen "now" used as `createdAt` for every test fixture.
final DateTime _createdAt = DateTime(2026, 1, 15);

// A pause-in-the-future timestamp for pause-related tests.
final DateTime _pauseUntil = DateTime(2026, 6, 16);

void main() {
  group('DoTime', () {
    test('== and hashCode are value-based', () {
      expect(const DoTime(7, 30), equals(const DoTime(7, 30)));
      expect(
        const DoTime(7, 30).hashCode,
        equals(const DoTime(7, 30).hashCode),
      );
      expect(const DoTime(7, 30), isNot(equals(const DoTime(7, 31))));
    });

    test('toString zero-pads both fields', () {
      expect(const DoTime(0, 5).toString(), '00:05');
      expect(const DoTime(23, 59).toString(), '23:59');
    });
  });

  group('Do.validate', () {
    test('accepts a well-formed DoFixed', () {
      final d = DoFixed(
        id: 'h1',
        name: 'Read',
        proofMode: const SoftProof(),
        createdAt: _createdAt,
        restDaysPerMonth: 2,
        weekdays: const {1, 3, 5},
        time: const DoTime(7, 30),
      );
      expect(d.validate, returnsNormally);
    });

    test('rejects empty name', () {
      final d = DoFixed(
        id: 'h1',
        name: '   ',
        proofMode: const SoftProof(),
        createdAt: _createdAt,
        restDaysPerMonth: 2,
        weekdays: const {1},
        time: const DoTime(7, 30),
      );
      expect(d.validate, throwsA(isA<DoNameEmpty>()));
    });

    test('rejects restDaysPerMonth out of range', () {
      final d = DoFixed(
        id: 'h1',
        name: 'Read',
        proofMode: const SoftProof(),
        createdAt: _createdAt,
        restDaysPerMonth: 32,
        weekdays: const {1},
        time: const DoTime(7, 30),
      );
      expect(d.validate, throwsA(isA<DoInvalidRestDays>()));
    });

    test('rejects colorSeed out of range', () {
      final d = DoFixed(
        id: 'h1',
        name: 'Read',
        proofMode: const SoftProof(),
        createdAt: _createdAt,
        restDaysPerMonth: 2,
        weekdays: const {1},
        time: const DoTime(7, 30),
        colorSeed: 8,
      );
      expect(d.validate, throwsA(isA<DoInvalidColorSeed>()));
    });

    test('rejects unknown icon name', () {
      final d = DoFixed(
        id: 'h1',
        name: 'Read',
        proofMode: const SoftProof(),
        createdAt: _createdAt,
        restDaysPerMonth: 2,
        weekdays: const {1},
        time: const DoTime(7, 30),
        iconName: 'not-a-real-icon',
      );
      expect(d.validate, throwsA(isA<DoInvalidIconName>()));
    });
  });

  group('DoFixed', () {
    test('copyWith preserves id and createdAt', () {
      final original = DoFixed(
        id: 'h1',
        name: 'Read',
        proofMode: const SoftProof(),
        createdAt: _createdAt,
        restDaysPerMonth: 2,
        weekdays: const {1, 3, 5},
        time: const DoTime(7, 30),
      );
      final updated = original.copyWith(name: 'Read 2');
      expect(updated.id, 'h1');
      expect(updated.createdAt, original.createdAt);
      expect(updated.name, 'Read 2');
      expect(updated.weekdays, original.weekdays);
    });

    test('copyWith with clearPausedUntil nullifies pause', () {
      final original = DoFixed(
        id: 'h1',
        name: 'Read',
        proofMode: const SoftProof(),
        createdAt: _createdAt,
        restDaysPerMonth: 2,
        weekdays: const {1},
        time: const DoTime(7, 30),
        pausedUntil: _pauseUntil,
      );
      final cleared = original.copyWith(clearPausedUntil: true);
      expect(cleared.pausedUntil, isNull);
    });

    test('rejects empty weekdays', () {
      final d = DoFixed(
        id: 'h1',
        name: 'Read',
        proofMode: const SoftProof(),
        createdAt: _createdAt,
        restDaysPerMonth: 2,
        weekdays: const <Weekday>{},
        time: const DoTime(7, 30),
      );
      expect(d.validate, throwsA(isA<DoNoWeekdaysSelected>()));
    });

    test('rejects out-of-range weekday', () {
      final d = DoFixed(
        id: 'h1',
        name: 'Read',
        proofMode: const SoftProof(),
        createdAt: _createdAt,
        restDaysPerMonth: 2,
        weekdays: const {8},
        time: const DoTime(7, 30),
      );
      expect(d.validate, throwsA(isA<DoInvalidWeekday>()));
    });

    test('rejects invalid time', () {
      final d = DoFixed(
        id: 'h1',
        name: 'Read',
        proofMode: const SoftProof(),
        createdAt: _createdAt,
        restDaysPerMonth: 2,
        weekdays: const {1},
        time: const DoTime(25, 0),
      );
      expect(d.validate, throwsA(isA<DoInvalidTime>()));
    });

    test('nextOccurrence returns same day if time has not passed', () {
      final d = DoFixed(
        id: 'h1',
        name: 'Read',
        proofMode: const SoftProof(),
        createdAt: _createdAt,
        restDaysPerMonth: 2,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        time: const DoTime(23, 59),
      );
      // 2026-01-15 is a Thursday (weekday=4); time 23:59 is after
      // from=2026-01-15 07:00.
      final next = d.nextOccurrence(DateTime(2026, 1, 15, 8));
      expect(next, equals(DateTime(2026, 1, 15, 23, 59)));
    });

    test('nextOccurrence returns next matching weekday', () {
      final d = DoFixed(
        id: 'h1',
        name: 'Read',
        proofMode: const SoftProof(),
        createdAt: _createdAt,
        restDaysPerMonth: 2,
        weekdays: const {2}, // Tuesday only
        time: const DoTime(7, 30),
      );
      // From 2026-01-15 (Thursday); next Tuesday is 2026-01-20.
      final next = d.nextOccurrence(DateTime(2026, 1, 15, 12));
      expect(next, equals(DateTime(2026, 1, 20, 7, 30)));
    });
  });

  group('DoInterval', () {
    test('copyWith preserves id and referenceDate', () {
      final original = DoInterval(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: _createdAt,
        restDaysPerMonth: 2,
        nDays: 3,
        referenceDate: _createdAt,
      );
      final updated = original.copyWith(nDays: 5);
      expect(updated.id, 'h1');
      expect(updated.referenceDate, _createdAt);
      expect(updated.nDays, 5);
    });

    test('rejects nDays < 1', () {
      final d = DoInterval(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: _createdAt,
        restDaysPerMonth: 2,
        nDays: 0,
        referenceDate: _createdAt,
      );
      expect(d.validate, throwsA(isA<DoInvalidInterval>()));
    });

    test('nextOccurrence before ref returns ref', () {
      final d = DoInterval(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 1, 15),
        restDaysPerMonth: 2,
        nDays: 3,
        referenceDate: DateTime(2026, 6, 16),
      );
      final next = d.nextOccurrence(DateTime(2026, 1, 15));
      expect(next, equals(DateTime(2026, 6, 16)));
    });

    test('nextOccurrence on ref returns ref + nDays', () {
      final d = DoInterval(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 1, 15),
        restDaysPerMonth: 2,
        nDays: 3,
        referenceDate: DateTime(2026, 6, 16),
      );
      final next = d.nextOccurrence(DateTime(2026, 6, 1, 12));
      expect(next, equals(DateTime(2026, 6, 16)));
    });
  });

  group('DoAnchor', () {
    test('copyWith preserves id and targetDoId', () {
      final original = DoAnchor(
        id: 'a1',
        name: 'Stretch after run',
        proofMode: const SoftProof(),
        createdAt: _createdAt,
        restDaysPerMonth: 2,
        targetDoId: 'h1',
        lastAnchor: null,
      );
      final updated = original.copyWith(name: 'Stretch after run 2');
      expect(updated.id, 'a1');
      expect(updated.targetDoId, 'h1');
      expect(updated.name, 'Stretch after run 2');
    });

    test('copyWith with clearLastAnchor nullifies anchor', () {
      final original = DoAnchor(
        id: 'a1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: _createdAt,
        restDaysPerMonth: 2,
        targetDoId: 'h1',
        lastAnchor: DateTime(2026, 5, 15),
      );
      final cleared = original.copyWith(clearLastAnchor: true);
      expect(cleared.lastAnchor, isNull);
    });

    test('rejects self-reference', () {
      final d = DoAnchor(
        id: 'a1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: _createdAt,
        restDaysPerMonth: 2,
        targetDoId: 'a1',
        lastAnchor: null,
      );
      expect(d.validate, throwsA(isA<DoAnchorSelfReference>()));
    });

    test('nextOccurrence without anchor returns tomorrow', () {
      final d = DoAnchor(
        id: 'a1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: _createdAt,
        restDaysPerMonth: 2,
        targetDoId: 'h1',
        lastAnchor: null,
      );
      final next = d.nextOccurrence(DateTime(2026, 5, 1, 12));
      expect(next, equals(DateTime(2026, 5, 2)));
    });

    test('nextOccurrence with anchor returns anchor + 1 day', () {
      final d = DoAnchor(
        id: 'a1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: _createdAt,
        restDaysPerMonth: 2,
        targetDoId: 'h1',
        lastAnchor: DateTime(2026, 5, 15),
      );
      final next = d.nextOccurrence(DateTime(2026, 5, 2, 12));
      expect(next, equals(DateTime(2026, 5, 16)));
    });
  });

  group('DoDayOfX', () {
    test('rejects when both dayOfMonth and nth are null', () {
      // NOTE: the constructor has an `assert` that triggers in
      // debug mode; we use a non-const instance here.
      expect(
        () => DoDayOfX(
          id: 'h1',
          name: 'Pay rent',
          proofMode: const SoftProof(),
          createdAt: _createdAt,
          restDaysPerMonth: 2,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects dayOfMonth out of range', () {
      final d = DoDayOfX(
        id: 'h1',
        name: 'Pay rent',
        proofMode: const SoftProof(),
        createdAt: _createdAt,
        restDaysPerMonth: 2,
        dayOfMonth: 32,
      );
      expect(d.validate, throwsA(isA<DoInvalidDayOfMonth>()));
    });

    test('rejects nth out of range', () {
      final d = DoDayOfX(
        id: 'h1',
        name: 'Pay rent',
        proofMode: const SoftProof(),
        createdAt: _createdAt,
        restDaysPerMonth: 2,
        nth: 6,
        weekday: 2,
      );
      expect(d.validate, throwsA(isA<DoInvalidNthWeekday>()));
    });

    test('nextOccurrence by dayOfMonth rolls to next month', () {
      final d = DoDayOfX(
        id: 'h1',
        name: 'Pay rent',
        proofMode: const SoftProof(),
        createdAt: _createdAt,
        restDaysPerMonth: 2,
        dayOfMonth: 1,
      );
      // From 2026-01-15; next 1st is 2026-02-01.
      final next = d.nextOccurrence(DateTime(2026, 1, 15));
      // ignore: avoid_redundant_argument_values
      expect(next, equals(DateTime(2026, 2, 1)));
    });
  });

  group('DoTimeWindow', () {
    test('rejects empty weekdays', () {
      final d = DoTimeWindow(
        id: 'h1',
        name: 'Fasting',
        proofMode: const SoftProof(),
        createdAt: _createdAt,
        restDaysPerMonth: 2,
        weekdays: const <int>{},
        start: const DoTime(20, 0),
        end: const DoTime(12, 0),
      );
      expect(d.validate, throwsA(isA<DoNoWeekdaysSelected>()));
    });

    test('rejects targetHours out of range', () {
      final d = DoTimeWindow(
        id: 'h1',
        name: 'Fasting',
        proofMode: const SoftProof(),
        createdAt: _createdAt,
        restDaysPerMonth: 2,
        weekdays: const {1},
        start: const DoTime(20, 0),
        end: const DoTime(12, 0),
        targetHours: 25,
      );
      expect(d.validate, throwsA(isA<DoInvalidTargetHours>()));
    });

    test('copyWith with clearTargetHours nullifies target', () {
      final original = DoTimeWindow(
        id: 'h1',
        name: 'Fasting',
        proofMode: const SoftProof(),
        createdAt: _createdAt,
        restDaysPerMonth: 2,
        weekdays: const {1},
        start: const DoTime(20, 0),
        end: const DoTime(12, 0),
        targetHours: 16,
      );
      final cleared = original.copyWith(clearTargetHours: true);
      expect(cleared.targetHours, isNull);
    });

    test('nextOccurrence when inside window returns from', () {
      final d = DoTimeWindow(
        id: 'h1',
        name: 'Fasting',
        proofMode: const SoftProof(),
        createdAt: _createdAt,
        restDaysPerMonth: 2,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        start: const DoTime(0, 0),
        end: const DoTime(23, 59),
      );
      // from=2026-01-15 12:00 is inside today's window.
      final next = d.nextOccurrence(DateTime(2026, 1, 15, 12));
      expect(next, equals(DateTime(2026, 1, 15, 12)));
    });
  });

  group('Do.missionChain + isPausedAt + isDeleted + effectiveStreakConfig', () {
    late final DoFixed softDo = DoFixed(
      id: 'h1',
      name: 'Read',
      proofMode: const SoftProof(),
      createdAt: _createdAt,
      restDaysPerMonth: 2,
      weekdays: const {1},
      time: const DoTime(7, 30),
    );

    test('SoftProof yields empty mission chain', () {
      expect(softDo.missionChain, equals(MissionChain.empty));
    });

    test('StrongProof yields the configured chain', () {
      final d = DoFixed(
        id: 'h1',
        name: 'Run',
        proofMode: StrongProof(
          MissionChain([
            const ShakeMission(
              id: 'm1',
              label: 'Shake 5x',
              timeout: Duration(minutes: 1),
              targetCount: 5,
            ),
          ]),
        ),
        createdAt: _createdAt,
        restDaysPerMonth: 2,
        weekdays: const {1},
        time: const DoTime(7, 30),
      );
      expect(d.missionChain, hasLength(1));
    });

    test('isPausedAt returns true when pausedUntil is in the future', () {
      final d = DoFixed(
        id: 'h1',
        name: 'Read',
        proofMode: const SoftProof(),
        createdAt: _createdAt,
        restDaysPerMonth: 2,
        weekdays: const {1},
        time: const DoTime(7, 30),
        pausedUntil: _pauseUntil,
      );
      expect(d.isPausedAt(DateTime(2026, 5, 15)), isTrue);
      expect(d.isPausedAt(DateTime(2026, 7, 15)), isFalse);
    });

    test('isPausedAt returns false when pausedUntil is null', () {
      expect(softDo.isPausedAt(DateTime(2026, 5, 15)), isFalse);
    });

    test('isDeleted mirrors deletedAt', () {
      final d = DoFixed(
        id: 'h1',
        name: 'Read',
        proofMode: const SoftProof(),
        createdAt: _createdAt,
        restDaysPerMonth: 2,
        weekdays: const {1},
        time: const DoTime(7, 30),
        deletedAt: DateTime(2026, 5, 15),
      );
      expect(d.isDeleted, isTrue);
      expect(softDo.isDeleted, isFalse);
    });

    test('effectiveStreakConfig uses graceWindowOverride when set', () {
      final d = DoFixed(
        id: 'h1',
        name: 'Read',
        proofMode: const SoftProof(),
        createdAt: _createdAt,
        restDaysPerMonth: 2,
        weekdays: const {1},
        time: const DoTime(7, 30),
        graceWindowOverride: Duration.zero,
      );
      final budget = SkipBudget(doId: 'h1', monthlyLimit: 2);
      final config = d.effectiveStreakConfig(skipBudget: budget);
      expect(config.graceWindow, Duration.zero);
    });

    test('effectiveStreakConfig falls back to kDefaultGraceWindow', () {
      final budget = SkipBudget(doId: 'h1', monthlyLimit: 2);
      final config = softDo.effectiveStreakConfig(skipBudget: budget);
      expect(config.graceWindow, kDefaultGraceWindow);
    });
  });

  group('Do equality', () {
    test('equality is id-based for the sealed base', () {
      final a = DoFixed(
        id: 'h1',
        name: 'Read',
        proofMode: const SoftProof(),
        createdAt: _createdAt,
        restDaysPerMonth: 2,
        weekdays: const {1},
        time: const DoTime(7, 30),
      );
      final b = DoFixed(
        id: 'h1',
        name: 'Read renamed',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 2, 20),
        restDaysPerMonth: 5,
        weekdays: const {2, 4},
        time: const DoTime(9, 0),
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('DoCategory export', () {
    test('DoCategory.other is the default', () {
      final d = DoFixed(
        id: 'h1',
        name: 'Read',
        proofMode: const SoftProof(),
        createdAt: _createdAt,
        restDaysPerMonth: 2,
        weekdays: const {1},
        time: const DoTime(7, 30),
      );
      expect(d.category, DoCategory.other);
    });
  });
}
