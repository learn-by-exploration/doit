// PersonGroupsScreen — list of cadence-style contact groups
// (WF-018). Each row shows the group's name, the next person
// to contact (rotation semantic), and a "mark contacted" CTA.
//
// Per the rule doc (.claude/rules/lib-screens.md), this is a
// StatefulWidget that subscribes to the repository. The list is
// reloaded on save/archive/delete.

import 'package:flutter/material.dart';

import 'package:common_games/people/cadence.dart';
import 'package:common_games/people/person.dart';
import 'package:common_games/people/person_group.dart';
import 'package:common_games/services/person_group_repository.dart';
import 'package:common_games/services/person_repository.dart';
import 'package:common_games/services/reminder_service.dart';
import 'package:common_games/theme/app_theme.dart';

class PersonGroupsScreen extends StatefulWidget {
  const PersonGroupsScreen({super.key});

  @override
  State<PersonGroupsScreen> createState() => _PersonGroupsScreenState();
}

class _PersonGroupsScreenState extends State<PersonGroupsScreen> {
  late Future<_GroupsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_GroupsData> _load() async {
    final groups = await PersonGroupRepository.instance.listAll();
    final enriched = <_GroupRow>[];
    for (final g in groups) {
      final members = await PersonGroupRepository.instance.listMembers(g.id);
      final nextPersonId = pickNextMember(members);
      final person = nextPersonId == null
          ? null
          : await PersonRepository.instance.getById(nextPersonId);
      enriched.add(_GroupRow(group: g, members: members, nextPerson: person));
    }
    return _GroupsData(rows: enriched);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await ReminderService.instance.rescheduleAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact groups'),
        actions: [
          IconButton(
            key: const ValueKey('person_groups.refresh'),
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<_GroupsData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.md),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Could not load groups'),
                      const SizedBox(height: Spacing.sm),
                      FilledButton(
                        onPressed: _refresh,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final data = snapshot.data ?? const _GroupsData(rows: []);
            if (data.rows.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(Spacing.lg),
                  child: Text(
                    'No contact groups yet.\n'
                    'Tap + to add a rotation group '
                    '(e.g., "Call a friend every week").',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(Spacing.md),
              children: [
                for (final r in data.rows)
                  _GroupCard(row: r, onChanged: _refresh),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('person_groups.add'),
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const AddPersonGroupScreen()),
          );
          if (created == true) await _refresh();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _GroupsData {
  const _GroupsData({required this.rows});
  final List<_GroupRow> rows;
}

class _GroupRow {
  const _GroupRow({
    required this.group,
    required this.members,
    required this.nextPerson,
  });
  final PersonGroup group;
  final List<GroupMember> members;
  final Person? nextPerson;
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.row, required this.onChanged});

  final _GroupRow row;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final g = row.group;
    final paused = g.isPausedAt(DateTime.now());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    g.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (paused)
                  const Chip(label: Text('Paused'))
                else
                  Chip(label: Text(_semanticLabel(g.semantic))),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              _cadenceLabel(g.cadence),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'Members: ${row.members.length}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (row.nextPerson != null &&
                g.semantic == GroupSemantic.rotation) ...[
              const SizedBox(height: Spacing.sm),
              Text(
                'Next: ${_personLabel(row.nextPerson!)}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
            const SizedBox(height: Spacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (row.nextPerson != null && !paused)
                  FilledButton.icon(
                    key: ValueKey('group.${g.id}.mark'),
                    icon: const Icon(Icons.check),
                    label: const Text('Mark contacted'),
                    onPressed: () async {
                      await PersonGroupRepository.instance.markContacted(
                        g.id,
                        row.nextPerson!.id,
                        DateTime.now(),
                      );
                      await onChanged();
                    },
                  ),
                IconButton(
                  key: ValueKey('group.${g.id}.delete'),
                  tooltip: 'Delete group',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await PersonGroupRepository.instance.deleteById(g.id);
                    await onChanged();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _personLabel(Person p) {
    // Person has no display name; we use the id as a placeholder.
    return p.id;
  }

  String _semanticLabel(GroupSemantic s) {
    return switch (s) {
      GroupSemantic.rotation => 'Rotation',
      GroupSemantic.any => 'Any',
      GroupSemantic.all => 'All',
    };
  }

  String _cadenceLabel(PersonCadence cadence) {
    return switch (cadence) {
      EveryNDays(:final nDays) => 'Every $nDays days',
      WeeklyOn() => 'Weekly',
      MonthlyOn() => 'Monthly',
      YearlyOn() => 'Yearly',
    };
  }
}

class AddPersonGroupScreen extends StatefulWidget {
  const AddPersonGroupScreen({super.key, this.existing});

  final PersonGroup? existing;

  @override
  State<AddPersonGroupScreen> createState() => _AddPersonGroupScreenState();
}

class _AddPersonGroupScreenState extends State<AddPersonGroupScreen> {
  final _nameCtrl = TextEditingController();
  final _handleCtrl = TextEditingController();
  String _channel = 'whatsapp';
  GroupSemantic _semantic = GroupSemantic.rotation;
  String _cadenceType = 'every_n_days';
  int _nDays = 7;
  int _weekday = DateTime.monday;
  int _dayOfMonth = 1;
  int _monthOfYear = 1;
  int _dayOfYear = 1;
  List<Person> _people = const [];
  Set<String> _selected = <String>{};
  String? _nameError;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _handleCtrl.text = e.handle;
      _channel = e.channel;
      _semantic = e.semantic;
    }
    _loadPeople();
  }

  Future<void> _loadPeople() async {
    final all = await PersonRepository.instance.listAll();
    if (!mounted) return;
    setState(() {
      _people = all;
      _loaded = true;
      if (widget.existing != null) {
        final members = PersonGroupRepository.instance.listMembers(
          widget.existing!.id,
        );
        members.then((m) {
          if (!mounted) return;
          setState(() {
            _selected = m.map((e) => e.personId).toSet();
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _handleCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final handle = _handleCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Name is required');
      return;
    }
    if (handle.isEmpty) {
      setState(() => _nameError = 'Handle (chat URI / phone) is required');
      return;
    }
    final id =
        widget.existing?.id ?? 'g_${DateTime.now().millisecondsSinceEpoch}';
    final createdAt = widget.existing?.createdAt ?? DateTime.now();
    final cadence = _buildCadence();
    final group = ContactGroup(
      id: id,
      name: name,
      cadence: cadence,
      semantic: _semantic,
      channel: _channel,
      handle: handle,
      createdAt: createdAt,
    );
    try {
      group.validate();
    } on PersonGroupValidationException catch (e) {
      setState(() => _nameError = e.toString());
      return;
    }
    await PersonGroupRepository.instance.save(group);
    for (final pid in _selected) {
      await PersonGroupRepository.instance.addMember(id, pid);
    }
    await ReminderService.instance.rescheduleAll();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  PersonCadence _buildCadence() {
    switch (_cadenceType) {
      case 'every_n_days':
        return EveryNDays(_nDays);
      case 'weekly_on':
        return WeeklyOn(_weekday);
      case 'monthly_on':
        return MonthlyOn(_dayOfMonth);
      case 'yearly_on':
        return YearlyOn(_monthOfYear, _dayOfYear);
      default:
        return const EveryNDays(7);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New group' : 'Edit group'),
        actions: [
          TextButton(
            key: const ValueKey('add_person_group.save'),
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Spacing.md),
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'Group name',
                errorText: _nameError,
              ),
            ),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: _handleCtrl,
              decoration: const InputDecoration(
                labelText: 'Channel handle (URI / phone / @handle)',
              ),
            ),
            const SizedBox(height: Spacing.md),
            Text('Channel', style: Theme.of(context).textTheme.titleMedium),
            Wrap(
              spacing: Spacing.sm,
              children: [
                for (final c in const [
                  'dialer',
                  'whatsapp',
                  'telegram',
                  'signal',
                  'sms',
                ])
                  ChoiceChip(
                    label: Text(c),
                    selected: _channel == c,
                    onSelected: (_) => setState(() => _channel = c),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            Text('Cadence', style: Theme.of(context).textTheme.titleMedium),
            Wrap(
              spacing: Spacing.sm,
              children: [
                for (final t in const [
                  'every_n_days',
                  'weekly_on',
                  'monthly_on',
                  'yearly_on',
                ])
                  ChoiceChip(
                    label: Text(_cadenceChipLabel(t)),
                    selected: _cadenceType == t,
                    onSelected: (_) => setState(() => _cadenceType = t),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            _cadenceParams(),
            const SizedBox(height: Spacing.md),
            Text('Semantic', style: Theme.of(context).textTheme.titleMedium),
            Wrap(
              spacing: Spacing.sm,
              children: [
                for (final s in GroupSemantic.values)
                  ChoiceChip(
                    label: Text(s.name),
                    selected: _semantic == s,
                    onSelected: (_) => setState(() => _semantic = s),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            Text('Members', style: Theme.of(context).textTheme.titleMedium),
            if (!_loaded)
              const Padding(
                padding: EdgeInsets.all(Spacing.md),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_people.isEmpty)
              const Padding(
                padding: EdgeInsets.all(Spacing.md),
                child: Text(
                  'No people added yet. Add a person on the People '
                  'screen first, then come back here to pick them.',
                ),
              )
            else
              Column(
                children: [
                  for (final p in _people)
                    CheckboxListTile(
                      key: ValueKey('group.member.${p.id}'),
                      title: Text(p.id),
                      subtitle: Text('lookup ${p.lookupKey}'),
                      value: _selected.contains(p.id),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selected.add(p.id);
                          } else {
                            _selected.remove(p.id);
                          }
                        });
                      },
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _cadenceChipLabel(String t) {
    return switch (t) {
      'every_n_days' => 'Every N days',
      'weekly_on' => 'Weekly',
      'monthly_on' => 'Monthly',
      'yearly_on' => 'Yearly',
      _ => t,
    };
  }

  Widget _cadenceParams() {
    switch (_cadenceType) {
      case 'every_n_days':
        return Row(
          children: [
            const Text('Days:'),
            const SizedBox(width: Spacing.sm),
            DropdownButton<int>(
              value: _nDays,
              onChanged: (v) {
                if (v != null) setState(() => _nDays = v);
              },
              items: const [
                DropdownMenuItem(value: 1, child: Text('1')),
                DropdownMenuItem(value: 3, child: Text('3')),
                DropdownMenuItem(value: 7, child: Text('7')),
                DropdownMenuItem(value: 14, child: Text('14')),
                DropdownMenuItem(value: 30, child: Text('30')),
              ],
            ),
          ],
        );
      case 'weekly_on':
        return Row(
          children: [
            const Text('Weekday:'),
            const SizedBox(width: Spacing.sm),
            DropdownButton<int>(
              value: _weekday,
              onChanged: (v) {
                if (v != null) setState(() => _weekday = v);
              },
              items: const [
                DropdownMenuItem(value: 1, child: Text('Mon')),
                DropdownMenuItem(value: 2, child: Text('Tue')),
                DropdownMenuItem(value: 3, child: Text('Wed')),
                DropdownMenuItem(value: 4, child: Text('Thu')),
                DropdownMenuItem(value: 5, child: Text('Fri')),
                DropdownMenuItem(value: 6, child: Text('Sat')),
                DropdownMenuItem(value: 7, child: Text('Sun')),
              ],
            ),
          ],
        );
      case 'monthly_on':
        return Row(
          children: [
            const Text('Day of month:'),
            const SizedBox(width: Spacing.sm),
            DropdownButton<int>(
              value: _dayOfMonth,
              onChanged: (v) {
                if (v != null) setState(() => _dayOfMonth = v);
              },
              items: [
                for (var d = 1; d <= 28; d++)
                  DropdownMenuItem(value: d, child: Text('$d')),
              ],
            ),
          ],
        );
      case 'yearly_on':
        return Row(
          children: [
            const Text('Month:'),
            const SizedBox(width: Spacing.sm),
            DropdownButton<int>(
              value: _monthOfYear,
              onChanged: (v) {
                if (v != null) setState(() => _monthOfYear = v);
              },
              items: [
                for (var m = 1; m <= 12; m++)
                  DropdownMenuItem(value: m, child: Text('$m')),
              ],
            ),
            const SizedBox(width: Spacing.md),
            const Text('Day:'),
            const SizedBox(width: Spacing.sm),
            DropdownButton<int>(
              value: _dayOfYear,
              onChanged: (v) {
                if (v != null) setState(() => _dayOfYear = v);
              },
              items: [
                for (var d = 1; d <= 31; d++)
                  DropdownMenuItem(value: d, child: Text('$d')),
              ],
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
