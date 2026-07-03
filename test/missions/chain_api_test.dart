// API tests for `MissionChain` (v1.5-cyc-chain / SYS-145 /
// ADR-076 / WF-073 + v1.6-θ / SYS-153 / ADR-084 / WF-081).
//
// Coverage (5 tests from v1.5-cyc-chain; +2 from v1.6-θ):
//   - `MissionChain.from` wraps as unmodifiable (mutator throws
//     `UnsupportedError`, pinning the `UnmodifiableListView`
//     contract from `lib/missions/chain.dart`).
//   - `MissionChain.empty` has length 0 and is reusable.
//   - `totalTimeout` sums per-mission timeouts (SYS-031
//     max-5-minutes budget).
//   - value equality + hashCode match for identical contents.
//   - `==` returns false when order differs (order-sensitive
//     equality semantics).
//   - v1.6-θ: `totalTimeout` for the empty chain returns
//     `Duration.zero` (boundary invariant — pins the `fold`
//     seed behavior so a future "add a minimum-budget"
//     change cannot silently produce a non-zero empty total).
//   - v1.6-θ: `MissionChain` is iterable in declared order via
//     the inherited `iterator` (cross-cutting invariant — the
//     chain is the canonical iteration target for the Strong-
//     mode executor and any `for`/`fold`/`where` consumer).

import 'package:doit/missions/chain.dart';
import 'package:doit/missions/mission.dart';
import 'package:flutter_test/flutter_test.dart';

const _hold = HoldMission(
  id: 'hold',
  label: 'Hold',
  timeout: Duration(seconds: 5),
  holdDuration: Duration(seconds: 1),
);
const _hold2 = HoldMission(
  id: 'hold2',
  label: 'Hold 2',
  timeout: Duration(seconds: 10),
  holdDuration: Duration(seconds: 2),
);
const _type = TypeMission(
  id: 'type',
  label: 'Type',
  timeout: Duration(seconds: 7),
  expectedPhrase: 'ok',
);

void main() {
  group('MissionChain API', () {
    test('from wraps the source as unmodifiable '
        '(mutator throws UnsupportedError)', () {
      // Arrange — build a chain from a regular List<Mission>.
      final source = <Mission>[_hold, _type];
      final chain = MissionChain.from(source);

      // Act + Assert — `add` on an UnmodifiableListView throws
      // `UnsupportedError` ("Cannot add to an unmodifiable
      // list"). This pins the chain's immutability contract.
      expect(() => chain.add(_hold2), throwsA(isA<UnsupportedError>()));
      expect(() => chain.removeAt(0), throwsA(isA<UnsupportedError>()));
      expect(() => chain[0] = _type, throwsA(isA<UnsupportedError>()));
      // Length is unchanged after each rejected mutation.
      expect(chain.length, 2);
    });

    test('empty has length 0 and is reusable', () {
      // Arrange + Act.
      final a = MissionChain.empty;
      final b = MissionChain.empty;

      // Assert — both references point at the same static
      // instance (the canonical empty sentinel).
      expect(identical(a, b), isTrue);
      expect(a.length, 0);
      expect(a.isEmpty, isTrue);
      expect(a, isEmpty);
    });

    test('totalTimeout sums per-mission timeouts (SYS-031)', () {
      // Arrange — a chain whose per-mission timeouts are
      // 5s + 10s + 7s = 22s. SYS-031 caps the total at
      // 5 minutes; this test pins the SUM behavior
      // independently of the cap.
      final chain = MissionChain.from([_hold, _hold2, _type]);

      // Act + Assert.
      expect(chain.totalTimeout, const Duration(seconds: 22));
    });

    test('value equality + hashCode match for identical contents', () {
      // Arrange — two chains built independently with the same
      // mission contents. They are NOT identical objects but
      // are value-equal.
      final a = MissionChain.from([_hold, _type]);
      final b = MissionChain.from([_hold, _type]);

      // Act + Assert — value equality holds AND hashCodes
      // match (a contract that enables Set<MissionChain> +
      // Map<MissionChain, ...> consumers).
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      // Different list identities — sanity check.
      expect(identical(a, b), isFalse);
    });

    test('== returns false when order differs', () {
      // Arrange — two chains with the same missions in
      // different order. The `==` contract is order-sensitive
      // (chain semantics are ordered; reordering changes the
      // verification sequence).
      final a = MissionChain.from([_hold, _type]);
      final b = MissionChain.from([_type, _hold]);

      // Act + Assert.
      expect(a == b, isFalse);
      // hashCodes MAY collide for non-equal lists — the
      // contract is `equal → equal hash`, not the converse.
      // We do NOT assert hash inequality.
    });

    // ---- v1.6-θ / SYS-153 / ADR-084 / WF-081 ----
    // Cross-cutting invariant checks.
    test('totalTimeout of an empty chain is Duration.zero '
        '(boundary invariant — v1.6-θ)', () {
      // Arrange — the canonical empty singleton and a freshly
      // built empty chain both have zero timeouts to sum.
      final canonical = MissionChain.empty;
      final fromEmpty = MissionChain.from(<Mission>[]);

      // Act + Assert — `fold(Duration.zero, ...)` over an
      // empty list MUST return the seed (no off-by-one in
      // the fold). This pins the boundary behavior so a
      // future refactor that, e.g., seeds with `Duration.zero`
      // but raises on empty, fails loudly here.
      expect(canonical.totalTimeout, Duration.zero);
      expect(fromEmpty.totalTimeout, Duration.zero);
      // Identity check — both empties are length 0, and
      // the canonical singleton is reused.
      expect(canonical.length, 0);
      expect(fromEmpty.length, 0);
    });

    test('iterator yields missions in declared order '
        '(cross-cutting Iterable contract — v1.6-θ)', () {
      // Arrange — a 3-mission chain in a deliberate order.
      // The Strong-mode executor walks the chain in this
      // exact order; a reverse-order bug would be silent in
      // production but visible here.
      final chain = MissionChain.from([_hold, _hold2, _type]);

      // Act — collect via `iterator` (the cross-cutting
      // API every Iterable exposes, including `for-in`).
      final collected = <Mission>[];
      for (final m in chain) {
        collected.add(m);
      }

      // Assert — order matches the input list verbatim.
      expect(collected, equals(<Mission>[_hold, _hold2, _type]));
      // Sanity: `first` / `last` are inherited from
      // UnmodifiableListView and agree with the iteration
      // order. The chain is NOT a Set — it is an
      // ordered list.
      expect(chain.first, _hold);
      expect(chain.last, _type);
      // `contains` is the cross-cutting lookup; same
      // identity check matters because `Mission.==` is the
      // default identity-equal (no override).
      expect(chain.contains(_hold), isTrue);
      expect(chain.contains(_hold2), isTrue);
      expect(chain.contains(_type), isTrue);
    });
  });
}
