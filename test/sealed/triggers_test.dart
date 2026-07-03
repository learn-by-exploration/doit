// Sealed hierarchy sweep — `validate()` + value-equality paths
// for the four pure-Dart sealed hierarchies that drive the
// engine:
//   - Action           (lib/triggers/action.dart)        — 5 leaves
//   - Condition        (lib/triggers/condition.dart)     — 7 leaves
//   - MissionResult + MissionChainResult
//                      (lib/missions/mission_result.dart) — 3 + 3
//   - DoProofMode      (lib/do/proof_mode.dart)          — 3 leaves
//                                                            + 1 validator
//
// Per the v1.6-ε / Phase 63 / SYS-150 / ADR-081 / WF-078
// plan, v1.6-ε is a pure-Dart test cycle. No production code
// changes; no Drift migration; no Kotlin touches; no widget
// tests. The 14 tests live in this single file in 4 grouped
// `group(...)` blocks. AAA pattern. Frozen String/DateTime
// constants; no `DateTime.now()` inside the model.
//
// Conformance: lib/triggers/action.dart:28-33 (sealed `Action` +
// `validate()` contract); lib/triggers/condition.dart:39-44
// (sealed `Condition` + `validate()`); lib/missions/
// mission_result.dart:14-59 (sealed `MissionResult` +
// `MissionChainResult`); lib/do/proof_mode.dart:29-104
// (sealed `DoProofMode` + `validateProofMode`).

import 'package:doit/do/proof_mode.dart';
import 'package:doit/missions/chain.dart';
import 'package:doit/missions/mission.dart';
import 'package:doit/missions/mission_result.dart';
import 'package:doit/triggers/action.dart';
import 'package:doit/triggers/condition.dart';
import 'package:doit/triggers/trigger.dart' show SilentMode;
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Action — 5 leaves + per-leaf validation.
// ---------------------------------------------------------------------------

void main() {
  group('v1.6-ε / Action (5 leaves)', () {
    test('ActionNotify with empty title throws ActionNotifyEmptyTitle '
        '(v1.6-ε / SYS-150)', () {
      // Arrange — explicit empty title.
      const action = ActionNotify(title: '', body: 'hello');

      // Act + Assert
      expect(action.validate, throwsA(isA<ActionNotifyEmptyTitle>()));
    });

    test('ActionNotify with whitespace-only body throws '
        'ActionNotifyEmptyBody after trim (v1.6-ε / SYS-150)', () {
      // Arrange — whitespace-only body (trim() leaves it empty).
      const action = ActionNotify(title: 'hi', body: '   ');

      // Act + Assert
      expect(action.validate, throwsA(isA<ActionNotifyEmptyBody>()));
    });

    test('ActionCallIntercept decision enum has 3 leaves '
        '(decline/declineWithAutoReply/mute) + ==/hashCode '
        '(v1.6-ε / SYS-150)', () {
      // Arrange + Act
      const decline = ActionCallIntercept(
        decision: CallInterceptDecision.decline,
      );
      const autoReply = ActionCallIntercept(
        decision: CallInterceptDecision.declineWithAutoReply,
      );
      const mute = ActionCallIntercept(decision: CallInterceptDecision.mute);

      // Assert — enum cardinality.
      expect(CallInterceptDecision.values.length, 3);

      // Assert — value-equality + hash.
      expect(decline, decline);
      expect(decline.hashCode, isNot(autoReply.hashCode));
      expect(mute, mute);
      expect(decline, isNot(autoReply));
    });

    test('ActionOverrideSilent + SilentMode.silent target + validate() '
        'returns self + ==/hashCode (v1.6-ε / SYS-150)', () {
      // Arrange + Act
      const action = ActionOverrideSilent(targetMode: SilentMode.silent);

      // Assert
      expect(action.validate(), action);
      expect(action, action);
      expect(action.hashCode, action.hashCode);
    });

    test('ActionOpenApp with empty route throws ActionOpenAppEmptyRoute '
        '+ ==/hashCode (v1.6-ε / SYS-150)', () {
      // Arrange — empty route.
      const action = ActionOpenApp(route: '');

      // Act + Assert
      expect(action.validate, throwsA(isA<ActionOpenAppEmptyRoute>()));

      // Two distinct routes produce distinct == (not the same instance).
      const a1 = ActionOpenApp(route: 'do/abc');
      const a2 = ActionOpenApp(route: 'do/def');
      expect(a1, isNot(a2));
      expect(a1.hashCode, isNot(a2.hashCode));
    });
  });

  // -------------------------------------------------------------------------
  // Condition — 7 leaves + per-leaf validation.
  // -------------------------------------------------------------------------

  group('v1.6-ε / Condition (7 leaves)', () {
    test('ConditionTimeWindow with startHour=24 throws '
        'ConditionTimeWindowInvalidHour (v1.6-ε / SYS-150)', () {
      // Arrange — out-of-range startHour.
      const cond = ConditionTimeWindow(
        startHour: 24, // 1 past 23
        startMinute: 0,
        endHour: 23,
        endMinute: 59,
      );

      // Act + Assert
      expect(cond.validate, throwsA(isA<ConditionTimeWindowInvalidHour>()));
    });

    test('ConditionDayOfWeek with empty set throws '
        'ConditionDayOfWeekEmpty + setEquals is order-insensitive '
        '(v1.6-ε / SYS-150)', () {
      // Arrange — empty set.
      final cond = ConditionDayOfWeek(const <int>{});

      // Act + Assert — empty rejection.
      expect(cond.validate, throwsA(isA<ConditionDayOfWeekEmpty>()));

      // Arrange — order-insensitive equality.
      final a = ConditionDayOfWeek(const {1, 2, 3});
      final b = ConditionDayOfWeek(const {3, 2, 1});

      // Assert — identical contents produce identical ==.
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('ConditionDayOfWeek with weekday=0 throws '
        'ConditionDayOfWeekInvalidWeekday (off-by-one boundary) '
        '(v1.6-ε / SYS-150)', () {
      // Arrange — Monday is 1, so 0 is invalid.
      final cond = ConditionDayOfWeek(const {0, 1});

      // Act + Assert
      expect(cond.validate, throwsA(isA<ConditionDayOfWeekInvalidWeekday>()));
    });

    test('ConditionBatteryRange with low > high throws Inverted '
        '(v1.6-ε / SYS-150)', () {
      // Arrange — inverted bounds.
      const cond = ConditionBatteryRange(low: 90, high: 20);

      // Act + Assert
      expect(cond.validate, throwsA(isA<ConditionBatteryRangeInverted>()));
    });

    test('ConditionBatteryRange with low=-1 throws InvalidBound '
        '(v1.6-ε / SYS-150)', () {
      // Arrange — negative bound.
      const cond = ConditionBatteryRange(low: -1, high: 100);

      // Act + Assert
      expect(cond.validate, throwsA(isA<ConditionBatteryRangeInvalidBound>()));
    });

    test('ConditionBatteryRange with both bounds null is the open-ended '
        'window (no throw) (v1.6-ε / SYS-150)', () {
      // Arrange — fully open-ended range.
      const cond = ConditionBatteryRange();

      // Act
      final out = cond.validate();

      // Assert
      expect(out, cond);
      expect(cond.low, isNull);
      expect(cond.high, isNull);
    });

    test('ConditionSilentMode(.vibrate) == self + SilentMode has 3 leaves '
        '(v1.6-ε / SYS-150)', () {
      // Arrange + Act
      const cond = ConditionSilentMode(SilentMode.vibrate);

      // Assert — value-equality.
      expect(cond, cond);

      // Assert — SilentMode cardinality (silent, vibrate, normal).
      expect(SilentMode.values.length, 3);
    });
  });

  // -------------------------------------------------------------------------
  // MissionResult + MissionChainResult — 3 leaves + 3 chain leaves.
  // -------------------------------------------------------------------------

  group('v1.6-ε / MissionResult + MissionChainResult (3 + 3 leaves)', () {
    test('ChainPassed carries an immutable List<MissionResult> '
        '(v1.6-ε / SYS-150)', () {
      // Arrange — single-element chain.
      const chain = ChainPassed(<MissionResult>[MissionPassed()]);

      // Assert — list-equality + non-empty.
      expect(chain.results.length, 1);
      expect(chain.results.first, const MissionPassed());
    });

    test('ChainFailedAt(index, result) round-trips index + result '
        '(v1.6-ε / SYS-150)', () {
      // Arrange + Act
      const failed = ChainFailedAt(
        index: 2,
        result: MissionFailed('input-mismatch'),
      );

      // Assert
      expect(failed.index, 2);
      expect(failed.result, const MissionFailed('input-mismatch'));
    });

    test('ChainTimedOut is-a ChainFailedAt with result=MissionTimedOut '
        '(v1.6-ε / SYS-150)', () {
      // Arrange + Act
      const timedOut = ChainTimedOut(index: 1);

      // Assert — is-a + index + result type.
      expect(timedOut, isA<ChainFailedAt>());
      expect(timedOut.index, 1);
      expect(timedOut.result, isA<MissionTimedOut>());
    });
  });

  // -------------------------------------------------------------------------
  // DoProofMode — 3 leaves + validateProofMode().
  // -------------------------------------------------------------------------

  group('v1.6-ε / DoProofMode (3 leaves + validator)', () {
    test('SoftProof().validateProofMode() returns without throwing '
        '(v1.6-ε / SYS-150)', () {
      // Arrange + Act
      const proof = SoftProof();

      // Assert — void return; no throw.
      expect(() => validateProofMode(proof), returnsNormally);
    });

    test('StrongProof(MissionChain.empty) throws StrongChainInvalid '
        '"non-empty" message (v1.6-ε / SYS-150)', () {
      // Arrange — empty chain.
      // (MissionChain.empty is a static final; not const-evaluable.)
      final proof = StrongProof(MissionChain.empty);

      // Act + Assert
      expect(
        () => validateProofMode(proof),
        throwsA(
          isA<StrongChainInvalid>().having(
            (e) => e.message,
            'message',
            contains('non-empty mission chain'),
          ),
        ),
      );
    });

    test('StrongProof with totalTimeout > 5 min throws StrongChainInvalid '
        '"5-minute cap" message (SYS-031 / v1.6-ε / SYS-150)', () {
      // Arrange — chain of 6 minute-bounded TypeMissions.
      final chain = MissionChain.from(<Mission>[
        const TypeMission(
          id: 't1',
          label: 'Type A',
          expectedPhrase: 'A',
          timeout: Duration(minutes: 1),
        ),
        const TypeMission(
          id: 't2',
          label: 'Type B',
          expectedPhrase: 'B',
          timeout: Duration(minutes: 1),
        ),
        const TypeMission(
          id: 't3',
          label: 'Type C',
          expectedPhrase: 'C',
          timeout: Duration(minutes: 1),
        ),
        const TypeMission(
          id: 't4',
          label: 'Type D',
          expectedPhrase: 'D',
          timeout: Duration(minutes: 1),
        ),
        const TypeMission(
          id: 't5',
          label: 'Type E',
          expectedPhrase: 'E',
          timeout: Duration(minutes: 1),
        ),
        const TypeMission(
          id: 't6',
          label: 'Type F',
          expectedPhrase: 'F',
          timeout: Duration(minutes: 1),
        ), // total 6 min > 5 cap
      ]);
      final proof = StrongProof(chain);

      // Act + Assert
      expect(
        () => validateProofMode(proof),
        throwsA(
          isA<StrongChainInvalid>().having(
            (e) => e.message,
            'message',
            contains('5-minute cap'),
          ),
        ),
      );
    });

    test('AutoProof().validateProofMode() throws AutoProofNotSupported '
        '+ AutoProof == self (v1.6-ε / SYS-150)', () {
      // Arrange — AutoProof is rejected in v0.1.
      const proof = AutoProof();

      // Act + Assert — AutoProof rejection.
      expect(
        () => validateProofMode(proof),
        throwsA(isA<AutoProofNotSupported>()),
      );

      // Assert — value-equality (AutoProof == AutoProof, regardless
      // of identity).
      expect(proof, proof);
      expect(proof == const AutoProof(), isTrue);
    });
  });
}
