# integration_test/ — Device E2E flows

This directory houses the **integration tests** for the
`do it` app. Per the Flutter convention, files in this
directory run via `flutter test integration_test/`
against a real Android emulator or physical device, NOT
via the local Dart VM.

## Device-vs-harness split (v1.4-stab-K / Phase 51 / SYS-138)

This test file was authored in the **v1.4-stab-K** cycle.
The CI / local harness has no `adb` binary and no
emulator, so the integration tests **do not execute** in
the harness — they only **compile** under `dart analyze`.

Execution is deferred to the on-device smoke step:

```bash
flutter test integration_test/critical_flows_test.dart \
  --device-id <android-device-id>
```

Or via `flutter drive`:

```bash
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/critical_flows_test.dart
```

The cycle's 3-gate verification (`dart format` +
`flutter analyze --fatal-infos` + `flutter test`)
passes from the model-layer unit tests
(`test/do/`, `test/people/`, `test/events/`,
`test/missions/`) alone.

## The 10 critical flows

1. Add a do (habit)
2. Mark done
3. Streak grows
4. Delete
5. Undo (via v1.4l restore)
6. Soft-delete + list-deleted (via v1.4l tombstone)
7. Restore from list (exercises the Cycle H screen)
8. Backup export
9. Backup restore
10. **PAUSE + edit name + Save preserves pause**
    (BUG-002 regression protector — replaces the
    dropped appcast slot in the original plan)

Flow 10 is the canonical Cycle-B regression protector.
A future contributor who adds `automationsJson: d.automationsJson`
to `_toRow` without the explicit "do not specify for empty
automations" comment will break the BUG-002 invariant and
this flow will catch it.
