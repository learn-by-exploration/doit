// Tests for [AnchorDetector] and [FakeAnchorDetector].

import 'package:common_games/reminders/anchor_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FakeAnchorDetector', () {
    test('markNow records the first anchor and returns it', () {
      final d = FakeAnchorDetector();
      final t = d.markNow();
      expect(t, isNotNull);
      expect(d.lastAnchor, t);
    });

    test('markNow within debounce returns null', () {
      final d = FakeAnchorDetector(debounceWindow: const Duration(seconds: 1));
      final t0 = d.markNow();
      expect(t0, isNotNull);
      final t1 = d.markNow();
      expect(t1, isNull);
      // lastAnchor remains the first one.
      expect(d.lastAnchor, t0);
    });

    test('markNow past debounce emits a new anchor', () async {
      final d = FakeAnchorDetector(
        debounceWindow: const Duration(milliseconds: 1),
      );
      final t0 = d.markNow();
      expect(t0, isNotNull);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final t1 = d.markNow();
      expect(t1, isNotNull);
      expect(t1, isNot(t0));
    });

    test('events stream emits on each non-debounced markNow', () async {
      final d = FakeAnchorDetector();
      final seen = <AnchorEvent>[];
      final sub = d.events.listen(seen.add);
      d.markNow();
      d.markNow(); // debounced
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(seen.length, 1);
    });

    test('reset clears lastAnchor', () {
      final d = FakeAnchorDetector();
      d.markNow();
      expect(d.lastAnchor, isNotNull);
      d.reset();
      expect(d.lastAnchor, isNull);
    });

    test('mode defaults to manual and can be changed', () {
      final d = FakeAnchorDetector();
      expect(d.mode, AnchorMode.manual);
      d.start(mode: AnchorMode.firstUnlock);
      expect(d.mode, AnchorMode.firstUnlock);
      d.stop();
    });
  });
}
