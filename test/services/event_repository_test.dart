// Tests for EventRepository (WF-017).

import 'package:common_games/events/event.dart';
import 'package:common_games/services/db.dart';
import 'package:common_games/services/db/schema.dart';
import 'package:common_games/services/event_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    await AppDatabaseService.instance.closeForTesting();
    db = AppDatabase(NativeDatabase.memory());
    await AppDatabaseService.instance.init(overrideDb: db);
    await AppDatabaseService.instance.ready;
  });

  tearDown(() async {
    await AppDatabaseService.instance.closeForTesting();
  });

  Event _event({
    String id = 'e1',
    String name = 'Doctor',
    int atMillis = 1735689600000,
    int leadTimeMillis = 900000,
    EventRecurrence recurrence = EventRecurrence.none,
  }) {
    return Event(
      id: id,
      name: name,
      atMillis: atMillis,
      leadTimeMillis: leadTimeMillis,
      createdAtMillis: DateTime.now().millisecondsSinceEpoch,
      recurrence: recurrence,
    );
  }

  test('save + getById round-trips', () async {
    await EventRepository.instance.save(_event());
    final got = await EventRepository.instance.getById('e1');
    expect(got, isNotNull);
    expect(got!.name, 'Doctor');
    expect(got.atMillis, 1735689600000);
    expect(got.leadTimeMillis, 900000);
  });

  test('listActive returns non-archived, sorted by atMillis asc', () async {
    await EventRepository.instance.save(_event(id: 'e1', atMillis: 2000));
    await EventRepository.instance.save(_event(id: 'e2', atMillis: 1000));
    await EventRepository.instance.save(_event(id: 'e3', atMillis: 3000));
    final events = await EventRepository.instance.listActive();
    expect(events.map((e) => e.id).toList(), ['e2', 'e1', 'e3']);
  });

  test('listActive excludes archived events', () async {
    await EventRepository.instance.save(_event(id: 'e1'));
    await EventRepository.instance.save(_event(id: 'e2'));
    await EventRepository.instance.archive('e2', DateTime.now());
    final events = await EventRepository.instance.listActive();
    expect(events.map((e) => e.id).toList(), ['e1']);
  });

  test('listPendingArchive returns fired-but-not-archived', () async {
    final now = DateTime.now();
    await EventRepository.instance.save(
      _event(id: 'past', atMillis: now.millisecondsSinceEpoch - 10000),
    );
    await EventRepository.instance.save(
      _event(id: 'future', atMillis: now.millisecondsSinceEpoch + 60000),
    );
    final pending = await EventRepository.instance.listPendingArchive(now);
    expect(pending.map((e) => e.id).toList(), ['past']);
  });

  test('archive sets archivedAtMillis', () async {
    await EventRepository.instance.save(_event(id: 'e1'));
    final before = DateTime.now();
    await EventRepository.instance.archive('e1', before);
    final got = await EventRepository.instance.getById('e1');
    expect(got!.archivedAtMillis, isNotNull);
  });

  test('deleteById removes the row', () async {
    await EventRepository.instance.save(_event(id: 'e1'));
    await EventRepository.instance.deleteById('e1');
    final got = await EventRepository.instance.getById('e1');
    expect(got, isNull);
  });

  test('save persists recurrence enum correctly', () async {
    await EventRepository.instance.save(
      _event(id: 'e1', recurrence: EventRecurrence.annually),
    );
    final got = await EventRepository.instance.getById('e1');
    expect(got!.recurrence, EventRecurrence.annually);
  });

  test('save validates the event', () async {
    expect(
      () => EventRepository.instance.save(
        const Event(
          id: 'e1',
          name: '   ',
          atMillis: 1,
          leadTimeMillis: 0,
          createdAtMillis: 0,
        ),
      ),
      throwsA(isA<EventNameEmpty>()),
    );
  });
}
