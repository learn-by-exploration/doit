// Tests for MissionInput / MissionResult / MathProblem / MemoryGame.
//
// v1.4-stab-K (Phase 51 / SYS-138 / ADR-069 / WF-066): the
// model-layer direct unit tests for `lib/missions/mission_input.dart`
// and `lib/missions/mission_result.dart` that bring the files to
// 100% line coverage.

import 'dart:math' as math;

import 'package:doit/missions/mission.dart';
import 'package:doit/missions/mission_input.dart';
import 'package:doit/missions/mission_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShakeSample.magnitude', () {
    test('magnitude = sqrt(x² + y² + z²)', () {
      final s = ShakeSample(x: 3, y: 4, z: 0, at: DateTime(2026, 1, 15));
      expect(s.magnitude, 5.0); // classic 3-4-5 triangle
    });

    test('magnitude is non-negative for any sample', () {
      final s = ShakeSample(x: -1, y: -2, z: -3, at: DateTime(2026, 1, 15));
      expect(s.magnitude, greaterThan(0));
    });

    test('zero sample yields magnitude 0', () {
      final s = ShakeSample(x: 0, y: 0, z: 0, at: DateTime(2026, 1, 15));
      expect(s.magnitude, 0.0);
    });
  });

  group('MathProblem.next (deterministic seed)', () {
    test('easy add problem has non-negative answer', () {
      final rng = math.Random(42);
      final p = MathProblem.next(MathDifficulty.easy, rng);
      expect(p.op, MathOp.add);
      expect(p.answer, p.a + p.b);
      expect(p.answer, greaterThan(0));
    });

    test('subtract problems never produce negative results', () {
      final rng = math.Random(7);
      for (var i = 0; i < 50; i++) {
        final p = MathProblem.next(MathDifficulty.normal, rng);
        if (p.op == MathOp.subtract) {
          expect(p.answer, greaterThanOrEqualTo(0));
          expect(p.answer, p.a - p.b);
        }
      }
    });

    test('hard problems include multiply', () {
      final rng = math.Random(123);
      var sawMultiply = false;
      for (var i = 0; i < 100; i++) {
        final p = MathProblem.next(MathDifficulty.hard, rng);
        if (p.op == MathOp.multiply) sawMultiply = true;
        if (p.op == MathOp.add) {
          expect(p.answer, p.a + p.b);
        } else if (p.op == MathOp.subtract) {
          expect(p.answer, p.a - p.b);
        } else if (p.op == MathOp.multiply) {
          expect(p.answer, p.a * p.b);
        }
      }
      expect(
        sawMultiply,
        isTrue,
        reason: 'hard difficulty must include multiply',
      );
    });
  });

  group('MemoryGame.generate', () {
    test('returns rows*cols cards in unmodifiable list', () {
      final cards = MemoryGame.generate(
        rows: 2,
        cols: 2,
        theme: 'shapes',
        seed: 1,
      );
      expect(cards, hasLength(4));
      expect(
        () => cards.add(const MemoryCard(symbol: 'X', pairId: 999)),
        throwsUnsupportedError,
      );
    });

    test('pairs are matched (each pairId appears exactly twice)', () {
      final cards = MemoryGame.generate(
        rows: 2,
        cols: 4,
        theme: 'animals',
        seed: 7,
      );
      final counts = <int, int>{};
      for (final c in cards) {
        counts[c.pairId] = (counts[c.pairId] ?? 0) + 1;
      }
      for (final entry in counts.entries) {
        expect(
          entry.value,
          2,
          reason: 'pairId ${entry.key} should appear exactly twice',
        );
      }
    });

    test('deterministic: same seed produces same order', () {
      final a = MemoryGame.generate(
        rows: 2,
        cols: 4,
        theme: 'fruits',
        seed: 99,
      );
      final b = MemoryGame.generate(
        rows: 2,
        cols: 4,
        theme: 'fruits',
        seed: 99,
      );
      final aSymbols = a.map((c) => '${c.pairId}:${c.symbol}').toList();
      final bSymbols = b.map((c) => '${c.pairId}:${c.symbol}').toList();
      expect(aSymbols, equals(bSymbols));
    });

    test('unknown theme falls back to shapes', () {
      final cards = MemoryGame.generate(
        rows: 2,
        cols: 2,
        theme: 'unknown-theme',
        seed: 3,
      );
      // The shapes pool symbols are ▲, ●, ■, ◆, ★, ♥, ♦, ♣.
      expect(
        cards.any((c) => c.symbol == '▲'),
        isTrue,
        reason: 'unknown theme should fall back to shapes pool',
      );
    });
  });

  group('MissionResult + MissionChainResult', () {
    test('MissionPassed carries optional detail', () {
      const r = MissionPassed(detail: 'ok');
      expect(r.detail, 'ok');
    });

    test('MissionFailed carries a reason', () {
      const r = MissionFailed('boom');
      expect(r.reason, 'boom');
    });

    test('ChainPassed exposes the per-mission results', () {
      const r = ChainPassed(<MissionResult>[
        MissionPassed(),
        MissionFailed('nope'),
      ]);
      expect(r.results, hasLength(2));
    });

    test('ChainFailedAt exposes the failure index + result', () {
      const r = ChainFailedAt(index: 2, result: MissionFailed('nope'));
      expect(r.index, 2);
      expect(r.result, isA<MissionFailed>());
    });

    test('ChainTimedOut is a ChainFailedAt with MissionTimedOut result', () {
      const r = ChainTimedOut(index: 1);
      expect(r.index, 1);
      expect(r.result, isA<MissionTimedOut>());
    });
  });

  group('MathOp enum coverage', () {
    test('enum has exactly 3 values', () {
      expect(MathOp.values, hasLength(3));
      expect(
        MathOp.values,
        containsAll(<MathOp>[MathOp.add, MathOp.subtract, MathOp.multiply]),
      );
    });
  });

  // Reference ShakeMission to ensure the import is preserved.
  test('ShakeMission can be constructed with targetCount', () {
    const m = ShakeMission(
      id: 'm1',
      label: 'Shake 5x',
      timeout: Duration(minutes: 1),
      targetCount: 5,
    );
    expect(m.targetCount, 5);
  });
}
