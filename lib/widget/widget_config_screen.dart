// Widget configuration picker — shown inside the Android
// AppWidget configuration activity (`DoitWidgetConfigureActivity`)
// when the user binds the do it home widget from the launcher
// (v1.4k / Phase 38 / SYS-125 / ADR-055 / WF-052).
//
// The activity launches the Flutter side with an initial route of
// `/widget-config?widgetId=...` (the activity's `getInitialRoute()`
// encodes the AppWidget id into the query string); the route is
// resolved by `lib/main.dart`'s `onGenerateRoute` to mount this
// widget. The user picks a row; the widget pops with the chosen
// habit id. The Kotlin side then calls
// `WidgetService.setSelectedHabitId(...)` (via the inbound
// `doit/widget` channel) and finishes the activity with
// `RESULT_OK` — the launcher then calls
// `DoitWidgetProvider.onUpdate` for the first time, painting
// the picked do.
//
// Empty-state copy + a "Back to do it" button (the launcher
// hands the activity an `appWidgetId` even when the user has
// zero dos; we cannot rely on the launcher's contract to dismiss
// us, so we close manually with RESULT_CANCELED).
//
// Layer rules (per .claude/rules/lib-screens.md):
//   - StatefulWidget: the screen reads from a service
//     (`DoRepository.instance`) and rebuilds on user picks.
//   - Touch targets ≥ 48dp. Picker rows are `ListTile` (the
//     `Material` default; the per-row tappable area is the
//     `InkWell` inside the tile, sized to the row height).

import 'package:flutter/material.dart';

import 'package:doit/do/do.dart';
import 'package:doit/l10n/gen/app_localizations.dart';
import 'package:doit/services/do_repository.dart';
import 'package:doit/widget/widget_service_proxy.dart';

/// A pure-Dart entry point the screen uses to write the
/// selection + refresh. The default implementation calls
/// [WidgetServiceProxy.setSelectedHabitId] (which routes to
/// `WidgetService.instance.setSelectedHabitId` once the
/// service is initialized). Tests inject a fake via the
/// optional [proxy] parameter.
typedef WidgetConfigPickedCallback = Future<void> Function(String habitId);

class WidgetConfigScreen extends StatefulWidget {
  const WidgetConfigScreen({
    super.key,
    this.widgetId,
    this.proxy = const WidgetServiceProxy(),
  });

  /// The `AppWidgetId` for the widget instance being
  /// configured. Displayed in the AppBar so the user can
  /// distinguish two widget instances during a multi-bind
  /// (the v1.4k scope is single-widget; multi-instance
  /// selection is parked to open_questions OQ-XX). Nullable
  /// for tests.
  final int? widgetId;

  /// Side-effect sink. Defaults to the production
  /// [WidgetServiceProxy] (which forwards to
  /// `WidgetService.instance.setSelectedHabitId`).
  final WidgetServiceProxy proxy;

  @override
  State<WidgetConfigScreen> createState() => _WidgetConfigScreenState();
}

class _WidgetConfigScreenState extends State<WidgetConfigScreen> {
  late Future<List<Do>> _dosFuture;

  @override
  void initState() {
    super.initState();
    // DoRepository.listAll() is a pure Drift read; no
    // init gate. The future resolves in the test fake-async
    // zone the same way the home screen's picker does.
    _dosFuture = DoRepository.instance.listAll();
  }

  Future<void> _onPicked(String habitId) async {
    await widget.proxy.setSelectedHabitId(habitId);
    if (!mounted) return;
    // Pop with the picked id. The Kotlin
    // `DoitWidgetConfigureActivity` reads
    // `setResult(RESULT_OK)` and finishes; the picked
    // habitId is available in the activity's `intent`
    // via the Future<String?> return of Navigator.pop.
    Navigator.of(context).pop<String>(habitId);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.widgetConfigureTitle)),
      body: SafeArea(
        child: FutureBuilder<List<Do>>(
          future: _dosFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final dos = snapshot.data ?? const <Do>[];
            if (dos.isEmpty) {
              return _EmptyState(message: l.widgetConfigureEmptyState);
            }
            return ListView.separated(
              itemCount: dos.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final d = dos[i];
                return _PickerRow(doData: d, onTap: () => _onPicked(d.id));
              },
            );
          },
        ),
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({required this.doData, required this.onTap});

  final Do doData;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      // 56dp min height matches the in-app tile's
      // primary touch target (per .claude/rules/lib-screens.md).
      minVerticalPadding: 16,
      title: Text(doData.name),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_task, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.widgetConfigureBackToHome),
            ),
          ],
        ),
      ),
    );
  }
}
