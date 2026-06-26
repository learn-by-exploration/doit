// Unit tests for firstActiveDo locator (v1.4a / Phase 28 /
// SYS-115 / ADR-045 / WF-042).
//
// Coverage:
//   - returns the first-active do (oldest createdAt) when
//     the list contains multiple non-paused dos
//   - skips paused dos
//   - returns null on empty repository
//   - returns null when every do is paused

import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/services/do_repository.dart';
import 'package:doit/widget/widget_state_locator.dart';
import 'package:flutter_test/flutter_test.dart';

Do _fixed(
  String id,
  String name, {
  required DateTime createdAt,
  DateTime? pausedUntil,
}) {
  return DoFixed(
    id: id,
    name: name,
    proofMode: const SoftProof(),
    createdAt: createdAt,
    restDaysPerMonth: 2,
    weekdays: const <int>{1, 2, 3, 4, 5, 6, 7},
    time: const DoTime(9, 0),
    pausedUntil: pausedUntil,
  );
}

class _FakeRepo implements DoRepository {
  final List<Do> dos;
  _FakeRepo(this.dos);

  @override
  Future<List<Do>> listAll() async => dos;

  @override
  Future<Do?> getById(String id) async {
    for (final d in dos) {
      if (d.id == id) return d;
    }
    return null;
  }

  @override
  Future<void> save(Do d) async {}

  @override
  Future<void> deleteById(String id) async {}

  @override
  Future<List<Do>> listActive(DateTime now) async => dos;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('returns the first-active do (oldest createdAt)', () async {
    final repo = _FakeRepo(<Do>[
      _fixed('a', 'Walk', createdAt: DateTime(2026, 5, 17, 10)),
      _fixed('b', 'Read', createdAt: DateTime(2026, 5, 15, 10)),
      _fixed('c', 'Stretch', createdAt: DateTime(2026, 5, 16, 10)),
    ]);

    final result = await firstActiveDo(repository: repo);
    expect(result!.id, 'b');
  });

  test('skips paused dos', () async {
    final repo = _FakeRepo(<Do>[
      _fixed('a', 'Walk', createdAt: DateTime(2026, 5, 17, 10)),
      _fixed(
        'b',
        'Read',
        createdAt: DateTime(2026, 5, 15, 10),
        pausedUntil: DateTime(2026, 7, 15),
      ),
    ]);

    final result = await firstActiveDo(
      repository: repo,
      now: DateTime(2026, 6, 15),
    );
    expect(result!.id, 'a');
  });

  test('returns null on empty repository', () async {
    final repo = _FakeRepo(<Do>[]);
    expect(await firstActiveDo(repository: repo), isNull);
  });

  test('returns null when every do is paused', () async {
    final repo = _FakeRepo(<Do>[
      _fixed(
        'a',
        'Walk',
        createdAt: DateTime(2026, 5, 15, 10),
        pausedUntil: DateTime(2026, 7, 15),
      ),
    ]);
    expect(
      await firstActiveDo(repository: repo, now: DateTime(2026, 6, 15)),
      isNull,
    );
  });
}
