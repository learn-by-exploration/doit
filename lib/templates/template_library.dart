// TemplateLibrary — the hand-curated built-in template catalog.
//
// 25 templates across 4 entity types:
//   - do        (the user's "habits" — renamed to "dos")
//   - person    (call/message cadence — relationships)
//   - event     (date-specific reminders)
//   - routine   (location/anchor routine placeholders for Phase F)
//
// The `payloadJson` envelope format is versioned by
// [kTemplateFormatVersion]. A save in [TemplateRepository]
// rejects an envelope whose `k` does not match the current
// version; bump both this file and the version when the schema
// changes.
//
// Per-entity envelope shape (Phase B PR 1 contract):
//   do      → {"k":1,"do":{"scheduleType":...,"weekdays":[...],"hour":HH,"minute":MM,"endHour":HH,"endMinute":MM,"nDays":N,"intervalMinutes":N,"proofMode":"soft","restDaysPerMonth":2,"category":"...","iconName":"...","name":"..."}}
//   person  → {"k":1,"person":{"cadenceType":"...","nDays":N,"weekday":N,"dayOfMonth":N,"monthOfYear":N,"channel":"dialer","name":"..."}}
//   event   → {"k":1,"event":{"recurrence":"monthly|yearly|none","dayOfMonth":N,"monthOfYear":N,"leadTimeMillis":N,"name":"..."}}
//   routine → {"k":1,"routine":{"trigger":"...","condition":"...","action":"...","note":"Phase C+ apply UX"}}
//
// The add screens (Phase B PR 2) read these envelopes. Keep the
// field names stable across PRs.
//
// iconName deviations from the user-facing spec table:
//   - `medication` (templates 2 and 11) is not in the 64-key
//     `DoIcons.keys` set; we use `task_alt` per the fallback
//     rule documented in the Phase B PR 1 spec ("Stick to known
//     keys; if unsure, fall back to `check` or `task_alt`").
//     `DoIcons.resolveFor` will return `task_alt` if the stored
//     string is unknown, so the UI is consistent.
//   - `volume_up` (template 16) is not in the 64-key set; we
//     use `do_not_disturb` (semantically closest: silent mode).
//
// v1.0 reframe (Phase B PR 1).

import 'package:meta/meta.dart';

import 'package:doit/templates/template.dart';

// Imported here only to give the [Template] constants a const
// `createdAt` value. The spec calls for `DateTime.utc(2026, 1, 1)`
// so all built-ins sort deterministically.
//
// `DateTime.utc(...)` is not a const constructor in Dart, so we
// use a `final` field here. The `Template` constructor itself is
// `const`, and the holder is `const`, so the resulting
// `createdAt` reference is itself const-foldable by the
// analyzer.
final DateTime _epoch = DateTime.utc(2026);

@immutable
class TemplateLibrary {
  const TemplateLibrary._();

  /// Bump on every payload-envelope shape change. Bumping
  /// invalidates the user-saved rows that still carry the old
  /// shape; the repository's `save` rejects mismatched `k`
  /// values, forcing the migration path to re-create.
  static const int kTemplateFormatVersion = 1;

  /// The 25 hand-curated templates. Insertion order is the
  /// picker display order. `id` is stable; the `seedBuiltIns`
  /// gate uses `isBuiltIn` to detect first-run.
  ///
  /// `builtIns` is `static final` (not `const`) because the
  /// `createdAt` DateTime is a runtime value (`DateTime.utc`
  /// is not a const constructor). The list itself is
  /// effectively immutable: callers must not mutate it.
  static final List<Template> builtIns = <Template>[
    // -------------------------------------------------------------
    // 1. Drink water — Do, interval, every 2h 08:00–20:00, health.
    Template(
      id: 't_builtin_01',

      name: 'Drink water',
      description: 'One glass every 2 hours, 8am–8pm.',
      iconName: 'local_drink',
      entityType: TemplateEntityType.doEntity,
      isBuiltIn: true,
      createdAt: _epoch,
      payloadJson:
          '{"k":1,"do":{"scheduleType":"interval","weekdays":[1,2,3,4,5,6,7],"hour":8,"minute":0,"endHour":20,"endMinute":0,"nDays":0,"intervalMinutes":120,"proofMode":"soft","restDaysPerMonth":2,"category":"health","iconName":"local_drink","name":"Drink water"}}',
    ),
    // 2. Take medication — Do, fixed 09:00, health.
    //    iconName deviation: 'medication' → 'task_alt' (not in 64-key set).
    Template(
      id: 't_builtin_02',
      name: 'Take medication',
      description: 'Once a day, 9am.',
      iconName: 'task_alt',
      entityType: TemplateEntityType.doEntity,
      isBuiltIn: true,
      createdAt: _epoch,
      payloadJson:
          '{"k":1,"do":{"scheduleType":"fixed","weekdays":[1,2,3,4,5,6,7],"hour":9,"minute":0,"endHour":0,"endMinute":0,"nDays":0,"intervalMinutes":0,"proofMode":"soft","restDaysPerMonth":2,"category":"health","iconName":"task_alt","name":"Take medication"}}',
    ),
    // 3. Stretch / move — Do, interval every 90min 09:00-18:00, health.
    Template(
      id: 't_builtin_03',
      name: 'Stretch / move',
      description: 'A 2-minute stretch every 90 minutes, 9am–6pm.',
      iconName: 'fitness_center',
      entityType: TemplateEntityType.doEntity,
      isBuiltIn: true,
      createdAt: _epoch,
      payloadJson:
          '{"k":1,"do":{"scheduleType":"interval","weekdays":[1,2,3,4,5,6,7],"hour":9,"minute":0,"endHour":18,"endMinute":0,"nDays":0,"intervalMinutes":90,"proofMode":"soft","restDaysPerMonth":2,"category":"health","iconName":"fitness_center","name":"Stretch / move"}}',
    ),
    // 4. 5-min meditation — Do, fixed 07:30, mind.
    Template(
      id: 't_builtin_04',
      name: '5-min meditation',
      description: 'Sit and breathe for five minutes at 7:30am.',
      iconName: 'self_improvement',
      entityType: TemplateEntityType.doEntity,
      isBuiltIn: true,
      createdAt: _epoch,
      payloadJson:
          '{"k":1,"do":{"scheduleType":"fixed","weekdays":[1,2,3,4,5,6,7],"hour":7,"minute":30,"endHour":0,"endMinute":0,"nDays":0,"intervalMinutes":0,"proofMode":"soft","restDaysPerMonth":2,"category":"mind","iconName":"self_improvement","name":"5-min meditation"}}',
    ),
    // 5. Read 20 pages — Do, fixed 21:00, mind.
    Template(
      id: 't_builtin_05',
      name: 'Read 20 pages',
      description: 'Twenty pages before bed, 9pm.',
      iconName: 'menu_book',
      entityType: TemplateEntityType.doEntity,
      isBuiltIn: true,
      createdAt: _epoch,
      payloadJson:
          '{"k":1,"do":{"scheduleType":"fixed","weekdays":[1,2,3,4,5,6,7],"hour":21,"minute":0,"endHour":0,"endMinute":0,"nDays":0,"intervalMinutes":0,"proofMode":"soft","restDaysPerMonth":2,"category":"mind","iconName":"menu_book","name":"Read 20 pages"}}',
    ),
    // 6. Journal — Do, fixed 22:00, mind.
    Template(
      id: 't_builtin_06',
      name: 'Journal',
      description: 'A short journal entry at 10pm.',
      iconName: 'edit_note',
      entityType: TemplateEntityType.doEntity,
      isBuiltIn: true,
      createdAt: _epoch,
      payloadJson:
          '{"k":1,"do":{"scheduleType":"fixed","weekdays":[1,2,3,4,5,6,7],"hour":22,"minute":0,"endHour":0,"endMinute":0,"nDays":0,"intervalMinutes":0,"proofMode":"soft","restDaysPerMonth":2,"category":"mind","iconName":"edit_note","name":"Journal"}}',
    ),
    // 7. Call Mom — Person, weeklyOn Sunday (1..7: 1=Mon, 7=Sun), relationships.
    Template(
      id: 't_builtin_07',
      name: 'Call Mom',
      description: 'A weekly call on Sunday.',
      iconName: 'call',
      entityType: TemplateEntityType.person,
      isBuiltIn: true,
      createdAt: _epoch,
      payloadJson:
          '{"k":1,"person":{"cadenceType":"weekly_on","nDays":0,"weekday":7,"dayOfMonth":0,"monthOfYear":0,"channel":"dialer","name":"Call Mom"}}',
    ),
    // 8. Call Dad — Person, weeklyOn Sunday, relationships.
    Template(
      id: 't_builtin_08',
      name: 'Call Dad',
      description: 'A weekly call on Sunday.',
      iconName: 'call',
      entityType: TemplateEntityType.person,
      isBuiltIn: true,
      createdAt: _epoch,
      payloadJson:
          '{"k":1,"person":{"cadenceType":"weekly_on","nDays":0,"weekday":7,"dayOfMonth":0,"monthOfYear":0,"channel":"dialer","name":"Call Dad"}}',
    ),
    // 9. Catch up with a friend — Person, everyNDays(7), relationships.
    Template(
      id: 't_builtin_09',
      name: 'Catch up with a friend',
      description: 'Reach out to one friend every 7 days.',
      iconName: 'group',
      entityType: TemplateEntityType.person,
      isBuiltIn: true,
      createdAt: _epoch,
      payloadJson:
          '{"k":1,"person":{"cadenceType":"every_n_days","nDays":7,"weekday":0,"dayOfMonth":0,"monthOfYear":0,"channel":"dialer","name":"Catch up with a friend"}}',
    ),
    // 10. Reply to unread messages — Do, dayOfX(weekday=1 Mon), productivity.
    //     dayOfX(weekday=1): "on the 1st Monday of the month". But spec says
    //     "weekday" — interpreted as "every Monday". Encode via scheduleType
    //     "fixed" with weekdays=1 to keep the envelope parseable. Day-of-X
    //     semantics land in Phase D; this is a placeholder that won't fire
    //     oddly.
    Template(
      id: 't_builtin_10',
      name: 'Reply to unread messages',
      description: 'Clear the inbox once a week, on Monday.',
      iconName: 'chat',
      entityType: TemplateEntityType.doEntity,
      isBuiltIn: true,
      createdAt: _epoch,
      payloadJson:
          '{"k":1,"do":{"scheduleType":"fixed","weekdays":[1],"hour":10,"minute":0,"endHour":0,"endMinute":0,"nDays":0,"intervalMinutes":0,"proofMode":"soft","restDaysPerMonth":2,"category":"productivity","iconName":"chat","name":"Reply to unread messages"}}',
    ),
    // 11. Take vitamins — Do, fixed 08:00, health.
    //     iconName deviation: 'medication' → 'task_alt' (not in 64-key set).
    Template(
      id: 't_builtin_11',
      name: 'Take vitamins',
      description: 'Once a day, 8am.',
      iconName: 'task_alt',
      entityType: TemplateEntityType.doEntity,
      isBuiltIn: true,
      createdAt: _epoch,
      payloadJson:
          '{"k":1,"do":{"scheduleType":"fixed","weekdays":[1,2,3,4,5,6,7],"hour":8,"minute":0,"endHour":0,"endMinute":0,"nDays":0,"intervalMinutes":0,"proofMode":"soft","restDaysPerMonth":2,"category":"health","iconName":"task_alt","name":"Take vitamins"}}',
    ),
    // 12. Stand-up desk break — Do, interval 50min 09:00-18:00, productivity.
    Template(
      id: 't_builtin_12',
      name: 'Stand-up desk break',
      description: 'Stand up and move for 2 min every 50 min, 9am–6pm.',
      iconName: 'repeat',
      entityType: TemplateEntityType.doEntity,
      isBuiltIn: true,
      createdAt: _epoch,
      payloadJson:
          '{"k":1,"do":{"scheduleType":"interval","weekdays":[1,2,3,4,5,6,7],"hour":9,"minute":0,"endHour":18,"endMinute":0,"nDays":0,"intervalMinutes":50,"proofMode":"soft","restDaysPerMonth":2,"category":"productivity","iconName":"repeat","name":"Stand-up desk break"}}',
    ),
    // 13. Walk 10k steps — Do, interval every day, health.
    Template(
      id: 't_builtin_13',
      name: 'Walk 10k steps',
      description: 'A daily 10,000-step check-in.',
      iconName: 'directions_walk',
      entityType: TemplateEntityType.doEntity,
      isBuiltIn: true,
      createdAt: _epoch,
      payloadJson:
          '{"k":1,"do":{"scheduleType":"interval","weekdays":[1,2,3,4,5,6,7],"hour":9,"minute":0,"endHour":21,"endMinute":0,"nDays":0,"intervalMinutes":0,"proofMode":"soft","restDaysPerMonth":2,"category":"health","iconName":"directions_walk","name":"Walk 10k steps"}}',
    ),
    // 14. Bedtime wind-down — Do, fixed 21:30, mind.
    Template(
      id: 't_builtin_14',
      name: 'Bedtime wind-down',
      description: 'Lights out and screens off at 9:30pm.',
      iconName: 'bedtime',
      entityType: TemplateEntityType.doEntity,
      isBuiltIn: true,
      createdAt: _epoch,
      payloadJson:
          '{"k":1,"do":{"scheduleType":"fixed","weekdays":[1,2,3,4,5,6,7],"hour":21,"minute":30,"endHour":0,"endMinute":0,"nDays":0,"intervalMinutes":0,"proofMode":"soft","restDaysPerMonth":2,"category":"mind","iconName":"bedtime","name":"Bedtime wind-down"}}',
    ),
    // 15. "I'm up" wake-up — Do, anchor, mind.
    //     Anchor targetDoId is empty; the add screen fills it.
    Template(
      id: 't_builtin_15',
      name: '"I\'m up" wake-up',
      description: 'Tap when you wake up; anchors morning habits.',
      iconName: 'wb_sunny',
      entityType: TemplateEntityType.doEntity,
      isBuiltIn: true,
      createdAt: _epoch,
      payloadJson:
          '{"k":1,"do":{"scheduleType":"anchor","weekdays":[],"hour":7,"minute":0,"endHour":0,"endMinute":0,"nDays":0,"intervalMinutes":0,"proofMode":"soft","restDaysPerMonth":2,"category":"mind","iconName":"wb_sunny","name":"I\'m up wake-up"}}',
    ),
    // 16. Japan silent mode — Routine placeholder, relationships.
    //     iconName deviation: 'volume_up' → 'do_not_disturb' (silent-mode
    //     semantics).
    Template(
      id: 't_builtin_16',
      name: 'Japan silent mode',
      description: 'Phone goes silent when crossing into Japan.',
      iconName: 'do_not_disturb',
      entityType: TemplateEntityType.routine,
      isBuiltIn: true,
      createdAt: _epoch,
      payloadJson:
          '{"k":1,"routine":{"trigger":"location","condition":"enter_country:JP","action":"set_ringer:silent","note":"Phase C+ apply UX"}}',
    ),
    // 17. Focus block — Routine placeholder, productivity.
    Template(
      id: 't_builtin_17',
      name: 'Focus block',
      description: 'When a focus block starts, silence notifications.',
      iconName: 'work',
      entityType: TemplateEntityType.routine,
      isBuiltIn: true,
      createdAt: _epoch,
      payloadJson:
          '{"k":1,"routine":{"trigger":"calendar","condition":"event:FocusBlock","action":"dn:on","note":"Phase C+ apply UX"}}',
    ),
    // 18. Working from home — Routine placeholder, productivity.
    Template(
      id: 't_builtin_18',
      name: 'Working from home',
      description: 'When you arrive home on a weekday, enable WFH mode.',
      iconName: 'home',
      entityType: TemplateEntityType.routine,
      isBuiltIn: true,
      createdAt: _epoch,
      payloadJson:
          '{"k":1,"routine":{"trigger":"location","condition":"enter:home;weekday","action":"profile:wfh","note":"Phase C+ apply UX"}}',
    ),
    // 19. At the gym — Routine placeholder, health.
    Template(
      id: 't_builtin_19',
      name: 'At the gym',
      description: 'When you arrive at the gym, start a workout timer.',
      iconName: 'fitness_center',
      entityType: TemplateEntityType.routine,
      isBuiltIn: true,
      createdAt: _epoch,
      payloadJson:
          '{"k":1,"routine":{"trigger":"location","condition":"enter:gym","action":"timer:workout","note":"Phase C+ apply UX"}}',
    ),
    // 20. Leaving work — Routine placeholder, productivity.
    Template(
      id: 't_builtin_20',
      name: 'Leaving work',
      description: 'When you leave work, remind you to log the day.',
      iconName: 'directions_walk',
      entityType: TemplateEntityType.routine,
      isBuiltIn: true,
      createdAt: _epoch,
      payloadJson:
          '{"k":1,"routine":{"trigger":"location","condition":"exit:work","action":"remind:log_day","note":"Phase C+ apply UX"}}',
    ),
    // 21. Meeting prep — Routine placeholder, productivity.
    Template(
      id: 't_builtin_21',
      name: 'Meeting prep',
      description: '15 min before a meeting, show the agenda.',
      iconName: 'event',
      entityType: TemplateEntityType.routine,
      isBuiltIn: true,
      createdAt: _epoch,
      payloadJson:
          '{"k":1,"routine":{"trigger":"calendar","condition":"event:meeting;-15min","action":"show:agenda","note":"Phase C+ apply UX"}}',
    ),
    // 22. Pay rent reminder — Event, monthlyOn 1st, productivity.
    Template(
      id: 't_builtin_22',
      name: 'Pay rent reminder',
      description: 'Reminder on the 1st of every month.',
      iconName: 'savings',
      entityType: TemplateEntityType.event,
      isBuiltIn: true,
      createdAt: _epoch,
      payloadJson:
          '{"k":1,"event":{"recurrence":"monthly","dayOfMonth":1,"monthOfYear":0,"leadTimeMillis":86400000,"name":"Pay rent reminder"}}',
    ),
    // 23. Birthday reminder — Event, yearlyOn, relationships.
    Template(
      id: 't_builtin_23',
      name: 'Birthday reminder',
      description: 'Annual reminder, lead 1 day.',
      iconName: 'cake',
      entityType: TemplateEntityType.event,
      isBuiltIn: true,
      createdAt: _epoch,
      payloadJson:
          '{"k":1,"event":{"recurrence":"yearly","dayOfMonth":0,"monthOfYear":0,"leadTimeMillis":86400000,"name":"Birthday reminder"}}',
    ),
    // 24. Renew passport — Event, date-specific + lead 1 week (604800000 ms).
    Template(
      id: 't_builtin_24',
      name: 'Renew passport',
      description: 'One-off reminder, lead 1 week.',
      iconName: 'edit_note',
      entityType: TemplateEntityType.event,
      isBuiltIn: true,
      createdAt: _epoch,
      payloadJson:
          '{"k":1,"event":{"recurrence":"none","dayOfMonth":0,"monthOfYear":0,"leadTimeMillis":604800000,"name":"Renew passport"}}',
    ),
    // 25. Doctor appointment — Event, date-specific + lead 1 day (86400000 ms).
    Template(
      id: 't_builtin_25',
      name: 'Doctor appointment',
      description: 'One-off reminder, lead 1 day.',
      iconName: 'today',
      entityType: TemplateEntityType.event,
      isBuiltIn: true,
      createdAt: _epoch,
      payloadJson:
          '{"k":1,"event":{"recurrence":"none","dayOfMonth":0,"monthOfYear":0,"leadTimeMillis":86400000,"name":"Doctor appointment"}}',
    ),
  ];

  /// Idempotently seeds the built-in library into [repo].
  /// Returns the count of rows newly inserted. If any built-in
  /// already exists, the call is a no-op (returns 0).
  ///
  /// The caller is responsible for invoking this once at app
  /// startup (typically from `main.dart` after the
  /// `AppDatabaseService.init()` future resolves). The migration
  /// creates the table but does NOT auto-seed; seeding belongs
  /// in the app-init path so the user can wipe the library
  /// without touching the migration history.
  ///
  /// TODO Phase B PR 2: wire this from `main.dart` /
  /// `AppDatabaseService.init()`.
  static Future<int> seedBuiltIns(TemplateImportRepository repo) async {
    final existing = await repo.listAll(builtInOnly: true);
    if (existing.isNotEmpty) return 0;
    var inserted = 0;
    for (final t in builtIns) {
      await repo.save(t);
      inserted++;
    }
    return inserted;
  }
}

/// Minimal interface used by [TemplateLibrary.seedBuiltIns] to
/// keep the library decoupled from `TemplateRepository`. The
/// repository implements this implicitly via `save` / `listAll`.
/// Defined here (not in the repository file) so the library has
/// no upward dependency on the service layer.
abstract class TemplateImportRepository {
  Future<void> save(Template t);
  Future<List<Template>> listAll({
    TemplateEntityType? entityType,
    bool builtInOnly = false,
  });
}
