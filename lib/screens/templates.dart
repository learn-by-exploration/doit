// Templates catalog screen — the user picks a curated template
// to bootstrap a new do / event / person. Routine templates
// are visible but disabled with a "Coming in v1.1" badge
// (the apply UX lands in Phase C+).
//
// Per WF-032 (Phase B PR 2). Backed by
// [TemplateRepository.instance.listAll] and seeded on first
// run via [TemplateLibrary.seedBuiltIns] (idempotent).
//
// Touch targets: cards are >= 48dp tall; the "Use this" button
// follows the existing AppBar-action pattern. All copy stays
// in the brand voice: action-led, no shame, no marketing fluff.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:doit/do/category.dart';
import 'package:doit/screens/add_event.dart';
import 'package:doit/screens/add_habit.dart';
import 'package:doit/screens/add_person.dart';
import 'package:doit/screens/add_routine.dart';
import 'package:doit/services/template_repository.dart';
import 'package:doit/templates/template.dart';
import 'package:doit/templates/template_library.dart';
import 'package:doit/theme/app_theme.dart';

/// The entity-type filter chip selected at the top of the
/// catalog. `all` shows every template; the rest filter by
/// [TemplateEntityType.tag].
enum _TemplateFilter { all, doEntity, event, person, routine }

extension on _TemplateFilter {
  String get label {
    switch (this) {
      case _TemplateFilter.all:
        return 'All';
      case _TemplateFilter.doEntity:
        return 'Do';
      case _TemplateFilter.event:
        return 'Event';
      case _TemplateFilter.person:
        return 'Person';
      case _TemplateFilter.routine:
        return 'Routine';
    }
  }

  /// The matching `entityType` for non-`all` filters.
  TemplateEntityType? get entityType {
    switch (this) {
      case _TemplateFilter.all:
        return null;
      case _TemplateFilter.doEntity:
        return TemplateEntityType.doEntity;
      case _TemplateFilter.event:
        return TemplateEntityType.event;
      case _TemplateFilter.person:
        return TemplateEntityType.person;
      case _TemplateFilter.routine:
        return TemplateEntityType.routine;
    }
  }
}

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  Future<List<Template>>? _future;
  _TemplateFilter _filter = _TemplateFilter.all;

  @override
  void initState() {
    super.initState();
    // Seed built-ins (idempotent) and load the catalog. The
    // seed must finish BEFORE listAll to guarantee the 25
    // built-ins are present on first run.
    _future = _seedAndLoad();
  }

  Future<List<Template>> _seedAndLoad() async {
    await TemplateLibrary.seedBuiltIns(TemplateRepository.instance);
    return TemplateRepository.instance.listAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Templates')),
      body: SafeArea(
        child: Column(
          children: [
            _FilterBar(
              active: _filter,
              onChanged: (f) => setState(() => _filter = f),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<List<Template>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return _ErrorView(
                      message: 'Could not load templates',
                      onRetry: () => setState(() {
                        _future = _seedAndLoad();
                      }),
                    );
                  }
                  final all = snap.data ?? <Template>[];
                  final filtered = _filter == _TemplateFilter.all
                      ? all
                      : all
                            .where((t) => t.entityType == _filter.entityType)
                            .toList(growable: false);
                  if (filtered.isEmpty) {
                    return const _EmptyView();
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.all(Spacing.md),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: Spacing.md,
                          crossAxisSpacing: Spacing.md,
                          childAspectRatio: 0.95,
                        ),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _TemplateCard(template: filtered[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.active, required this.onChanged});

  final _TemplateFilter active;
  final ValueChanged<_TemplateFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
        children: [
          for (final f in _TemplateFilter.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
              child: FilterChip(
                key: ValueKey('templates.filter.${f.name}'),
                label: Text(f.label),
                selected: f == active,
                onSelected: (v) {
                  if (v) onChanged(f);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template});

  final Template template;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('template_card.${template.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _onUse(context),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _iconFor(template),
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                template.name,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: Spacing.xs),
              Expanded(
                child: Text(
                  template.description,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              _TrailingAction(template: template, onUse: () => _onUse(context)),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(Template t) {
    // The template's iconName is one of the 64 keys; fall
    // back to the category-default for the most common
    // entity type. The icon picker is the single source of
    // truth for the visual identity.
    final key = DoIcons.resolveFor(
      category: DoCategory.other,
      iconName: t.iconName,
    );
    return _kIconMap[key] ?? Icons.check;
  }

  Future<void> _onUse(BuildContext context) async {
    final t = template;
    // Phase F PR 2 (SYS-075): template #16 ("Japan silent
    // mode") routes to the dedicated AddRoutineScreen instead
    // of the generic routine snackbar. Every other routine
    // template (17..21) keeps the v1.1 badge + snackbar.
    if (t.id == 't_builtin_16') {
      if (!context.mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const AddRoutineScreen()));
      return;
    }
    switch (t.entityType) {
      case TemplateEntityType.doEntity:
        final payload = _payloadFor(t, 'do');
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AddHabitScreen(initialPayload: payload),
          ),
        );
      case TemplateEntityType.person:
        final payload = _payloadFor(t, 'person');
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AddPersonScreen(initialPayload: payload),
          ),
        );
      case TemplateEntityType.event:
        final payload = _payloadFor(t, 'event');
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AddEventScreen(initialPayload: payload),
          ),
        );
      case TemplateEntityType.routine:
        // Routine apply UX lands in Phase C+; routine
        // templates render the "Coming in v1.1" badge
        // and the tap is a no-op.
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Routines land in v1.1.')));
    }
  }

  /// Decode the template's `payloadJson` and return the inner
  /// map for [envelopeKey]. Returns `null` when the envelope
  /// is malformed — the screen falls back to a blank add
  /// form, matching the behavior the repository guarantees
  /// for built-ins (validate at save time, tolerate at
  /// apply time).
  Map<String, dynamic>? _payloadFor(Template t, String envelopeKey) {
    try {
      final parsed = jsonDecode(t.payloadJson);
      if (parsed is! Map<String, dynamic>) return null;
      final inner = parsed[envelopeKey];
      if (inner is! Map<String, dynamic>) return null;
      return inner;
    } on FormatException catch (e) {
      if (kDebugMode) {
        debugPrint('TemplatesScreen: bad envelope for ${t.id}: $e');
      }
      return null;
    }
  }
}

class _TrailingAction extends StatelessWidget {
  const _TrailingAction({required this.template, required this.onUse});

  final Template template;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    // Phase F PR 2 (SYS-075): template #16 has a real apply
    // UX (the AddRoutineScreen) — suppress the "Coming in
    // v1.1" badge and render the "Use this" button instead.
    if (template.id == 't_builtin_16') {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.tonal(
          key: ValueKey('template_card.${template.id}.use'),
          onPressed: onUse,
          child: const Text('Use this'),
        ),
      );
    }
    if (template.entityType == TemplateEntityType.routine) {
      return Container(
        key: ValueKey('template_card.${template.id}.coming_soon'),
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.xs,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Coming in v1.1',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton.tonal(
        key: ValueKey('template_card.${template.id}.use'),
        onPressed: onUse,
        child: const Text('Use this'),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Text(
          'No templates for this filter.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: Spacing.md),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

/// Inline copy of the 64-key icon map. Mirrors the lookup in
/// `lib/screens/home.dart:486-548` and `add_habit.dart` so the
/// catalog screen does not pull in the picker. The map is
/// intentionally duplicated (the picker is the source of
/// truth, but the picker is a widget, not a data structure);
/// the alternative is a global static, which is a layering
/// violation (widgets importing each other for a static).
const Map<String, IconData> _kIconMap = <String, IconData>{
  'local_drink': Icons.local_drink,
  'directions_run': Icons.directions_run,
  'fitness_center': Icons.fitness_center,
  'self_improvement': Icons.self_improvement,
  'bedtime': Icons.bedtime,
  'wb_sunny': Icons.wb_sunny,
  'restaurant': Icons.restaurant,
  'local_fire_department': Icons.local_fire_department,
  'spa': Icons.spa,
  'air': Icons.air,
  'menu_book': Icons.menu_book,
  'edit_note': Icons.edit_note,
  'psychology_alt': Icons.psychology_alt,
  'lightbulb': Icons.lightbulb,
  'auto_stories': Icons.auto_stories,
  'call': Icons.call,
  'chat': Icons.chat,
  'mail': Icons.mail,
  'group': Icons.group,
  'favorite': Icons.favorite,
  'pets': Icons.pets,
  'volunteer_activism': Icons.volunteer_activism,
  'diversity_3': Icons.diversity_3,
  'check_circle': Icons.check_circle,
  'task_alt': Icons.task_alt,
  'pending_actions': Icons.pending_actions,
  'event': Icons.event,
  'today': Icons.today,
  'schedule': Icons.schedule,
  'work': Icons.work,
  'school': Icons.school,
  'home': Icons.home,
  'cleaning_services': Icons.cleaning_services,
  'kitchen': Icons.kitchen,
  'local_laundry_service': Icons.local_laundry_service,
  'yard': Icons.yard,
  'shopping_cart': Icons.shopping_cart,
  'receipt_long': Icons.receipt_long,
  'savings': Icons.savings,
  'block': Icons.block,
  'do_not_disturb': Icons.do_not_disturb,
  'pause_circle': Icons.pause_circle,
  'repeat': Icons.repeat,
  'restore': Icons.restore,
  'undo': Icons.undo,
  'check': Icons.check,
  'restaurant_menu': Icons.restaurant_menu,
  'lunch_dining': Icons.lunch_dining,
  'local_pizza': Icons.local_pizza,
  'cake': Icons.cake,
  'coffee': Icons.coffee,
  'liquor': Icons.liquor,
  'set_meal': Icons.set_meal,
  'directions_walk': Icons.directions_walk,
  'directions_bike': Icons.directions_bike,
  'pool': Icons.pool,
  'sports_gymnastics': Icons.sports_gymnastics,
  'sports_tennis': Icons.sports_tennis,
  'sports_basketball': Icons.sports_basketball,
  'sports_soccer': Icons.sports_soccer,
  'hiking': Icons.hiking,
};
