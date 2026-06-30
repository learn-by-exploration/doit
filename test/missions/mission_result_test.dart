// Tests for MissionResult / MissionChainResult sealed hierarchy.
//
// v1.4-stab-K (Phase 51 / SYS-138 / ADR-069 / WF-066): the
// model-layer direct unit tests for `lib/missions/mission_result.dart`
// that bring the file to 100% line coverage.

import 'package:doit/missions/mission_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MissionResult sealed hierarchy', () {
    test('MissionPassed without detail is valid', () {
      const r = MissionPassed();
      expect(r.detail, isNull);
    });

    test('MissionPassed with detail exposes it', () {
      const r = MissionPassed(detail: 'shaken 5 times');
      expect(r.detail, 'shaken 5 times');
    });

    test('MissionFailed carries a reason', () {
      const r = MissionFailed('magnitude too low');
      expect(r.reason, 'magnitude too low');
    });

    test('MissionTimedOut carries no payload', () {
      const r = MissionTimedOut();
      expect(r, isA<MissionResult>());
    });
  });

  group('MissionChainResult sealed hierarchy', () {
    test('ChainPassed exposes its results list', () {
      const r = ChainPassed(<MissionResult>[
        MissionPassed(),
        MissionPassed(detail: 'ok'),
      ]);
      expect(r.results, hasLength(2));
      expect(r.results[0], isA<MissionPassed>());
      expect(r.results[1], isA<MissionPassed>());
    });

    test('ChainFailedAt exposes the failure index + result', () {
      const r = ChainFailedAt(index: 3, result: MissionFailed('out of order'));
      expect(r.index, 3);
      expect(r.result, isA<MissionFailed>());
      expect((r.result as MissionFailed).reason, 'out of order');
    });

    test('ChainTimedOut is a ChainFailedAt with index only', () {
      const r = ChainTimedOut(index: 5);
      expect(r.index, 5);
      expect(r.result, isA<MissionTimedOut>());
    });
  });
}
