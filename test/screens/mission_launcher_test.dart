// Tests for `MissionLauncherScreen` — the chain-level
// orchestrator widget for strong-mode habit mission
// launches (v1.3d / Phase 15 / SYS-114 / ADR-044).
//
// The launcher:
//   1. Loads the habit by id via the injected `habitLoader`.
//   2. Iterates the mission chain, pushing the right
//      `MissionXxxScreen` for each `Mission`.
//   3. Runs `MissionChainExecutor.run(chain, inputs)` once
//      all inputs are collected.
//   4. On `ChainPassed`, appends a completion via the
//      injected `completionAppender`.
//   5. Pops with `true` (passed), `null` (failed /
//      cancelled / missing habit).
//
// The test seam: the launcher takes optional
// `habitLoader` + `completionAppender` callbacks. Tests
// pass mocks to drive the happy / sad paths without
// touching the real DB.
//
// Test fixture choice: TypeMission only — the verify
// logic compares typed text against `expectedPhrase`
// without RNG so the tests are deterministic. MathMission
// uses a seeded RNG; verifying the executor's
// `ChainPassed` branch would require reverse-engineering
// the seeded sequence.

import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/missions/chain.dart';
import 'package:doit/missions/mission_input.dart';
import 'package:doit/screens/mission_launcher.dart';
import 'package:doit/screens/mission_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Do _strongHabit({
  required String id,
  required MissionChain chain,
  String name = 'Strong habit',
}) => DoFixed(
  id: id,
  name: name,
  proofMode: StrongProof(chain),
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  restDaysPerMonth: 0,
  weekdays: const {1, 2, 3, 4, 5, 6, 7},
  time: const DoTime(9, 0),
);

Do _softHabit({required String id}) => DoFixed(
  id: id,
  name: 'Soft habit',
  proofMode: const SoftProof(),
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  restDaysPerMonth: 0,
  weekdays: const {1, 2, 3, 4, 5, 6, 7},
  time: const DoTime(9, 0),
);

MissionChain _typeOnlyChain({required String phrase}) => MissionChain.from([
  TypeMission(
    id: 'm-type',
    label: 'Type the phrase',
    timeout: const Duration(seconds: 30),
    expectedPhrase: phrase,
  ),
]);

MissionChain _typeTypeChain({
  required String phraseA,
  required String phraseB,
}) => MissionChain.from([
  TypeMission(
    id: 'm-type-1',
    label: 'Type phrase A',
    timeout: const Duration(seconds: 30),
    expectedPhrase: phraseA,
  ),
  TypeMission(
    id: 'm-type-2',
    label: 'Type phrase B',
    timeout: const Duration(seconds: 30),
    expectedPhrase: phraseB,
  ),
]);

/// Drives the next mission route the launcher pushes by
/// popping with the given result. Returns a future that
/// completes when the launcher has either finished
/// pushing all missions or popped itself.
Future<void> _driveMissions({
  required WidgetTester tester,
  required List<Object?> pops,
}) async {
  for (final popValue in pops) {
    // Drain frames so the launcher's `Navigator.push`
    // microtask completes and the mission route is on
    // top.
    await tester.pumpAndSettle();
    expect(
      find.byType(MissionTypeScreen),
      findsOneWidget,
      reason:
          'The launcher should have pushed the next '
          'Type mission screen by now.',
    );
    // Pop the topmost route with the expected value.
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navigator.pop(popValue);
    await tester.pumpAndSettle();
  }

  // Drain the final pop.
  await tester.pumpAndSettle();
}

Future<void> _mountLauncher({
  required WidgetTester tester,
  required Future<Do?> Function(String) habitLoader,
  required Future<String> Function({
    required String habitId,
    required DateTime day,
    required String proofModeAtTime,
    String? note,
    String? missionResultsJson,
  })
  completionAppender,
  required String habitId,
  DateTime? now,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MissionLauncherScreen(
        habitId: habitId,
        habitLoader: habitLoader,
        completionAppender: completionAppender,
        nowProvider: () => now ?? DateTime(2026, 6, 25, 9),
      ),
    ),
  );

  // Drain microtasks + frames so `_runOrDismiss`
  // completes the habit lookup + chain start.
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets(
    'launches a 1-mission chain, appends completion, pops with true',
    (tester) async {
      final habit = _strongHabit(
        id: 'h-1',
        chain: _typeOnlyChain(phrase: 'hello'),
      );
      final appended = <Map<String, Object?>>[];
      await _mountLauncher(
        tester: tester,
        habitLoader: (id) async => habit,
        completionAppender:
            ({
              required String habitId,
              required DateTime day,
              required String proofModeAtTime,
              String? note,
              String? missionResultsJson,
            }) async {
              appended.add({
                'habitId': habitId,
                'day': day,
                'proofModeAtTime': proofModeAtTime,
                'missionResultsJson': missionResultsJson,
              });
              return 'c-test';
            },
        habitId: 'h-1',
      );

      await _driveMissions(
        tester: tester,
        pops: [
          // TypeMission pops with a TextInput. The
          // expected phrase is 'hello' so the typed
          // input matches (default settings:
          // caseSensitive=false, trimWhitespace=true,
          // ignorePunctuation=true).
          const TextInput('hello'),
        ],
      );

      // The completion appender was called exactly
      // once with the right habit id + proof mode tag.
      expect(appended, hasLength(1));
      expect(appended.single['habitId'], 'h-1');
      expect(appended.single['proofModeAtTime'], 'strong');
      expect(appended.single['missionResultsJson'], 'missions=1');
    },
  );

  testWidgets(
    'pops with null when the chain returns ChainFailedAt (wrong phrase)',
    (tester) async {
      final habit = _strongHabit(
        id: 'h-2',
        chain: _typeOnlyChain(phrase: 'hello'),
      );
      var appended = 0;
      await _mountLauncher(
        tester: tester,
        habitLoader: (id) async => habit,
        completionAppender:
            ({
              required String habitId,
              required DateTime day,
              required String proofModeAtTime,
              String? note,
              String? missionResultsJson,
            }) async {
              appended++;
              return 'c-test';
            },
        habitId: 'h-2',
      );

      await _driveMissions(
        tester: tester,
        pops: [
          // Wrong phrase: the chain executor returns
          // `ChainFailedAt` because the type mission's
          // `verify` flags the phrase mismatch.
          const TextInput('goodbye'),
        ],
      );

      expect(
        appended,
        0,
        reason:
            'A failed chain must NOT append a completion '
            '(the streak stays broken per v1.1f).',
      );
    },
  );

  testWidgets(
    'pops with null when the habit is missing (DoRepository returns null)',
    (tester) async {
      var appended = 0;
      await _mountLauncher(
        tester: tester,
        habitLoader: (id) async => null,
        completionAppender:
            ({
              required String habitId,
              required DateTime day,
              required String proofModeAtTime,
              String? note,
              String? missionResultsJson,
            }) async {
              appended++;
              return 'c-test';
            },
        habitId: 'h-missing',
      );
      // No missions pushed — the launcher dismisses
      // immediately.
      await tester.pumpAndSettle();

      expect(
        appended,
        0,
        reason: 'A missing habit must NOT append a completion.',
      );
    },
  );

  testWidgets('pops with null when the habit is not in StrongProof mode', (
    tester,
  ) async {
    final habit = _softHabit(id: 'h-3');
    var appended = 0;
    await _mountLauncher(
      tester: tester,
      habitLoader: (id) async => habit,
      completionAppender:
          ({
            required String habitId,
            required DateTime day,
            required String proofModeAtTime,
            String? note,
            String? missionResultsJson,
          }) async {
            appended++;
            return 'c-test';
          },
      habitId: 'h-3',
    );
    await tester.pumpAndSettle();

    expect(
      appended,
      0,
      reason:
          'A non-strong habit must NOT launch the '
          'mission UI (only StrongProof triggers '
          'FullScreenActivity per SYS-113).',
    );
  });

  testWidgets(
    'iterates a 2-mission chain and feeds both inputs to the executor',
    (tester) async {
      final habit = _strongHabit(
        id: 'h-4',
        chain: _typeTypeChain(phraseA: 'hello', phraseB: 'world'),
      );
      final appended = <Map<String, Object?>>[];
      await _mountLauncher(
        tester: tester,
        habitLoader: (id) async => habit,
        completionAppender:
            ({
              required String habitId,
              required DateTime day,
              required String proofModeAtTime,
              String? note,
              String? missionResultsJson,
            }) async {
              appended.add({
                'habitId': habitId,
                'missionResultsJson': missionResultsJson,
              });
              return 'c-test';
            },
        habitId: 'h-4',
      );

      await _driveMissions(
        tester: tester,
        pops: [const TextInput('hello'), const TextInput('world')],
      );

      // Both missions completed → completion
      // appender called once with `missions=2`.
      expect(appended, hasLength(1));
      expect(appended.single['missionResultsJson'], 'missions=2');
    },
  );

  testWidgets('aborts the chain when a mission pops with null (cancel)', (
    tester,
  ) async {
    final habit = _strongHabit(
      id: 'h-5',
      chain: _typeTypeChain(phraseA: 'hello', phraseB: 'world'),
    );
    var appended = 0;
    await _mountLauncher(
      tester: tester,
      habitLoader: (id) async => habit,
      completionAppender:
          ({
            required String habitId,
            required DateTime day,
            required String proofModeAtTime,
            String? note,
            String? missionResultsJson,
          }) async {
            appended++;
            return 'c-test';
          },
      habitId: 'h-5',
    );

    // The user cancels the first mission by popping
    // with `null` (no input). The launcher must
    // abort the rest of the chain — the second
    // mission is NEVER pushed.
    await _driveMissions(tester: tester, pops: [null]);

    // No further mission screen on the stack; the
    // launcher has popped itself.
    expect(find.byType(MissionTypeScreen), findsNothing);
    expect(
      appended,
      0,
      reason:
          'A cancelled mission aborts the chain — '
          'no completion is appended.',
    );
  });
}
