// Tests for the Do model: validation, immutability, copyWith.

import 'package:doit/do/consecutive_counter.dart';
import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/do/skip_budget.dart';
import 'package:doit/missions/chain.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _createdAt() => DateTime(2026);

DoFixed _fixed() {
  return DoFixed(
    id: 'h1',
    name: 'Drink water',
    proofMode: const SoftProof(),
    createdAt: _createdAt(),
    restDaysPerMonth: 2,
    weekdays: const {1, 3, 5},
    time: const DoTime(9, 0),
  );
}

DoInterval _interval() {
  return DoInterval(
    id: 'h1',
    name: 'Read',
    proofMode: const SoftProof(),
    createdAt: _createdAt(),
    restDaysPerMonth: 2,
    nDays: 3,
    referenceDate: DateTime(2026, 6),
  );
}

DoAnchor _anchor() {
  return DoAnchor(
    id: 'h1',
    name: 'Follow up',
    proofMode: const SoftProof(),
    createdAt: _createdAt(),
    restDaysPerMonth: 2,
    targetDoId: 'h0',
    lastAnchor: null,
  );
}

DoDayOfX _dayOfMonth({required int day}) {
  return DoDayOfX(
    id: 'h1',
    name: 'Pay rent',
    proofMode: const SoftProof(),
    createdAt: _createdAt(),
    restDaysPerMonth: 2,
    dayOfMonth: day,
  );
}

// WF-021 (Phase 11d). Per-day todo has no schedule-specific
// fields — same shape as the model base.
DoPerDay _perDay() {
  return DoPerDay(
    id: 'h1',
    name: 'Daily check-in',
    proofMode: const SoftProof(),
    createdAt: _createdAt(),
    restDaysPerMonth: 2,
  );
}

StrongProof _strong() {
  return StrongProof(
    MissionChain.from(const [
      ShakeMission(
        id: 'm1',
        label: 'Shake 14',
        timeout: Duration(seconds: 30),
        targetCount: 14,
      ),
    ]),
  );
}

void main() {
  group('Do.validate', () {
    test('a fresh Soft habit validates', () {
      expect(_fixed().validate, returnsNormally);
    });

    test('a fresh Interval habit validates', () {
      expect(_interval().validate, returnsNormally);
    });

    test('a fresh Anchor habit validates', () {
      expect(_anchor().validate, returnsNormally);
    });

    test('a fresh DayOfX habit validates', () {
      expect(_dayOfMonth(day: 15).validate, returnsNormally);
    });

    // WF-021 (Phase 11d). DoPerDay has no schedule-specific
    // invariants beyond the base — empty validate arm.
    test('a fresh PerDay habit validates', () {
      expect(_perDay().validate, returnsNormally);
    });

    test('empty name throws DoNameEmpty', () {
      final h = _fixed().copyWith(name: '   ');
      expect(h.validate, throwsA(isA<DoNameEmpty>()));
    });

    test('invalid time throws DoInvalidTime', () {
      final h = _fixed().copyWith(time: const DoTime(25, 0));
      expect(h.validate, throwsA(isA<DoInvalidTime>()));
    });

    test('negative restDaysPerMonth throws', () {
      final h = _fixed().copyWith(restDaysPerMonth: -1);
      expect(h.validate, throwsA(isA<DoInvalidRestDays>()));
    });

    test('empty weekday set throws DoNoWeekdaysSelected', () {
      final h = _fixed().copyWith(weekdays: <Weekday>{});
      expect(h.validate, throwsA(isA<DoNoWeekdaysSelected>()));
    });

    test('weekday out of range throws DoInvalidWeekday', () {
      final h = _fixed().copyWith(weekdays: <Weekday>{0, 1});
      expect(h.validate, throwsA(isA<DoInvalidWeekday>()));
    });

    test('interval nDays < 1 throws DoInvalidInterval', () {
      final h = _interval().copyWith(nDays: 0);
      expect(h.validate, throwsA(isA<DoInvalidInterval>()));
    });

    test('anchor self-reference throws DoAnchorSelfReference', () {
      final h = _anchor().copyWith(targetDoId: 'h1');
      expect(h.validate, throwsA(isA<DoAnchorSelfReference>()));
    });

    test('dayOfMonth out of range throws DoInvalidDayOfMonth', () {
      final h = _dayOfMonth(day: 0);
      expect(h.validate, throwsA(isA<DoInvalidDayOfMonth>()));
    });

    test('dayOfMonth = 32 throws DoInvalidDayOfMonth', () {
      final h = _dayOfMonth(day: 32);
      expect(h.validate, throwsA(isA<DoInvalidDayOfMonth>()));
    });

    test('strong proof with empty chain throws StrongChainInvalid', () {
      final h = _fixed().copyWith(proofMode: StrongProof(MissionChain.empty));
      expect(h.validate, throwsA(isA<StrongChainInvalid>()));
    });

    test(
      'strong proof with chain timeout > 5 min throws StrongChainInvalid',
      () {
        final h = _fixed().copyWith(
          proofMode: StrongProof(
            MissionChain.from(const [
              HoldMission(
                id: 'm1',
                label: 'Hold',
                timeout: Duration(minutes: 6),
                holdDuration: Duration(minutes: 6),
              ),
            ]),
          ),
        );
        expect(h.validate, throwsA(isA<StrongChainInvalid>()));
      },
    );

    test('Auto proof is rejected in v0.1', () {
      final h = _fixed().copyWith(proofMode: const AutoProof());
      expect(h.validate, throwsA(isA<AutoProofNotSupported>()));
    });

    // WF-021 (Phase 11d). Base invariants apply to DoPerDay:
    // empty name and negative rest-days still throw, even
    // though the schedule subtype has no schedule fields.
    test('PerDay habit with empty name throws DoNameEmpty', () {
      final h = _perDay().copyWith(name: '');
      expect(h.validate, throwsA(isA<DoNameEmpty>()));
    });

    test('PerDay habit with negative rest days throws DoInvalidRestDays', () {
      final h = _perDay().copyWith(restDaysPerMonth: -1);
      expect(h.validate, throwsA(isA<DoInvalidRestDays>()));
    });
  });

  group('Do.copyWith immutability', () {
    test(
      'copyWith on a Fixed habit returns a new instance with the change',
      () {
        final h = _fixed();
        final h2 = h.copyWith(name: 'Drink water (2)');
        expect(identical(h, h2), isFalse);
        expect(h.name, 'Drink water');
        expect(h2.name, 'Drink water (2)');
      },
    );

    test('missionChain on a Soft habit is empty', () {
      expect(_fixed().missionChain, MissionChain.empty);
    });

    test('missionChain on a Strong habit returns the proof chain', () {
      final h = _fixed().copyWith(proofMode: _strong());
      expect(h.missionChain.length, 1);
      expect(h.missionChain.first, isA<ShakeMission>());
    });
  });

  group('MemoryMission grid shape', () {
    test('rows*cols must be even', () {
      expect(
        () => MemoryMission(
          id: 'm1',
          label: 'Memory',
          timeout: const Duration(minutes: 2),
          rows: 3,
          cols: 3,
          theme: 'animals',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('even grid is allowed', () {
      const m = MemoryMission(
        id: 'm1',
        label: 'Memory',
        timeout: Duration(minutes: 2),
        rows: 2,
        cols: 4,
        theme: 'animals',
      );
      expect(m.rows * m.cols, 8);
    });
  });

  // WF-023 (Phase 11f). The per-do grace-window override is a
  // sealed-class field on the `Do` base; each subclass forwards
  // it through its own copyWith. The calculator reads it via
  // `effectiveStreakConfig`, falling back to the 3-hour global
  // default from SYS-019 when the override is null.
  group('Do.effectiveStreakConfig (WF-023)', () {
    test('without an override, returns the global 3-hour default', () {
      final cfg = _fixed().effectiveStreakConfig(
        skipBudget: SkipBudget(doId: 'h1', monthlyLimit: 2),
      );
      expect(cfg.graceWindow, const Duration(hours: 3));
      // Pin against the named constant so a future change to
      // SYS-019's window length shows up here.
      expect(cfg.graceWindow, kDefaultGraceWindow);
      expect(cfg.skipBudget.monthlyLimit, 2);
    });

    test('with an override, returns the override (not the default)', () {
      final h = _fixed().copyWith(
        graceWindowOverride: const Duration(hours: 6),
      );
      final cfg = h.effectiveStreakConfig(
        skipBudget: SkipBudget(doId: 'h1', monthlyLimit: 2),
      );
      expect(cfg.graceWindow, const Duration(hours: 6));
    });

    test('a zero override is honored (0-minute window)', () {
      // Edge: user can opt into a stricter "no grace at all"
      // window. We honor it verbatim rather than falling back
      // to the global default.
      final h = _fixed().copyWith(graceWindowOverride: Duration.zero);
      final cfg = h.effectiveStreakConfig(
        skipBudget: SkipBudget(doId: 'h1', monthlyLimit: 2),
      );
      expect(cfg.graceWindow, Duration.zero);
    });

    test('DoPerDay accepts and exposes the override', () {
      final h = _perDay().copyWith(
        graceWindowOverride: const Duration(minutes: 30),
      );
      expect(h.graceWindowOverride, const Duration(minutes: 30));
      final cfg = h.effectiveStreakConfig(
        skipBudget: SkipBudget(doId: 'h1', monthlyLimit: 2),
      );
      expect(cfg.graceWindow, const Duration(minutes: 30));
    });

    test('copyWith(clearGraceWindowOverride: true) resets to null', () {
      final h1 = _fixed().copyWith(
        graceWindowOverride: const Duration(hours: 6),
      );
      expect(h1.graceWindowOverride, const Duration(hours: 6));
      final h2 = h1.copyWith(clearGraceWindowOverride: true);
      expect(h2.graceWindowOverride, isNull);
      final cfg = h2.effectiveStreakConfig(
        skipBudget: SkipBudget(doId: 'h1', monthlyLimit: 2),
      );
      expect(cfg.graceWindow, const Duration(hours: 3));
    });

    test(
      'DoInterval, DoAnchor, DoDayOfX, DoTimeWindow all forward the override',
      () {
        // Each subclass has its own concrete copyWith; verify
        // they all preserve the override field.
        final iv = _interval().copyWith(
          graceWindowOverride: const Duration(minutes: 90),
        );
        expect(iv.graceWindowOverride, const Duration(minutes: 90));
        final an = _anchor().copyWith(
          graceWindowOverride: const Duration(minutes: 90),
        );
        expect(an.graceWindowOverride, const Duration(minutes: 90));
        final dx = _dayOfMonth(
          day: 15,
        ).copyWith(graceWindowOverride: const Duration(minutes: 90));
        expect(dx.graceWindowOverride, const Duration(minutes: 90));
        final tw = DoTimeWindow(
          id: 'tw',
          name: 'Fasting',
          proofMode: const SoftProof(),
          createdAt: DateTime(2026),
          restDaysPerMonth: 2,
          weekdays: const {1, 2, 3, 4, 5},
          start: const DoTime(20, 0),
          end: const DoTime(12, 0),
          targetHours: 16,
          graceWindowOverride: const Duration(minutes: 90),
        );
        expect(tw.graceWindowOverride, const Duration(minutes: 90));
      },
    );
  });
}
