// Tests for `lib/reminders/full_screen_intent.dart` —
// the Dart-side FullScreenIntent abstraction, the
// FakeFullScreenIntent test seam, and the v1.3d
// LaunchIntent / LaunchMode additive (SYS-114 / ADR-044).
//
// v1.4-stab-C / Phase 43 / SYS-130 / ADR-061 / WF-058:
// these tests lift `lib/reminders/full_screen_intent.dart`
// coverage from 25% (Cycle A audit) to ≥ 80%. The
// production `PlatformFullScreenIntent` implementation is
// exercised by `test/services/platform_full_screen_intent_test.dart`
// (channel-level); this file covers the data classes and
// the in-memory test fixture that widget tests depend on.
//
// AAA + deterministic. The seed data is a strong-mode
// DoFixed + MathMission chain so the test fixture mirrors
// the real call-site shape.

import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/missions/chain.dart';
import 'package:doit/reminders/full_screen_intent.dart';
import 'package:flutter_test/flutter_test.dart';

/// A strong-mode habit + matching MathMission chain. The
/// FSI launch handler does NOT execute the chain — it just
/// hands the habitId to the Kotlin side — but the chain
/// must be non-null per the `FullScreenLaunch` contract.
MissionChain _strongChain() => MissionChain.from([
  const MathMission(
    id: 'm-fsi-1',
    label: 'Solve the math',
    timeout: Duration(seconds: 30),
    difficulty: MathDifficulty.easy,
  ),
]);

Do _strongHabit({String id = 'h-fsi-test', String name = 'FSI test'}) =>
    DoFixed(
      id: id,
      name: name,
      proofMode: StrongProof(_strongChain()),
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      restDaysPerMonth: 0,
      weekdays: const {1, 2, 3, 4, 5, 6, 7},
      time: const DoTime(9, 0),
    );

void main() {
  group('FakeFullScreenIntent.show', () {
    test('records every FullScreenLaunch in invocation order', () async {
      // Arrange
      final fsi = FakeFullScreenIntent();
      final habit1 = _strongHabit(id: 'h-1');
      final habit2 = _strongHabit(id: 'h-2', name: 'Second habit');
      final chain1 = _strongChain();
      final chain2 = _strongChain();

      // Act
      await fsi.show(habit1, chain1);
      await fsi.show(habit2, chain2);

      // Assert
      expect(fsi.launches, hasLength(2));
      expect(fsi.launches[0].habit.id, 'h-1');
      expect(fsi.launches[1].habit.id, 'h-2');
      expect(fsi.launches[1].habit.name, 'Second habit');
    });
  });

  group('FakeFullScreenIntent.showRoutineOverlay', () {
    test(
      'records title and body exactly as supplied (null passes through)',
      () async {
        // Arrange
        final fsi = FakeFullScreenIntent();

        // Act — three overlay calls covering title-only, body-only,
        // and neither (the routine engine emits the empty case when
        // an ActionFullscreen arm has neither title nor body).
        await fsi.showRoutineOverlay(title: 'Japan silent', body: 'Toggle on');
        await fsi.showRoutineOverlay(title: 'title only');
        await fsi.showRoutineOverlay();
        await fsi.showRoutineOverlay(body: 'body only');

        // Assert
        expect(fsi.routineOverlays, hasLength(4));
        expect(fsi.routineOverlays[0].title, 'Japan silent');
        expect(fsi.routineOverlays[0].body, 'Toggle on');
        expect(fsi.routineOverlays[1].title, 'title only');
        expect(fsi.routineOverlays[1].body, isNull);
        expect(fsi.routineOverlays[2].title, isNull);
        expect(fsi.routineOverlays[2].body, isNull);
        expect(fsi.routineOverlays[3].title, isNull);
        expect(fsi.routineOverlays[3].body, 'body only');
      },
    );
  });

  group('FakeFullScreenIntent.getLaunchIntent', () {
    test(
      'returns the scripted launch intent and appends it to launchIntents',
      () async {
        // Arrange — v1.3d / SYS-114 / ADR-044: the canonical read
        // for re-entry scenarios is `getLaunchIntent()` over the
        // `doit/full_screen` channel. The Fake seam implements
        // the same shape so widget tests can drive it.
        final fsi = FakeFullScreenIntent();
        const scripted = LaunchIntent(
          mode: LaunchMode.habit,
          habitId: 'h-from-channel',
        );

        // Act
        fsi.scriptedLaunchIntent = scripted;
        final result1 = await fsi.getLaunchIntent();
        final result2 = await fsi.getLaunchIntent();

        // Assert — same scripted value returned both times
        // (mirrors production behavior; the channel is
        // idempotent), and every invocation is recorded in
        // launchIntents so the widget test can confirm the
        // initial-route read AND the on-demand read happened.
        expect(result1, scripted);
        expect(result2, scripted);
        expect(fsi.launchIntents, [scripted, scripted]);
      },
    );

    test(
      'returns null and records null when scriptedLaunchIntent is null',
      () async {
        // Arrange — the production outcome for `getLaunchIntent`
        // when the activity was NOT launched as a full-screen
        // intent (e.g., unrelated future entry point). The
        // Fake seam must mirror the production contract.
        final fsi = FakeFullScreenIntent();

        // Act
        final result = await fsi.getLaunchIntent();

        // Assert
        expect(result, isNull);
        expect(fsi.launchIntents, [isNull]);
      },
    );
  });

  group('RoutineOverlayLaunch equality', () {
    test('equal when title + body match; hashCode is consistent', () {
      // Arrange
      const a = RoutineOverlayLaunch(title: 't', body: 'b');
      const b = RoutineOverlayLaunch(title: 't', body: 'b');
      const c = RoutineOverlayLaunch(title: 't', body: 'different');

      // Act + Assert
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('LaunchIntent equality', () {
    test('equal when mode + habitId + title + body all match', () {
      // Arrange
      const a = LaunchIntent(mode: LaunchMode.habit, habitId: 'h-1');
      const b = LaunchIntent(mode: LaunchMode.habit, habitId: 'h-1');
      const c = LaunchIntent(mode: LaunchMode.overlay, title: 't', body: 'b');

      // Act + Assert
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });
}
