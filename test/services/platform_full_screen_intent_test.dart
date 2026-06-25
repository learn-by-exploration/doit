// Tests for `PlatformFullScreenIntent` — the production
// Dart-side adapter for the `doit/full_screen` channel.
//
// v1.3d / Phase 15 / SYS-114 / ADR-044: covers the launch
// handlers (`showHabitMission`, `showRoutineOverlay`) and
// the launch-intent read (`getLaunchIntent`). Each test
// mocks the channel and asserts the right method + args
// are invoked.
//
// The `_safe` wrapper is exercised end-to-end: a
// `MissingPluginException` (the production outcome for
// `getLaunchIntent` since the Kotlin side does not
// implement it) MUST be swallowed and `getLaunchIntent`
// must return `null`. The wrapper is defense-in-depth per
// ADR-013.

import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/missions/chain.dart';
import 'package:doit/services/platform_full_screen_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A mission chain with a single Math mission. The
/// launcher does NOT execute the chain itself — the
/// platform FSI adapter just hands the `habitId` to the
/// Kotlin side. The chain is included so the test fixture
/// matches a realistic strong-mode habit.
MissionChain _strongChain() => MissionChain.from([
  const MathMission(
    id: 'm1',
    label: 'Solve the problem',
    timeout: Duration(seconds: 30),
    difficulty: MathDifficulty.easy,
  ),
]);

Do _strongHabit({String id = 'h-fsi', String name = 'FSI test habit'}) =>
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
  TestWidgetsFlutterBinding.ensureInitialized();

  // The channel under test. Mirrors the production
  // `doit/full_screen` channel name.
  const channel = MethodChannel('doit/full_screen');

  late List<MethodCall> calls;

  setUp(() {
    calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'showHabitMission':
        case 'showRoutineOverlay':
          return true;
        case 'canUseFullScreenIntent':
        case 'openFullScreenIntentSettings':
          return true;
        case 'getLaunchIntent':
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('showHabitMission invokes the channel with the habit id', () async {
    final fsi = PlatformFullScreenIntent();
    await fsi.show(_strongHabit(id: 'h-7'), _strongChain());
    expect(calls, hasLength(1));
    expect(calls.single.method, 'showHabitMission');
    expect(
      (calls.single.arguments as Map)['habitId'],
      'h-7',
      reason: 'The habit id is the canonical key the Kotlin side reads.',
    );
  });

  test(
    'showRoutineOverlay invokes the channel with title and body when both are provided',
    () async {
      final fsi = PlatformFullScreenIntent();
      await fsi.showRoutineOverlay(title: 'Japan silent', body: 'Toggle on');
      expect(calls, hasLength(1));
      expect(calls.single.method, 'showRoutineOverlay');
      expect((calls.single.arguments as Map)['title'], 'Japan silent');
      expect((calls.single.arguments as Map)['body'], 'Toggle on');
    },
  );

  test(
    'showRoutineOverlay propagates only the provided fields (title-only / body-only / neither)',
    () async {
      final fsi = PlatformFullScreenIntent();
      await fsi.showRoutineOverlay(title: 'only title');
      expect((calls.last.arguments as Map).containsKey('title'), isTrue);
      expect((calls.last.arguments as Map).containsKey('body'), isFalse);

      await fsi.showRoutineOverlay(body: 'only body');
      expect((calls.last.arguments as Map).containsKey('title'), isFalse);
      expect((calls.last.arguments as Map).containsKey('body'), isTrue);

      await fsi.showRoutineOverlay();
      expect((calls.last.arguments as Map).containsKey('title'), isFalse);
      expect((calls.last.arguments as Map).containsKey('body'), isFalse);
    },
  );

  test(
    'getLaunchIntent returns null when the channel reports MissingPluginException',
    () async {
      // v1.3d / SYS-114 / ADR-044: the Kotlin side
      // does NOT implement `getLaunchIntent` (the
      // initial-route query string is the canonical
      // read). The Dart `_safe` wrapper swallows the
      // `MissingPluginException` and returns `null`.
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getLaunchIntent') {
          throw MissingPluginException(
            'No implementation found for method getLaunchIntent '
            'on channel doit/full_screen',
          );
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
      });

      final fsi = PlatformFullScreenIntent();
      // `kDebugMode` is true under flutter_test, so the
      // `debugPrint` call inside `_safe` runs. We do
      // not assert on the print — only on the result.
      // Capture the print to keep the test output
      // clean.
      final originalDebugPrint = debugPrint;
      debugPrint = (_, {wrapWidth}) {};
      addTearDown(() {
        debugPrint = originalDebugPrint;
      });

      final result = await fsi.getLaunchIntent();
      expect(
        result,
        isNull,
        reason:
            'A MissingPluginException is the production '
            'outcome for getLaunchIntent and MUST be '
            'swallowed (ADR-013).',
      );
    },
  );

  test(
    'showHabitMission swallows MissingPluginException (production behavior)',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw MissingPluginException(
          'No implementation found for method showHabitMission '
          'on channel doit/full_screen',
        );
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
      });

      final fsi = PlatformFullScreenIntent();
      // The `_safe` wrapper swallows the exception
      // and the call resolves normally. If `_safe`
      // re-raised, this test would fail.
      await fsi.show(_strongHabit(), _strongChain());
    },
  );
}
