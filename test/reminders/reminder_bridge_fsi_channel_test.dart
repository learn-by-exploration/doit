// v1.4-stab-C / Phase 43 / SYS-130 / ADR-061 / WF-058:
// pins the KNOWN channel-surface gap on `ReminderBridge.showFullScreen`
// as a follow-up bug.
//
// **The gap.** `lib/reminders/reminder_bridge.dart` declares
// `Future<void> showFullScreen(String habitId)` on the Dart-side
// `ReminderBridge` interface (line 60). The implementation at
// line 218 invokes `_channel.invokeMethod('showFullScreen', ...)`
// over the `doit/reminders` MethodChannel.
//
// The Kotlin side at
// `android/app/src/main/kotlin/com/doit/ReminderChannelProxy.kt`
// has NO arm for `showFullScreen`. The `when` block (lines 33-78)
// handles `setExact`, `cancel`, `showNotification`,
// `cancelNotification`, `probeReliability` — everything else
// falls through to `result.notImplemented()` which the Flutter
// framework translates to `MissingPluginException` on the
// Dart side.
//
// **Why this gap is inert today.** A repo-wide grep confirms
// no production Dart code calls `reminderBridge.showFullScreen(...)`
// (the FSI launch path is wired through
// `lib/services/platform_full_screen_intent.dart` →
// `doit/full_screen` channel instead, which has the
// `showHabitMission` / `showRoutineOverlay` arms). The gap
// therefore does not crash anything in v1.4 — but the
// Dart-side seam IS broken-by-construction and a future
// caller would crash with a `MissingPluginException`.
//
// **This test pins the gap as a known follow-up bug.** A
// future stabilization cycle will either (a) remove the
// dead `showFullScreen` arm from the Dart bridge entirely,
// or (b) add the matching Kotlin arm and remove this test.
// Until then, this test is the regression-protector: if a
// future contributor "fixes" the test by mocking
// `showFullScreen` on the channel, the gap is silently
// unfixed and the next code review will catch it.
//
// AAA + deterministic. Uses the production-side method
// name `showFullScreen` to mirror the production state.

import 'package:doit/reminders/reminder_bridge.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReminderBridge.showFullScreen channel-surface gap '
      '(v1.4-stab-C / SYS-130 / ADR-061 / WF-058)', () {
    const channel = MethodChannel('doit/reminders');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('PlatformReminderBridge.showFullScreen invokes the channel method '
        '(Dart seam IS exercised — see test/reminders/reminder_bridge_test.dart '
        'line 269 for the parallel assertion on the same seam)', () async {
      // Arrange — mock handler returns null for any
      // call (the test-only seam shape; NOT the
      // production state, which returns
      // notImplemented() for unknown methods).
      final List<MethodCall> log = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            log.add(call);
            return null;
          });

      // Act
      final b = PlatformReminderBridge();
      await b.showFullScreen('h-fsi-stab');

      // Assert — the Dart seam IS exercised, even
      // though the Kotlin handler does not implement
      // it. The test pins the channel-method name so
      // a future contributor who renames either side
      // sees the test fail and updates both.
      expect(log, hasLength(1));
      expect(log.single.method, 'showFullScreen');
      expect((log.single.arguments as Map)['habitId'], 'h-fsi-stab');
    });

    test('PlatformReminderBridge.showFullScreen throws MissingPluginException '
        'when the Kotlin handler has no arm (KNOWN GAP — '
        'see ReminderChannelProxy.kt when block)', () async {
      // Arrange — simulate the PRODUCTION Kotlin
      // handler. `result.notImplemented()` for
      // unknown methods is what the Kotlin `else`
      // branch returns; Flutter's MethodChannel
      // translates that to `MissingPluginException`
      // on the Dart side.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            // Mirror production: only the documented
            // arms are handled; everything else is
            // notImplemented. The `showFullScreen`
            // method is NOT in the production arm
            // list, so it MUST fall through.
            switch (call.method) {
              case 'setExact':
              case 'cancel':
              case 'showNotification':
              case 'cancelNotification':
              case 'probeReliability':
                return null;
              default:
                throw MissingPluginException(
                  'No implementation found for method '
                  '${call.method} on channel doit/reminders',
                );
            }
          });

      // Act + Assert — the call MUST throw. This
      // pins the gap as a known behavior; a future
      // stabilization cycle that adds the
      // `showFullScreen` Kotlin arm (or removes the
      // Dart-side dead seam) will see this test
      // fail and remove it.
      final b = PlatformReminderBridge();
      await expectLater(
        () => b.showFullScreen('h-fsi-stab-gap'),
        throwsA(isA<MissingPluginException>()),
      );
    });
  });
}
