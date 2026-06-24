// Tests for [AnchorDetector] and [FakeAnchorDetector].

import 'package:doit/reminders/anchor_detector.dart';
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

  // WF-026 (Phase 11e). The evening anchor ("I'm winding
  // down") is a parallel manual anchor with its own debounce
  // counter. The morning and evening counters do NOT share
  // debounce state — a morning "I'm up" does not block the
  // evening "I'm winding down".
  group('FakeAnchorDetector (evening anchor)', () {
    test('markEveningNow records the first evening anchor', () {
      final d = FakeAnchorDetector();
      final t = d.markEveningNow();
      expect(t, isNotNull);
      expect(d.lastEveningAnchor, t);
    });

    test('markEveningNow within debounce returns null', () {
      final d = FakeAnchorDetector(debounceWindow: const Duration(seconds: 1));
      final t0 = d.markEveningNow();
      expect(t0, isNotNull);
      final t1 = d.markEveningNow();
      expect(t1, isNull);
      expect(d.lastEveningAnchor, t0);
    });

    test('morning and evening debounce counters are independent', () {
      final d = FakeAnchorDetector(debounceWindow: const Duration(seconds: 1));
      final tm = d.markNow();
      expect(tm, isNotNull);
      // The morning anchor fires; the evening anchor should
      // still fire because the debounce is per-anchor.
      final te = d.markEveningNow();
      expect(te, isNotNull);
      expect(d.lastAnchor, tm);
      expect(d.lastEveningAnchor, te);
    });

    test('morning debounce does not affect evening debounce', () {
      final d = FakeAnchorDetector(debounceWindow: const Duration(seconds: 1));
      d.markNow(); // first morning anchor
      // Second morning call within debounce returns null.
      expect(d.markNow(), isNull);
      // Evening anchor still works because it has its own
      // counter.
      expect(d.markEveningNow(), isNotNull);
    });

    test('evening debounce does not affect morning debounce', () {
      final d = FakeAnchorDetector(debounceWindow: const Duration(seconds: 1));
      d.markEveningNow(); // first evening anchor
      expect(d.markEveningNow(), isNull);
      expect(d.markNow(), isNotNull);
    });

    test('reset clears both morning and evening anchors', () {
      final d = FakeAnchorDetector();
      d.markNow();
      d.markEveningNow();
      expect(d.lastAnchor, isNotNull);
      expect(d.lastEveningAnchor, isNotNull);
      d.reset();
      expect(d.lastAnchor, isNull);
      expect(d.lastEveningAnchor, isNull);
    });
  });
}
