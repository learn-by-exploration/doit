// Tests for PauseService (v0.4b-era seam, v1.2d cleanup).
//
// Coverage:
//   - `_ready` is eagerly completed at construction time
//     (regression: pre-v1.2d the Completer was never completed
//     and every public method hung on `await _ready`).
//   - `resetForTesting()` is idempotent and does not throw
//     even if called before the singleton has been used.

import 'package:doit/services/pause_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PauseService readiness gate (v1.2d / Phase 4)', () {
    test('`isReady` is true at first read (no `init()` needed)', () {
      // No `init()` call — the eager-complete-at-constructor
      // pattern means the singleton is ready the instant
      // `PauseService.instance` is dereferenced.
      expect(PauseService.instance.isReady, isTrue);
    });

    test('resetForTesting() is idempotent and does not throw', () {
      // First call: Completer is already complete (eager).
      PauseService.instance.resetForTesting();
      // Second call: still no throw.
      PauseService.instance.resetForTesting();
    });

    test('resetForTesting() keeps the gate complete', () {
      PauseService.instance.resetForTesting();
      expect(PauseService.instance.isReady, isTrue);
    });
  });
}
