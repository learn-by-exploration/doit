# `lib/people/**` — Person model and contact resolution

## Model purity

Files in `lib/people/` MUST NOT import `package:flutter/*`. The
person model and cadence engine are pure Dart so they are
testable without a Flutter test harness.

**Exception:** `lib/people/contact_picker_screen.dart` is the
only file that imports Flutter. It wraps the platform's contact
picker UI.

## Sealed hierarchy

- `Person` is a sealed class.
- `PersonChannel` is a sealed class with `ChannelDialer`,
  `ChannelWhatsApp`, `ChannelTelegram`, `ChannelSignal`,
  `ChannelSms`. Add a new channel by adding a new subclass, not
  by editing an enum.

## Contact resolution

- `PersonResolver` (a service in `lib/services/`) takes a
  `PersonId` and returns a `PersonSnapshot` with display name,
  channel handle, and a "still resolvable" flag.
- The resolver caches resolutions in the local DB. It re-resolves
  on a debounced timer (every 24 h) or immediately on
  `ContactsContract.Contacts#CONTENT_URI` change broadcast.
- A person whose underlying contact was deleted is marked
  `PersonUnresolved`. The user is shown a banner; the cadence
  habit is paused; archiving or picking a new person resumes it.

## Cadence

- `PersonCadence` is a sealed class with `EveryNDays(n)`,
  `WeeklyOn(dayOfWeek)`, `MonthlyOn(dayOfMonth)`,
  `YearlyOn(month, day)`. Add a new cadence shape by adding a
  new subclass.
- `DateTime nextOccurrence(DateTime from)` is pure, like the
  habit schedule engine.

## Privacy

- The app does not store the contact's full vCard. It stores
  the lookup key (a stable hash of the contact URI), the
  display name (cached), and the channel handle.
- If the user uninstalls the app, the lookup keys are
  useless — the next install will rebuild the cache from a
  fresh `READ_CONTACTS` read.
- The `READ_CONTACTS` permission is requested with a rationale
  screen that says "used only to resolve names you have
  chosen to add to a cadence". The rationale text lives in
  `lib/people/permission_rationale.dart`.

## Forbidden patterns

- No bulk contact import. The user picks contacts explicitly,
  one at a time or in a multi-select.
- No automatic syncing of all contacts into the local DB. The
  DB only contains the contacts the user has added to a
  cadence.
- No `READ_CALL_LOG`. Cadence is configured manually or
  per-person, not derived from the call log.

## Tests

- `test/people/person_resolver_test.dart` — happy path,
  contact-deleted path, channel-app-not-installed path.
- `test/people/cadence_test.dart` — every cadence shape,
  edge cases (Feb 29, end-of-month, end-of-year).
- `test/people/person_model_test.dart` — immutability of
  `channel` after creation.
- 80%+ coverage on changed files.

## When changing this folder

- Update the matching SYS- IDs.
- If a new channel is added, append an ADR and update
  [`docs/v_model/architecture_options.md`](../../docs/v_model/architecture_options.md).
- If the privacy boundary changes (e.g., a new permission),
  the PR is blocked until the change is reviewed.
