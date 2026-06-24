// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schema.dart';

// ignore_for_file: type=lint
class $HabitsTable extends Habits with TableInfo<$HabitsTable, HabitRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HabitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _proofModeMeta = const VerificationMeta(
    'proofMode',
  );
  @override
  late final GeneratedColumn<String> proofMode = GeneratedColumn<String>(
    'proof_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMillisMeta = const VerificationMeta(
    'createdAtMillis',
  );
  @override
  late final GeneratedColumn<int> createdAtMillis = GeneratedColumn<int>(
    'created_at_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _restDaysPerMonthMeta = const VerificationMeta(
    'restDaysPerMonth',
  );
  @override
  late final GeneratedColumn<int> restDaysPerMonth = GeneratedColumn<int>(
    'rest_days_per_month',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(2),
  );
  static const VerificationMeta _scheduleTypeMeta = const VerificationMeta(
    'scheduleType',
  );
  @override
  late final GeneratedColumn<String> scheduleType = GeneratedColumn<String>(
    'schedule_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weekdaysMeta = const VerificationMeta(
    'weekdays',
  );
  @override
  late final GeneratedColumn<String> weekdays = GeneratedColumn<String>(
    'weekdays',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hourMeta = const VerificationMeta('hour');
  @override
  late final GeneratedColumn<int> hour = GeneratedColumn<int>(
    'hour',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _minuteMeta = const VerificationMeta('minute');
  @override
  late final GeneratedColumn<int> minute = GeneratedColumn<int>(
    'minute',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nDaysMeta = const VerificationMeta('nDays');
  @override
  late final GeneratedColumn<int> nDays = GeneratedColumn<int>(
    'n_days',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _referenceDateMillisMeta =
      const VerificationMeta('referenceDateMillis');
  @override
  late final GeneratedColumn<int> referenceDateMillis = GeneratedColumn<int>(
    'reference_date_millis',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetHabitIdMeta = const VerificationMeta(
    'targetHabitId',
  );
  @override
  late final GeneratedColumn<String> targetHabitId = GeneratedColumn<String>(
    'target_habit_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastAnchorMillisMeta = const VerificationMeta(
    'lastAnchorMillis',
  );
  @override
  late final GeneratedColumn<int> lastAnchorMillis = GeneratedColumn<int>(
    'last_anchor_millis',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dayOfMonthMeta = const VerificationMeta(
    'dayOfMonth',
  );
  @override
  late final GeneratedColumn<int> dayOfMonth = GeneratedColumn<int>(
    'day_of_month',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nthMeta = const VerificationMeta('nth');
  @override
  late final GeneratedColumn<int> nth = GeneratedColumn<int>(
    'nth',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weekdayMeta = const VerificationMeta(
    'weekday',
  );
  @override
  late final GeneratedColumn<int> weekday = GeneratedColumn<int>(
    'weekday',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _referenceDayOfMonthMeta =
      const VerificationMeta('referenceDayOfMonth');
  @override
  late final GeneratedColumn<int> referenceDayOfMonth = GeneratedColumn<int>(
    'reference_day_of_month',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endHourMeta = const VerificationMeta(
    'endHour',
  );
  @override
  late final GeneratedColumn<int> endHour = GeneratedColumn<int>(
    'end_hour',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endMinuteMeta = const VerificationMeta(
    'endMinute',
  );
  @override
  late final GeneratedColumn<int> endMinute = GeneratedColumn<int>(
    'end_minute',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetHoursMeta = const VerificationMeta(
    'targetHours',
  );
  @override
  late final GeneratedColumn<int> targetHours = GeneratedColumn<int>(
    'target_hours',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _missionChainJsonMeta = const VerificationMeta(
    'missionChainJson',
  );
  @override
  late final GeneratedColumn<String> missionChainJson = GeneratedColumn<String>(
    'mission_chain_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('other'),
  );
  static const VerificationMeta _colorSeedMeta = const VerificationMeta(
    'colorSeed',
  );
  @override
  late final GeneratedColumn<int> colorSeed = GeneratedColumn<int>(
    'color_seed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _iconNameMeta = const VerificationMeta(
    'iconName',
  );
  @override
  late final GeneratedColumn<String> iconName = GeneratedColumn<String>(
    'icon_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pausedUntilMillisMeta = const VerificationMeta(
    'pausedUntilMillis',
  );
  @override
  late final GeneratedColumn<int> pausedUntilMillis = GeneratedColumn<int>(
    'paused_until_millis',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _automationsJsonMeta = const VerificationMeta(
    'automationsJson',
  );
  @override
  late final GeneratedColumn<String> automationsJson = GeneratedColumn<String>(
    'automations_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _graceWindowOverrideMillisMeta =
      const VerificationMeta('graceWindowOverrideMillis');
  @override
  late final GeneratedColumn<int> graceWindowOverrideMillis =
      GeneratedColumn<int>(
        'grace_window_override_millis',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    proofMode,
    createdAtMillis,
    restDaysPerMonth,
    scheduleType,
    weekdays,
    hour,
    minute,
    nDays,
    referenceDateMillis,
    targetHabitId,
    lastAnchorMillis,
    dayOfMonth,
    nth,
    weekday,
    referenceDayOfMonth,
    endHour,
    endMinute,
    targetHours,
    missionChainJson,
    category,
    colorSeed,
    iconName,
    pausedUntilMillis,
    automationsJson,
    graceWindowOverrideMillis,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'habits';
  @override
  VerificationContext validateIntegrity(
    Insertable<HabitRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('proof_mode')) {
      context.handle(
        _proofModeMeta,
        proofMode.isAcceptableOrUnknown(data['proof_mode']!, _proofModeMeta),
      );
    } else if (isInserting) {
      context.missing(_proofModeMeta);
    }
    if (data.containsKey('created_at_millis')) {
      context.handle(
        _createdAtMillisMeta,
        createdAtMillis.isAcceptableOrUnknown(
          data['created_at_millis']!,
          _createdAtMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMillisMeta);
    }
    if (data.containsKey('rest_days_per_month')) {
      context.handle(
        _restDaysPerMonthMeta,
        restDaysPerMonth.isAcceptableOrUnknown(
          data['rest_days_per_month']!,
          _restDaysPerMonthMeta,
        ),
      );
    }
    if (data.containsKey('schedule_type')) {
      context.handle(
        _scheduleTypeMeta,
        scheduleType.isAcceptableOrUnknown(
          data['schedule_type']!,
          _scheduleTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduleTypeMeta);
    }
    if (data.containsKey('weekdays')) {
      context.handle(
        _weekdaysMeta,
        weekdays.isAcceptableOrUnknown(data['weekdays']!, _weekdaysMeta),
      );
    }
    if (data.containsKey('hour')) {
      context.handle(
        _hourMeta,
        hour.isAcceptableOrUnknown(data['hour']!, _hourMeta),
      );
    }
    if (data.containsKey('minute')) {
      context.handle(
        _minuteMeta,
        minute.isAcceptableOrUnknown(data['minute']!, _minuteMeta),
      );
    }
    if (data.containsKey('n_days')) {
      context.handle(
        _nDaysMeta,
        nDays.isAcceptableOrUnknown(data['n_days']!, _nDaysMeta),
      );
    }
    if (data.containsKey('reference_date_millis')) {
      context.handle(
        _referenceDateMillisMeta,
        referenceDateMillis.isAcceptableOrUnknown(
          data['reference_date_millis']!,
          _referenceDateMillisMeta,
        ),
      );
    }
    if (data.containsKey('target_habit_id')) {
      context.handle(
        _targetHabitIdMeta,
        targetHabitId.isAcceptableOrUnknown(
          data['target_habit_id']!,
          _targetHabitIdMeta,
        ),
      );
    }
    if (data.containsKey('last_anchor_millis')) {
      context.handle(
        _lastAnchorMillisMeta,
        lastAnchorMillis.isAcceptableOrUnknown(
          data['last_anchor_millis']!,
          _lastAnchorMillisMeta,
        ),
      );
    }
    if (data.containsKey('day_of_month')) {
      context.handle(
        _dayOfMonthMeta,
        dayOfMonth.isAcceptableOrUnknown(
          data['day_of_month']!,
          _dayOfMonthMeta,
        ),
      );
    }
    if (data.containsKey('nth')) {
      context.handle(
        _nthMeta,
        nth.isAcceptableOrUnknown(data['nth']!, _nthMeta),
      );
    }
    if (data.containsKey('weekday')) {
      context.handle(
        _weekdayMeta,
        weekday.isAcceptableOrUnknown(data['weekday']!, _weekdayMeta),
      );
    }
    if (data.containsKey('reference_day_of_month')) {
      context.handle(
        _referenceDayOfMonthMeta,
        referenceDayOfMonth.isAcceptableOrUnknown(
          data['reference_day_of_month']!,
          _referenceDayOfMonthMeta,
        ),
      );
    }
    if (data.containsKey('end_hour')) {
      context.handle(
        _endHourMeta,
        endHour.isAcceptableOrUnknown(data['end_hour']!, _endHourMeta),
      );
    }
    if (data.containsKey('end_minute')) {
      context.handle(
        _endMinuteMeta,
        endMinute.isAcceptableOrUnknown(data['end_minute']!, _endMinuteMeta),
      );
    }
    if (data.containsKey('target_hours')) {
      context.handle(
        _targetHoursMeta,
        targetHours.isAcceptableOrUnknown(
          data['target_hours']!,
          _targetHoursMeta,
        ),
      );
    }
    if (data.containsKey('mission_chain_json')) {
      context.handle(
        _missionChainJsonMeta,
        missionChainJson.isAcceptableOrUnknown(
          data['mission_chain_json']!,
          _missionChainJsonMeta,
        ),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('color_seed')) {
      context.handle(
        _colorSeedMeta,
        colorSeed.isAcceptableOrUnknown(data['color_seed']!, _colorSeedMeta),
      );
    }
    if (data.containsKey('icon_name')) {
      context.handle(
        _iconNameMeta,
        iconName.isAcceptableOrUnknown(data['icon_name']!, _iconNameMeta),
      );
    }
    if (data.containsKey('paused_until_millis')) {
      context.handle(
        _pausedUntilMillisMeta,
        pausedUntilMillis.isAcceptableOrUnknown(
          data['paused_until_millis']!,
          _pausedUntilMillisMeta,
        ),
      );
    }
    if (data.containsKey('automations_json')) {
      context.handle(
        _automationsJsonMeta,
        automationsJson.isAcceptableOrUnknown(
          data['automations_json']!,
          _automationsJsonMeta,
        ),
      );
    }
    if (data.containsKey('grace_window_override_millis')) {
      context.handle(
        _graceWindowOverrideMillisMeta,
        graceWindowOverrideMillis.isAcceptableOrUnknown(
          data['grace_window_override_millis']!,
          _graceWindowOverrideMillisMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HabitRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HabitRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      proofMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}proof_mode'],
      )!,
      createdAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_millis'],
      )!,
      restDaysPerMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rest_days_per_month'],
      )!,
      scheduleType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schedule_type'],
      )!,
      weekdays: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}weekdays'],
      ),
      hour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hour'],
      ),
      minute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}minute'],
      ),
      nDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}n_days'],
      ),
      referenceDateMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reference_date_millis'],
      ),
      targetHabitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_habit_id'],
      ),
      lastAnchorMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_anchor_millis'],
      ),
      dayOfMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_of_month'],
      ),
      nth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}nth'],
      ),
      weekday: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}weekday'],
      ),
      referenceDayOfMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reference_day_of_month'],
      ),
      endHour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_hour'],
      ),
      endMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_minute'],
      ),
      targetHours: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_hours'],
      ),
      missionChainJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mission_chain_json'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      colorSeed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_seed'],
      )!,
      iconName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_name'],
      ),
      pausedUntilMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paused_until_millis'],
      ),
      automationsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}automations_json'],
      ),
      graceWindowOverrideMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}grace_window_override_millis'],
      ),
    );
  }

  @override
  $HabitsTable createAlias(String alias) {
    return $HabitsTable(attachedDatabase, alias);
  }
}

class HabitRow extends DataClass implements Insertable<HabitRow> {
  final String id;
  final String name;
  final String proofMode;
  final int createdAtMillis;
  final int restDaysPerMonth;
  final String scheduleType;
  final String? weekdays;
  final int? hour;
  final int? minute;
  final int? nDays;
  final int? referenceDateMillis;
  final String? targetHabitId;
  final int? lastAnchorMillis;
  final int? dayOfMonth;
  final int? nth;
  final int? weekday;
  final int? referenceDayOfMonth;
  final int? endHour;
  final int? endMinute;
  final int? targetHours;
  final String? missionChainJson;
  final String category;
  final int colorSeed;
  final String? iconName;
  final int? pausedUntilMillis;
  final String? automationsJson;
  final int? graceWindowOverrideMillis;
  const HabitRow({
    required this.id,
    required this.name,
    required this.proofMode,
    required this.createdAtMillis,
    required this.restDaysPerMonth,
    required this.scheduleType,
    this.weekdays,
    this.hour,
    this.minute,
    this.nDays,
    this.referenceDateMillis,
    this.targetHabitId,
    this.lastAnchorMillis,
    this.dayOfMonth,
    this.nth,
    this.weekday,
    this.referenceDayOfMonth,
    this.endHour,
    this.endMinute,
    this.targetHours,
    this.missionChainJson,
    required this.category,
    required this.colorSeed,
    this.iconName,
    this.pausedUntilMillis,
    this.automationsJson,
    this.graceWindowOverrideMillis,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['proof_mode'] = Variable<String>(proofMode);
    map['created_at_millis'] = Variable<int>(createdAtMillis);
    map['rest_days_per_month'] = Variable<int>(restDaysPerMonth);
    map['schedule_type'] = Variable<String>(scheduleType);
    if (!nullToAbsent || weekdays != null) {
      map['weekdays'] = Variable<String>(weekdays);
    }
    if (!nullToAbsent || hour != null) {
      map['hour'] = Variable<int>(hour);
    }
    if (!nullToAbsent || minute != null) {
      map['minute'] = Variable<int>(minute);
    }
    if (!nullToAbsent || nDays != null) {
      map['n_days'] = Variable<int>(nDays);
    }
    if (!nullToAbsent || referenceDateMillis != null) {
      map['reference_date_millis'] = Variable<int>(referenceDateMillis);
    }
    if (!nullToAbsent || targetHabitId != null) {
      map['target_habit_id'] = Variable<String>(targetHabitId);
    }
    if (!nullToAbsent || lastAnchorMillis != null) {
      map['last_anchor_millis'] = Variable<int>(lastAnchorMillis);
    }
    if (!nullToAbsent || dayOfMonth != null) {
      map['day_of_month'] = Variable<int>(dayOfMonth);
    }
    if (!nullToAbsent || nth != null) {
      map['nth'] = Variable<int>(nth);
    }
    if (!nullToAbsent || weekday != null) {
      map['weekday'] = Variable<int>(weekday);
    }
    if (!nullToAbsent || referenceDayOfMonth != null) {
      map['reference_day_of_month'] = Variable<int>(referenceDayOfMonth);
    }
    if (!nullToAbsent || endHour != null) {
      map['end_hour'] = Variable<int>(endHour);
    }
    if (!nullToAbsent || endMinute != null) {
      map['end_minute'] = Variable<int>(endMinute);
    }
    if (!nullToAbsent || targetHours != null) {
      map['target_hours'] = Variable<int>(targetHours);
    }
    if (!nullToAbsent || missionChainJson != null) {
      map['mission_chain_json'] = Variable<String>(missionChainJson);
    }
    map['category'] = Variable<String>(category);
    map['color_seed'] = Variable<int>(colorSeed);
    if (!nullToAbsent || iconName != null) {
      map['icon_name'] = Variable<String>(iconName);
    }
    if (!nullToAbsent || pausedUntilMillis != null) {
      map['paused_until_millis'] = Variable<int>(pausedUntilMillis);
    }
    if (!nullToAbsent || automationsJson != null) {
      map['automations_json'] = Variable<String>(automationsJson);
    }
    if (!nullToAbsent || graceWindowOverrideMillis != null) {
      map['grace_window_override_millis'] = Variable<int>(
        graceWindowOverrideMillis,
      );
    }
    return map;
  }

  HabitsCompanion toCompanion(bool nullToAbsent) {
    return HabitsCompanion(
      id: Value(id),
      name: Value(name),
      proofMode: Value(proofMode),
      createdAtMillis: Value(createdAtMillis),
      restDaysPerMonth: Value(restDaysPerMonth),
      scheduleType: Value(scheduleType),
      weekdays: weekdays == null && nullToAbsent
          ? const Value.absent()
          : Value(weekdays),
      hour: hour == null && nullToAbsent ? const Value.absent() : Value(hour),
      minute: minute == null && nullToAbsent
          ? const Value.absent()
          : Value(minute),
      nDays: nDays == null && nullToAbsent
          ? const Value.absent()
          : Value(nDays),
      referenceDateMillis: referenceDateMillis == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceDateMillis),
      targetHabitId: targetHabitId == null && nullToAbsent
          ? const Value.absent()
          : Value(targetHabitId),
      lastAnchorMillis: lastAnchorMillis == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAnchorMillis),
      dayOfMonth: dayOfMonth == null && nullToAbsent
          ? const Value.absent()
          : Value(dayOfMonth),
      nth: nth == null && nullToAbsent ? const Value.absent() : Value(nth),
      weekday: weekday == null && nullToAbsent
          ? const Value.absent()
          : Value(weekday),
      referenceDayOfMonth: referenceDayOfMonth == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceDayOfMonth),
      endHour: endHour == null && nullToAbsent
          ? const Value.absent()
          : Value(endHour),
      endMinute: endMinute == null && nullToAbsent
          ? const Value.absent()
          : Value(endMinute),
      targetHours: targetHours == null && nullToAbsent
          ? const Value.absent()
          : Value(targetHours),
      missionChainJson: missionChainJson == null && nullToAbsent
          ? const Value.absent()
          : Value(missionChainJson),
      category: Value(category),
      colorSeed: Value(colorSeed),
      iconName: iconName == null && nullToAbsent
          ? const Value.absent()
          : Value(iconName),
      pausedUntilMillis: pausedUntilMillis == null && nullToAbsent
          ? const Value.absent()
          : Value(pausedUntilMillis),
      automationsJson: automationsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(automationsJson),
      graceWindowOverrideMillis:
          graceWindowOverrideMillis == null && nullToAbsent
          ? const Value.absent()
          : Value(graceWindowOverrideMillis),
    );
  }

  factory HabitRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HabitRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      proofMode: serializer.fromJson<String>(json['proofMode']),
      createdAtMillis: serializer.fromJson<int>(json['createdAtMillis']),
      restDaysPerMonth: serializer.fromJson<int>(json['restDaysPerMonth']),
      scheduleType: serializer.fromJson<String>(json['scheduleType']),
      weekdays: serializer.fromJson<String?>(json['weekdays']),
      hour: serializer.fromJson<int?>(json['hour']),
      minute: serializer.fromJson<int?>(json['minute']),
      nDays: serializer.fromJson<int?>(json['nDays']),
      referenceDateMillis: serializer.fromJson<int?>(
        json['referenceDateMillis'],
      ),
      targetHabitId: serializer.fromJson<String?>(json['targetHabitId']),
      lastAnchorMillis: serializer.fromJson<int?>(json['lastAnchorMillis']),
      dayOfMonth: serializer.fromJson<int?>(json['dayOfMonth']),
      nth: serializer.fromJson<int?>(json['nth']),
      weekday: serializer.fromJson<int?>(json['weekday']),
      referenceDayOfMonth: serializer.fromJson<int?>(
        json['referenceDayOfMonth'],
      ),
      endHour: serializer.fromJson<int?>(json['endHour']),
      endMinute: serializer.fromJson<int?>(json['endMinute']),
      targetHours: serializer.fromJson<int?>(json['targetHours']),
      missionChainJson: serializer.fromJson<String?>(json['missionChainJson']),
      category: serializer.fromJson<String>(json['category']),
      colorSeed: serializer.fromJson<int>(json['colorSeed']),
      iconName: serializer.fromJson<String?>(json['iconName']),
      pausedUntilMillis: serializer.fromJson<int?>(json['pausedUntilMillis']),
      automationsJson: serializer.fromJson<String?>(json['automationsJson']),
      graceWindowOverrideMillis: serializer.fromJson<int?>(
        json['graceWindowOverrideMillis'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'proofMode': serializer.toJson<String>(proofMode),
      'createdAtMillis': serializer.toJson<int>(createdAtMillis),
      'restDaysPerMonth': serializer.toJson<int>(restDaysPerMonth),
      'scheduleType': serializer.toJson<String>(scheduleType),
      'weekdays': serializer.toJson<String?>(weekdays),
      'hour': serializer.toJson<int?>(hour),
      'minute': serializer.toJson<int?>(minute),
      'nDays': serializer.toJson<int?>(nDays),
      'referenceDateMillis': serializer.toJson<int?>(referenceDateMillis),
      'targetHabitId': serializer.toJson<String?>(targetHabitId),
      'lastAnchorMillis': serializer.toJson<int?>(lastAnchorMillis),
      'dayOfMonth': serializer.toJson<int?>(dayOfMonth),
      'nth': serializer.toJson<int?>(nth),
      'weekday': serializer.toJson<int?>(weekday),
      'referenceDayOfMonth': serializer.toJson<int?>(referenceDayOfMonth),
      'endHour': serializer.toJson<int?>(endHour),
      'endMinute': serializer.toJson<int?>(endMinute),
      'targetHours': serializer.toJson<int?>(targetHours),
      'missionChainJson': serializer.toJson<String?>(missionChainJson),
      'category': serializer.toJson<String>(category),
      'colorSeed': serializer.toJson<int>(colorSeed),
      'iconName': serializer.toJson<String?>(iconName),
      'pausedUntilMillis': serializer.toJson<int?>(pausedUntilMillis),
      'automationsJson': serializer.toJson<String?>(automationsJson),
      'graceWindowOverrideMillis': serializer.toJson<int?>(
        graceWindowOverrideMillis,
      ),
    };
  }

  HabitRow copyWith({
    String? id,
    String? name,
    String? proofMode,
    int? createdAtMillis,
    int? restDaysPerMonth,
    String? scheduleType,
    Value<String?> weekdays = const Value.absent(),
    Value<int?> hour = const Value.absent(),
    Value<int?> minute = const Value.absent(),
    Value<int?> nDays = const Value.absent(),
    Value<int?> referenceDateMillis = const Value.absent(),
    Value<String?> targetHabitId = const Value.absent(),
    Value<int?> lastAnchorMillis = const Value.absent(),
    Value<int?> dayOfMonth = const Value.absent(),
    Value<int?> nth = const Value.absent(),
    Value<int?> weekday = const Value.absent(),
    Value<int?> referenceDayOfMonth = const Value.absent(),
    Value<int?> endHour = const Value.absent(),
    Value<int?> endMinute = const Value.absent(),
    Value<int?> targetHours = const Value.absent(),
    Value<String?> missionChainJson = const Value.absent(),
    String? category,
    int? colorSeed,
    Value<String?> iconName = const Value.absent(),
    Value<int?> pausedUntilMillis = const Value.absent(),
    Value<String?> automationsJson = const Value.absent(),
    Value<int?> graceWindowOverrideMillis = const Value.absent(),
  }) => HabitRow(
    id: id ?? this.id,
    name: name ?? this.name,
    proofMode: proofMode ?? this.proofMode,
    createdAtMillis: createdAtMillis ?? this.createdAtMillis,
    restDaysPerMonth: restDaysPerMonth ?? this.restDaysPerMonth,
    scheduleType: scheduleType ?? this.scheduleType,
    weekdays: weekdays.present ? weekdays.value : this.weekdays,
    hour: hour.present ? hour.value : this.hour,
    minute: minute.present ? minute.value : this.minute,
    nDays: nDays.present ? nDays.value : this.nDays,
    referenceDateMillis: referenceDateMillis.present
        ? referenceDateMillis.value
        : this.referenceDateMillis,
    targetHabitId: targetHabitId.present
        ? targetHabitId.value
        : this.targetHabitId,
    lastAnchorMillis: lastAnchorMillis.present
        ? lastAnchorMillis.value
        : this.lastAnchorMillis,
    dayOfMonth: dayOfMonth.present ? dayOfMonth.value : this.dayOfMonth,
    nth: nth.present ? nth.value : this.nth,
    weekday: weekday.present ? weekday.value : this.weekday,
    referenceDayOfMonth: referenceDayOfMonth.present
        ? referenceDayOfMonth.value
        : this.referenceDayOfMonth,
    endHour: endHour.present ? endHour.value : this.endHour,
    endMinute: endMinute.present ? endMinute.value : this.endMinute,
    targetHours: targetHours.present ? targetHours.value : this.targetHours,
    missionChainJson: missionChainJson.present
        ? missionChainJson.value
        : this.missionChainJson,
    category: category ?? this.category,
    colorSeed: colorSeed ?? this.colorSeed,
    iconName: iconName.present ? iconName.value : this.iconName,
    pausedUntilMillis: pausedUntilMillis.present
        ? pausedUntilMillis.value
        : this.pausedUntilMillis,
    automationsJson: automationsJson.present
        ? automationsJson.value
        : this.automationsJson,
    graceWindowOverrideMillis: graceWindowOverrideMillis.present
        ? graceWindowOverrideMillis.value
        : this.graceWindowOverrideMillis,
  );
  HabitRow copyWithCompanion(HabitsCompanion data) {
    return HabitRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      proofMode: data.proofMode.present ? data.proofMode.value : this.proofMode,
      createdAtMillis: data.createdAtMillis.present
          ? data.createdAtMillis.value
          : this.createdAtMillis,
      restDaysPerMonth: data.restDaysPerMonth.present
          ? data.restDaysPerMonth.value
          : this.restDaysPerMonth,
      scheduleType: data.scheduleType.present
          ? data.scheduleType.value
          : this.scheduleType,
      weekdays: data.weekdays.present ? data.weekdays.value : this.weekdays,
      hour: data.hour.present ? data.hour.value : this.hour,
      minute: data.minute.present ? data.minute.value : this.minute,
      nDays: data.nDays.present ? data.nDays.value : this.nDays,
      referenceDateMillis: data.referenceDateMillis.present
          ? data.referenceDateMillis.value
          : this.referenceDateMillis,
      targetHabitId: data.targetHabitId.present
          ? data.targetHabitId.value
          : this.targetHabitId,
      lastAnchorMillis: data.lastAnchorMillis.present
          ? data.lastAnchorMillis.value
          : this.lastAnchorMillis,
      dayOfMonth: data.dayOfMonth.present
          ? data.dayOfMonth.value
          : this.dayOfMonth,
      nth: data.nth.present ? data.nth.value : this.nth,
      weekday: data.weekday.present ? data.weekday.value : this.weekday,
      referenceDayOfMonth: data.referenceDayOfMonth.present
          ? data.referenceDayOfMonth.value
          : this.referenceDayOfMonth,
      endHour: data.endHour.present ? data.endHour.value : this.endHour,
      endMinute: data.endMinute.present ? data.endMinute.value : this.endMinute,
      targetHours: data.targetHours.present
          ? data.targetHours.value
          : this.targetHours,
      missionChainJson: data.missionChainJson.present
          ? data.missionChainJson.value
          : this.missionChainJson,
      category: data.category.present ? data.category.value : this.category,
      colorSeed: data.colorSeed.present ? data.colorSeed.value : this.colorSeed,
      iconName: data.iconName.present ? data.iconName.value : this.iconName,
      pausedUntilMillis: data.pausedUntilMillis.present
          ? data.pausedUntilMillis.value
          : this.pausedUntilMillis,
      automationsJson: data.automationsJson.present
          ? data.automationsJson.value
          : this.automationsJson,
      graceWindowOverrideMillis: data.graceWindowOverrideMillis.present
          ? data.graceWindowOverrideMillis.value
          : this.graceWindowOverrideMillis,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HabitRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('proofMode: $proofMode, ')
          ..write('createdAtMillis: $createdAtMillis, ')
          ..write('restDaysPerMonth: $restDaysPerMonth, ')
          ..write('scheduleType: $scheduleType, ')
          ..write('weekdays: $weekdays, ')
          ..write('hour: $hour, ')
          ..write('minute: $minute, ')
          ..write('nDays: $nDays, ')
          ..write('referenceDateMillis: $referenceDateMillis, ')
          ..write('targetHabitId: $targetHabitId, ')
          ..write('lastAnchorMillis: $lastAnchorMillis, ')
          ..write('dayOfMonth: $dayOfMonth, ')
          ..write('nth: $nth, ')
          ..write('weekday: $weekday, ')
          ..write('referenceDayOfMonth: $referenceDayOfMonth, ')
          ..write('endHour: $endHour, ')
          ..write('endMinute: $endMinute, ')
          ..write('targetHours: $targetHours, ')
          ..write('missionChainJson: $missionChainJson, ')
          ..write('category: $category, ')
          ..write('colorSeed: $colorSeed, ')
          ..write('iconName: $iconName, ')
          ..write('pausedUntilMillis: $pausedUntilMillis, ')
          ..write('automationsJson: $automationsJson, ')
          ..write('graceWindowOverrideMillis: $graceWindowOverrideMillis')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    proofMode,
    createdAtMillis,
    restDaysPerMonth,
    scheduleType,
    weekdays,
    hour,
    minute,
    nDays,
    referenceDateMillis,
    targetHabitId,
    lastAnchorMillis,
    dayOfMonth,
    nth,
    weekday,
    referenceDayOfMonth,
    endHour,
    endMinute,
    targetHours,
    missionChainJson,
    category,
    colorSeed,
    iconName,
    pausedUntilMillis,
    automationsJson,
    graceWindowOverrideMillis,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HabitRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.proofMode == this.proofMode &&
          other.createdAtMillis == this.createdAtMillis &&
          other.restDaysPerMonth == this.restDaysPerMonth &&
          other.scheduleType == this.scheduleType &&
          other.weekdays == this.weekdays &&
          other.hour == this.hour &&
          other.minute == this.minute &&
          other.nDays == this.nDays &&
          other.referenceDateMillis == this.referenceDateMillis &&
          other.targetHabitId == this.targetHabitId &&
          other.lastAnchorMillis == this.lastAnchorMillis &&
          other.dayOfMonth == this.dayOfMonth &&
          other.nth == this.nth &&
          other.weekday == this.weekday &&
          other.referenceDayOfMonth == this.referenceDayOfMonth &&
          other.endHour == this.endHour &&
          other.endMinute == this.endMinute &&
          other.targetHours == this.targetHours &&
          other.missionChainJson == this.missionChainJson &&
          other.category == this.category &&
          other.colorSeed == this.colorSeed &&
          other.iconName == this.iconName &&
          other.pausedUntilMillis == this.pausedUntilMillis &&
          other.automationsJson == this.automationsJson &&
          other.graceWindowOverrideMillis == this.graceWindowOverrideMillis);
}

class HabitsCompanion extends UpdateCompanion<HabitRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> proofMode;
  final Value<int> createdAtMillis;
  final Value<int> restDaysPerMonth;
  final Value<String> scheduleType;
  final Value<String?> weekdays;
  final Value<int?> hour;
  final Value<int?> minute;
  final Value<int?> nDays;
  final Value<int?> referenceDateMillis;
  final Value<String?> targetHabitId;
  final Value<int?> lastAnchorMillis;
  final Value<int?> dayOfMonth;
  final Value<int?> nth;
  final Value<int?> weekday;
  final Value<int?> referenceDayOfMonth;
  final Value<int?> endHour;
  final Value<int?> endMinute;
  final Value<int?> targetHours;
  final Value<String?> missionChainJson;
  final Value<String> category;
  final Value<int> colorSeed;
  final Value<String?> iconName;
  final Value<int?> pausedUntilMillis;
  final Value<String?> automationsJson;
  final Value<int?> graceWindowOverrideMillis;
  final Value<int> rowid;
  const HabitsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.proofMode = const Value.absent(),
    this.createdAtMillis = const Value.absent(),
    this.restDaysPerMonth = const Value.absent(),
    this.scheduleType = const Value.absent(),
    this.weekdays = const Value.absent(),
    this.hour = const Value.absent(),
    this.minute = const Value.absent(),
    this.nDays = const Value.absent(),
    this.referenceDateMillis = const Value.absent(),
    this.targetHabitId = const Value.absent(),
    this.lastAnchorMillis = const Value.absent(),
    this.dayOfMonth = const Value.absent(),
    this.nth = const Value.absent(),
    this.weekday = const Value.absent(),
    this.referenceDayOfMonth = const Value.absent(),
    this.endHour = const Value.absent(),
    this.endMinute = const Value.absent(),
    this.targetHours = const Value.absent(),
    this.missionChainJson = const Value.absent(),
    this.category = const Value.absent(),
    this.colorSeed = const Value.absent(),
    this.iconName = const Value.absent(),
    this.pausedUntilMillis = const Value.absent(),
    this.automationsJson = const Value.absent(),
    this.graceWindowOverrideMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HabitsCompanion.insert({
    required String id,
    required String name,
    required String proofMode,
    required int createdAtMillis,
    this.restDaysPerMonth = const Value.absent(),
    required String scheduleType,
    this.weekdays = const Value.absent(),
    this.hour = const Value.absent(),
    this.minute = const Value.absent(),
    this.nDays = const Value.absent(),
    this.referenceDateMillis = const Value.absent(),
    this.targetHabitId = const Value.absent(),
    this.lastAnchorMillis = const Value.absent(),
    this.dayOfMonth = const Value.absent(),
    this.nth = const Value.absent(),
    this.weekday = const Value.absent(),
    this.referenceDayOfMonth = const Value.absent(),
    this.endHour = const Value.absent(),
    this.endMinute = const Value.absent(),
    this.targetHours = const Value.absent(),
    this.missionChainJson = const Value.absent(),
    this.category = const Value.absent(),
    this.colorSeed = const Value.absent(),
    this.iconName = const Value.absent(),
    this.pausedUntilMillis = const Value.absent(),
    this.automationsJson = const Value.absent(),
    this.graceWindowOverrideMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       proofMode = Value(proofMode),
       createdAtMillis = Value(createdAtMillis),
       scheduleType = Value(scheduleType);
  static Insertable<HabitRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? proofMode,
    Expression<int>? createdAtMillis,
    Expression<int>? restDaysPerMonth,
    Expression<String>? scheduleType,
    Expression<String>? weekdays,
    Expression<int>? hour,
    Expression<int>? minute,
    Expression<int>? nDays,
    Expression<int>? referenceDateMillis,
    Expression<String>? targetHabitId,
    Expression<int>? lastAnchorMillis,
    Expression<int>? dayOfMonth,
    Expression<int>? nth,
    Expression<int>? weekday,
    Expression<int>? referenceDayOfMonth,
    Expression<int>? endHour,
    Expression<int>? endMinute,
    Expression<int>? targetHours,
    Expression<String>? missionChainJson,
    Expression<String>? category,
    Expression<int>? colorSeed,
    Expression<String>? iconName,
    Expression<int>? pausedUntilMillis,
    Expression<String>? automationsJson,
    Expression<int>? graceWindowOverrideMillis,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (proofMode != null) 'proof_mode': proofMode,
      if (createdAtMillis != null) 'created_at_millis': createdAtMillis,
      if (restDaysPerMonth != null) 'rest_days_per_month': restDaysPerMonth,
      if (scheduleType != null) 'schedule_type': scheduleType,
      if (weekdays != null) 'weekdays': weekdays,
      if (hour != null) 'hour': hour,
      if (minute != null) 'minute': minute,
      if (nDays != null) 'n_days': nDays,
      if (referenceDateMillis != null)
        'reference_date_millis': referenceDateMillis,
      if (targetHabitId != null) 'target_habit_id': targetHabitId,
      if (lastAnchorMillis != null) 'last_anchor_millis': lastAnchorMillis,
      if (dayOfMonth != null) 'day_of_month': dayOfMonth,
      if (nth != null) 'nth': nth,
      if (weekday != null) 'weekday': weekday,
      if (referenceDayOfMonth != null)
        'reference_day_of_month': referenceDayOfMonth,
      if (endHour != null) 'end_hour': endHour,
      if (endMinute != null) 'end_minute': endMinute,
      if (targetHours != null) 'target_hours': targetHours,
      if (missionChainJson != null) 'mission_chain_json': missionChainJson,
      if (category != null) 'category': category,
      if (colorSeed != null) 'color_seed': colorSeed,
      if (iconName != null) 'icon_name': iconName,
      if (pausedUntilMillis != null) 'paused_until_millis': pausedUntilMillis,
      if (automationsJson != null) 'automations_json': automationsJson,
      if (graceWindowOverrideMillis != null)
        'grace_window_override_millis': graceWindowOverrideMillis,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HabitsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? proofMode,
    Value<int>? createdAtMillis,
    Value<int>? restDaysPerMonth,
    Value<String>? scheduleType,
    Value<String?>? weekdays,
    Value<int?>? hour,
    Value<int?>? minute,
    Value<int?>? nDays,
    Value<int?>? referenceDateMillis,
    Value<String?>? targetHabitId,
    Value<int?>? lastAnchorMillis,
    Value<int?>? dayOfMonth,
    Value<int?>? nth,
    Value<int?>? weekday,
    Value<int?>? referenceDayOfMonth,
    Value<int?>? endHour,
    Value<int?>? endMinute,
    Value<int?>? targetHours,
    Value<String?>? missionChainJson,
    Value<String>? category,
    Value<int>? colorSeed,
    Value<String?>? iconName,
    Value<int?>? pausedUntilMillis,
    Value<String?>? automationsJson,
    Value<int?>? graceWindowOverrideMillis,
    Value<int>? rowid,
  }) {
    return HabitsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      proofMode: proofMode ?? this.proofMode,
      createdAtMillis: createdAtMillis ?? this.createdAtMillis,
      restDaysPerMonth: restDaysPerMonth ?? this.restDaysPerMonth,
      scheduleType: scheduleType ?? this.scheduleType,
      weekdays: weekdays ?? this.weekdays,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      nDays: nDays ?? this.nDays,
      referenceDateMillis: referenceDateMillis ?? this.referenceDateMillis,
      targetHabitId: targetHabitId ?? this.targetHabitId,
      lastAnchorMillis: lastAnchorMillis ?? this.lastAnchorMillis,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      nth: nth ?? this.nth,
      weekday: weekday ?? this.weekday,
      referenceDayOfMonth: referenceDayOfMonth ?? this.referenceDayOfMonth,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
      targetHours: targetHours ?? this.targetHours,
      missionChainJson: missionChainJson ?? this.missionChainJson,
      category: category ?? this.category,
      colorSeed: colorSeed ?? this.colorSeed,
      iconName: iconName ?? this.iconName,
      pausedUntilMillis: pausedUntilMillis ?? this.pausedUntilMillis,
      automationsJson: automationsJson ?? this.automationsJson,
      graceWindowOverrideMillis:
          graceWindowOverrideMillis ?? this.graceWindowOverrideMillis,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (proofMode.present) {
      map['proof_mode'] = Variable<String>(proofMode.value);
    }
    if (createdAtMillis.present) {
      map['created_at_millis'] = Variable<int>(createdAtMillis.value);
    }
    if (restDaysPerMonth.present) {
      map['rest_days_per_month'] = Variable<int>(restDaysPerMonth.value);
    }
    if (scheduleType.present) {
      map['schedule_type'] = Variable<String>(scheduleType.value);
    }
    if (weekdays.present) {
      map['weekdays'] = Variable<String>(weekdays.value);
    }
    if (hour.present) {
      map['hour'] = Variable<int>(hour.value);
    }
    if (minute.present) {
      map['minute'] = Variable<int>(minute.value);
    }
    if (nDays.present) {
      map['n_days'] = Variable<int>(nDays.value);
    }
    if (referenceDateMillis.present) {
      map['reference_date_millis'] = Variable<int>(referenceDateMillis.value);
    }
    if (targetHabitId.present) {
      map['target_habit_id'] = Variable<String>(targetHabitId.value);
    }
    if (lastAnchorMillis.present) {
      map['last_anchor_millis'] = Variable<int>(lastAnchorMillis.value);
    }
    if (dayOfMonth.present) {
      map['day_of_month'] = Variable<int>(dayOfMonth.value);
    }
    if (nth.present) {
      map['nth'] = Variable<int>(nth.value);
    }
    if (weekday.present) {
      map['weekday'] = Variable<int>(weekday.value);
    }
    if (referenceDayOfMonth.present) {
      map['reference_day_of_month'] = Variable<int>(referenceDayOfMonth.value);
    }
    if (endHour.present) {
      map['end_hour'] = Variable<int>(endHour.value);
    }
    if (endMinute.present) {
      map['end_minute'] = Variable<int>(endMinute.value);
    }
    if (targetHours.present) {
      map['target_hours'] = Variable<int>(targetHours.value);
    }
    if (missionChainJson.present) {
      map['mission_chain_json'] = Variable<String>(missionChainJson.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (colorSeed.present) {
      map['color_seed'] = Variable<int>(colorSeed.value);
    }
    if (iconName.present) {
      map['icon_name'] = Variable<String>(iconName.value);
    }
    if (pausedUntilMillis.present) {
      map['paused_until_millis'] = Variable<int>(pausedUntilMillis.value);
    }
    if (automationsJson.present) {
      map['automations_json'] = Variable<String>(automationsJson.value);
    }
    if (graceWindowOverrideMillis.present) {
      map['grace_window_override_millis'] = Variable<int>(
        graceWindowOverrideMillis.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HabitsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('proofMode: $proofMode, ')
          ..write('createdAtMillis: $createdAtMillis, ')
          ..write('restDaysPerMonth: $restDaysPerMonth, ')
          ..write('scheduleType: $scheduleType, ')
          ..write('weekdays: $weekdays, ')
          ..write('hour: $hour, ')
          ..write('minute: $minute, ')
          ..write('nDays: $nDays, ')
          ..write('referenceDateMillis: $referenceDateMillis, ')
          ..write('targetHabitId: $targetHabitId, ')
          ..write('lastAnchorMillis: $lastAnchorMillis, ')
          ..write('dayOfMonth: $dayOfMonth, ')
          ..write('nth: $nth, ')
          ..write('weekday: $weekday, ')
          ..write('referenceDayOfMonth: $referenceDayOfMonth, ')
          ..write('endHour: $endHour, ')
          ..write('endMinute: $endMinute, ')
          ..write('targetHours: $targetHours, ')
          ..write('missionChainJson: $missionChainJson, ')
          ..write('category: $category, ')
          ..write('colorSeed: $colorSeed, ')
          ..write('iconName: $iconName, ')
          ..write('pausedUntilMillis: $pausedUntilMillis, ')
          ..write('automationsJson: $automationsJson, ')
          ..write('graceWindowOverrideMillis: $graceWindowOverrideMillis, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PeopleTable extends People with TableInfo<$PeopleTable, PersonRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PeopleTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lookupKeyMeta = const VerificationMeta(
    'lookupKey',
  );
  @override
  late final GeneratedColumn<String> lookupKey = GeneratedColumn<String>(
    'lookup_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _channelMeta = const VerificationMeta(
    'channel',
  );
  @override
  late final GeneratedColumn<String> channel = GeneratedColumn<String>(
    'channel',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _handleMeta = const VerificationMeta('handle');
  @override
  late final GeneratedColumn<String> handle = GeneratedColumn<String>(
    'handle',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMillisMeta = const VerificationMeta(
    'createdAtMillis',
  );
  @override
  late final GeneratedColumn<int> createdAtMillis = GeneratedColumn<int>(
    'created_at_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cadenceTypeMeta = const VerificationMeta(
    'cadenceType',
  );
  @override
  late final GeneratedColumn<String> cadenceType = GeneratedColumn<String>(
    'cadence_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nDaysMeta = const VerificationMeta('nDays');
  @override
  late final GeneratedColumn<int> nDays = GeneratedColumn<int>(
    'n_days',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weekdayMeta = const VerificationMeta(
    'weekday',
  );
  @override
  late final GeneratedColumn<int> weekday = GeneratedColumn<int>(
    'weekday',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dayOfMonthMeta = const VerificationMeta(
    'dayOfMonth',
  );
  @override
  late final GeneratedColumn<int> dayOfMonth = GeneratedColumn<int>(
    'day_of_month',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _monthOfYearMeta = const VerificationMeta(
    'monthOfYear',
  );
  @override
  late final GeneratedColumn<int> monthOfYear = GeneratedColumn<int>(
    'month_of_year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _anchoredToWakeupMeta = const VerificationMeta(
    'anchoredToWakeup',
  );
  @override
  late final GeneratedColumn<bool> anchoredToWakeup = GeneratedColumn<bool>(
    'anchored_to_wakeup',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("anchored_to_wakeup" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _missionChainJsonMeta = const VerificationMeta(
    'missionChainJson',
  );
  @override
  late final GeneratedColumn<String> missionChainJson = GeneratedColumn<String>(
    'mission_chain_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pausedUntilMillisMeta = const VerificationMeta(
    'pausedUntilMillis',
  );
  @override
  late final GeneratedColumn<int> pausedUntilMillis = GeneratedColumn<int>(
    'paused_until_millis',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _automationsJsonMeta = const VerificationMeta(
    'automationsJson',
  );
  @override
  late final GeneratedColumn<String> automationsJson = GeneratedColumn<String>(
    'automations_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    lookupKey,
    displayName,
    channel,
    handle,
    createdAtMillis,
    cadenceType,
    nDays,
    weekday,
    dayOfMonth,
    monthOfYear,
    anchoredToWakeup,
    missionChainJson,
    pausedUntilMillis,
    automationsJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'people';
  @override
  VerificationContext validateIntegrity(
    Insertable<PersonRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('lookup_key')) {
      context.handle(
        _lookupKeyMeta,
        lookupKey.isAcceptableOrUnknown(data['lookup_key']!, _lookupKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_lookupKeyMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('channel')) {
      context.handle(
        _channelMeta,
        channel.isAcceptableOrUnknown(data['channel']!, _channelMeta),
      );
    } else if (isInserting) {
      context.missing(_channelMeta);
    }
    if (data.containsKey('handle')) {
      context.handle(
        _handleMeta,
        handle.isAcceptableOrUnknown(data['handle']!, _handleMeta),
      );
    } else if (isInserting) {
      context.missing(_handleMeta);
    }
    if (data.containsKey('created_at_millis')) {
      context.handle(
        _createdAtMillisMeta,
        createdAtMillis.isAcceptableOrUnknown(
          data['created_at_millis']!,
          _createdAtMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMillisMeta);
    }
    if (data.containsKey('cadence_type')) {
      context.handle(
        _cadenceTypeMeta,
        cadenceType.isAcceptableOrUnknown(
          data['cadence_type']!,
          _cadenceTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_cadenceTypeMeta);
    }
    if (data.containsKey('n_days')) {
      context.handle(
        _nDaysMeta,
        nDays.isAcceptableOrUnknown(data['n_days']!, _nDaysMeta),
      );
    }
    if (data.containsKey('weekday')) {
      context.handle(
        _weekdayMeta,
        weekday.isAcceptableOrUnknown(data['weekday']!, _weekdayMeta),
      );
    }
    if (data.containsKey('day_of_month')) {
      context.handle(
        _dayOfMonthMeta,
        dayOfMonth.isAcceptableOrUnknown(
          data['day_of_month']!,
          _dayOfMonthMeta,
        ),
      );
    }
    if (data.containsKey('month_of_year')) {
      context.handle(
        _monthOfYearMeta,
        monthOfYear.isAcceptableOrUnknown(
          data['month_of_year']!,
          _monthOfYearMeta,
        ),
      );
    }
    if (data.containsKey('anchored_to_wakeup')) {
      context.handle(
        _anchoredToWakeupMeta,
        anchoredToWakeup.isAcceptableOrUnknown(
          data['anchored_to_wakeup']!,
          _anchoredToWakeupMeta,
        ),
      );
    }
    if (data.containsKey('mission_chain_json')) {
      context.handle(
        _missionChainJsonMeta,
        missionChainJson.isAcceptableOrUnknown(
          data['mission_chain_json']!,
          _missionChainJsonMeta,
        ),
      );
    }
    if (data.containsKey('paused_until_millis')) {
      context.handle(
        _pausedUntilMillisMeta,
        pausedUntilMillis.isAcceptableOrUnknown(
          data['paused_until_millis']!,
          _pausedUntilMillisMeta,
        ),
      );
    }
    if (data.containsKey('automations_json')) {
      context.handle(
        _automationsJsonMeta,
        automationsJson.isAcceptableOrUnknown(
          data['automations_json']!,
          _automationsJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PersonRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PersonRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      lookupKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lookup_key'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      channel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel'],
      )!,
      handle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}handle'],
      )!,
      createdAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_millis'],
      )!,
      cadenceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cadence_type'],
      )!,
      nDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}n_days'],
      ),
      weekday: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}weekday'],
      ),
      dayOfMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_of_month'],
      ),
      monthOfYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}month_of_year'],
      ),
      anchoredToWakeup: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}anchored_to_wakeup'],
      )!,
      missionChainJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mission_chain_json'],
      ),
      pausedUntilMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paused_until_millis'],
      ),
      automationsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}automations_json'],
      ),
    );
  }

  @override
  $PeopleTable createAlias(String alias) {
    return $PeopleTable(attachedDatabase, alias);
  }
}

class PersonRow extends DataClass implements Insertable<PersonRow> {
  final String id;
  final String lookupKey;
  final String displayName;
  final String channel;
  final String handle;
  final int createdAtMillis;
  final String cadenceType;
  final int? nDays;
  final int? weekday;
  final int? dayOfMonth;
  final int? monthOfYear;
  final bool anchoredToWakeup;
  final String? missionChainJson;
  final int? pausedUntilMillis;
  final String? automationsJson;
  const PersonRow({
    required this.id,
    required this.lookupKey,
    required this.displayName,
    required this.channel,
    required this.handle,
    required this.createdAtMillis,
    required this.cadenceType,
    this.nDays,
    this.weekday,
    this.dayOfMonth,
    this.monthOfYear,
    required this.anchoredToWakeup,
    this.missionChainJson,
    this.pausedUntilMillis,
    this.automationsJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['lookup_key'] = Variable<String>(lookupKey);
    map['display_name'] = Variable<String>(displayName);
    map['channel'] = Variable<String>(channel);
    map['handle'] = Variable<String>(handle);
    map['created_at_millis'] = Variable<int>(createdAtMillis);
    map['cadence_type'] = Variable<String>(cadenceType);
    if (!nullToAbsent || nDays != null) {
      map['n_days'] = Variable<int>(nDays);
    }
    if (!nullToAbsent || weekday != null) {
      map['weekday'] = Variable<int>(weekday);
    }
    if (!nullToAbsent || dayOfMonth != null) {
      map['day_of_month'] = Variable<int>(dayOfMonth);
    }
    if (!nullToAbsent || monthOfYear != null) {
      map['month_of_year'] = Variable<int>(monthOfYear);
    }
    map['anchored_to_wakeup'] = Variable<bool>(anchoredToWakeup);
    if (!nullToAbsent || missionChainJson != null) {
      map['mission_chain_json'] = Variable<String>(missionChainJson);
    }
    if (!nullToAbsent || pausedUntilMillis != null) {
      map['paused_until_millis'] = Variable<int>(pausedUntilMillis);
    }
    if (!nullToAbsent || automationsJson != null) {
      map['automations_json'] = Variable<String>(automationsJson);
    }
    return map;
  }

  PeopleCompanion toCompanion(bool nullToAbsent) {
    return PeopleCompanion(
      id: Value(id),
      lookupKey: Value(lookupKey),
      displayName: Value(displayName),
      channel: Value(channel),
      handle: Value(handle),
      createdAtMillis: Value(createdAtMillis),
      cadenceType: Value(cadenceType),
      nDays: nDays == null && nullToAbsent
          ? const Value.absent()
          : Value(nDays),
      weekday: weekday == null && nullToAbsent
          ? const Value.absent()
          : Value(weekday),
      dayOfMonth: dayOfMonth == null && nullToAbsent
          ? const Value.absent()
          : Value(dayOfMonth),
      monthOfYear: monthOfYear == null && nullToAbsent
          ? const Value.absent()
          : Value(monthOfYear),
      anchoredToWakeup: Value(anchoredToWakeup),
      missionChainJson: missionChainJson == null && nullToAbsent
          ? const Value.absent()
          : Value(missionChainJson),
      pausedUntilMillis: pausedUntilMillis == null && nullToAbsent
          ? const Value.absent()
          : Value(pausedUntilMillis),
      automationsJson: automationsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(automationsJson),
    );
  }

  factory PersonRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PersonRow(
      id: serializer.fromJson<String>(json['id']),
      lookupKey: serializer.fromJson<String>(json['lookupKey']),
      displayName: serializer.fromJson<String>(json['displayName']),
      channel: serializer.fromJson<String>(json['channel']),
      handle: serializer.fromJson<String>(json['handle']),
      createdAtMillis: serializer.fromJson<int>(json['createdAtMillis']),
      cadenceType: serializer.fromJson<String>(json['cadenceType']),
      nDays: serializer.fromJson<int?>(json['nDays']),
      weekday: serializer.fromJson<int?>(json['weekday']),
      dayOfMonth: serializer.fromJson<int?>(json['dayOfMonth']),
      monthOfYear: serializer.fromJson<int?>(json['monthOfYear']),
      anchoredToWakeup: serializer.fromJson<bool>(json['anchoredToWakeup']),
      missionChainJson: serializer.fromJson<String?>(json['missionChainJson']),
      pausedUntilMillis: serializer.fromJson<int?>(json['pausedUntilMillis']),
      automationsJson: serializer.fromJson<String?>(json['automationsJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'lookupKey': serializer.toJson<String>(lookupKey),
      'displayName': serializer.toJson<String>(displayName),
      'channel': serializer.toJson<String>(channel),
      'handle': serializer.toJson<String>(handle),
      'createdAtMillis': serializer.toJson<int>(createdAtMillis),
      'cadenceType': serializer.toJson<String>(cadenceType),
      'nDays': serializer.toJson<int?>(nDays),
      'weekday': serializer.toJson<int?>(weekday),
      'dayOfMonth': serializer.toJson<int?>(dayOfMonth),
      'monthOfYear': serializer.toJson<int?>(monthOfYear),
      'anchoredToWakeup': serializer.toJson<bool>(anchoredToWakeup),
      'missionChainJson': serializer.toJson<String?>(missionChainJson),
      'pausedUntilMillis': serializer.toJson<int?>(pausedUntilMillis),
      'automationsJson': serializer.toJson<String?>(automationsJson),
    };
  }

  PersonRow copyWith({
    String? id,
    String? lookupKey,
    String? displayName,
    String? channel,
    String? handle,
    int? createdAtMillis,
    String? cadenceType,
    Value<int?> nDays = const Value.absent(),
    Value<int?> weekday = const Value.absent(),
    Value<int?> dayOfMonth = const Value.absent(),
    Value<int?> monthOfYear = const Value.absent(),
    bool? anchoredToWakeup,
    Value<String?> missionChainJson = const Value.absent(),
    Value<int?> pausedUntilMillis = const Value.absent(),
    Value<String?> automationsJson = const Value.absent(),
  }) => PersonRow(
    id: id ?? this.id,
    lookupKey: lookupKey ?? this.lookupKey,
    displayName: displayName ?? this.displayName,
    channel: channel ?? this.channel,
    handle: handle ?? this.handle,
    createdAtMillis: createdAtMillis ?? this.createdAtMillis,
    cadenceType: cadenceType ?? this.cadenceType,
    nDays: nDays.present ? nDays.value : this.nDays,
    weekday: weekday.present ? weekday.value : this.weekday,
    dayOfMonth: dayOfMonth.present ? dayOfMonth.value : this.dayOfMonth,
    monthOfYear: monthOfYear.present ? monthOfYear.value : this.monthOfYear,
    anchoredToWakeup: anchoredToWakeup ?? this.anchoredToWakeup,
    missionChainJson: missionChainJson.present
        ? missionChainJson.value
        : this.missionChainJson,
    pausedUntilMillis: pausedUntilMillis.present
        ? pausedUntilMillis.value
        : this.pausedUntilMillis,
    automationsJson: automationsJson.present
        ? automationsJson.value
        : this.automationsJson,
  );
  PersonRow copyWithCompanion(PeopleCompanion data) {
    return PersonRow(
      id: data.id.present ? data.id.value : this.id,
      lookupKey: data.lookupKey.present ? data.lookupKey.value : this.lookupKey,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      channel: data.channel.present ? data.channel.value : this.channel,
      handle: data.handle.present ? data.handle.value : this.handle,
      createdAtMillis: data.createdAtMillis.present
          ? data.createdAtMillis.value
          : this.createdAtMillis,
      cadenceType: data.cadenceType.present
          ? data.cadenceType.value
          : this.cadenceType,
      nDays: data.nDays.present ? data.nDays.value : this.nDays,
      weekday: data.weekday.present ? data.weekday.value : this.weekday,
      dayOfMonth: data.dayOfMonth.present
          ? data.dayOfMonth.value
          : this.dayOfMonth,
      monthOfYear: data.monthOfYear.present
          ? data.monthOfYear.value
          : this.monthOfYear,
      anchoredToWakeup: data.anchoredToWakeup.present
          ? data.anchoredToWakeup.value
          : this.anchoredToWakeup,
      missionChainJson: data.missionChainJson.present
          ? data.missionChainJson.value
          : this.missionChainJson,
      pausedUntilMillis: data.pausedUntilMillis.present
          ? data.pausedUntilMillis.value
          : this.pausedUntilMillis,
      automationsJson: data.automationsJson.present
          ? data.automationsJson.value
          : this.automationsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PersonRow(')
          ..write('id: $id, ')
          ..write('lookupKey: $lookupKey, ')
          ..write('displayName: $displayName, ')
          ..write('channel: $channel, ')
          ..write('handle: $handle, ')
          ..write('createdAtMillis: $createdAtMillis, ')
          ..write('cadenceType: $cadenceType, ')
          ..write('nDays: $nDays, ')
          ..write('weekday: $weekday, ')
          ..write('dayOfMonth: $dayOfMonth, ')
          ..write('monthOfYear: $monthOfYear, ')
          ..write('anchoredToWakeup: $anchoredToWakeup, ')
          ..write('missionChainJson: $missionChainJson, ')
          ..write('pausedUntilMillis: $pausedUntilMillis, ')
          ..write('automationsJson: $automationsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    lookupKey,
    displayName,
    channel,
    handle,
    createdAtMillis,
    cadenceType,
    nDays,
    weekday,
    dayOfMonth,
    monthOfYear,
    anchoredToWakeup,
    missionChainJson,
    pausedUntilMillis,
    automationsJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PersonRow &&
          other.id == this.id &&
          other.lookupKey == this.lookupKey &&
          other.displayName == this.displayName &&
          other.channel == this.channel &&
          other.handle == this.handle &&
          other.createdAtMillis == this.createdAtMillis &&
          other.cadenceType == this.cadenceType &&
          other.nDays == this.nDays &&
          other.weekday == this.weekday &&
          other.dayOfMonth == this.dayOfMonth &&
          other.monthOfYear == this.monthOfYear &&
          other.anchoredToWakeup == this.anchoredToWakeup &&
          other.missionChainJson == this.missionChainJson &&
          other.pausedUntilMillis == this.pausedUntilMillis &&
          other.automationsJson == this.automationsJson);
}

class PeopleCompanion extends UpdateCompanion<PersonRow> {
  final Value<String> id;
  final Value<String> lookupKey;
  final Value<String> displayName;
  final Value<String> channel;
  final Value<String> handle;
  final Value<int> createdAtMillis;
  final Value<String> cadenceType;
  final Value<int?> nDays;
  final Value<int?> weekday;
  final Value<int?> dayOfMonth;
  final Value<int?> monthOfYear;
  final Value<bool> anchoredToWakeup;
  final Value<String?> missionChainJson;
  final Value<int?> pausedUntilMillis;
  final Value<String?> automationsJson;
  final Value<int> rowid;
  const PeopleCompanion({
    this.id = const Value.absent(),
    this.lookupKey = const Value.absent(),
    this.displayName = const Value.absent(),
    this.channel = const Value.absent(),
    this.handle = const Value.absent(),
    this.createdAtMillis = const Value.absent(),
    this.cadenceType = const Value.absent(),
    this.nDays = const Value.absent(),
    this.weekday = const Value.absent(),
    this.dayOfMonth = const Value.absent(),
    this.monthOfYear = const Value.absent(),
    this.anchoredToWakeup = const Value.absent(),
    this.missionChainJson = const Value.absent(),
    this.pausedUntilMillis = const Value.absent(),
    this.automationsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PeopleCompanion.insert({
    required String id,
    required String lookupKey,
    required String displayName,
    required String channel,
    required String handle,
    required int createdAtMillis,
    required String cadenceType,
    this.nDays = const Value.absent(),
    this.weekday = const Value.absent(),
    this.dayOfMonth = const Value.absent(),
    this.monthOfYear = const Value.absent(),
    this.anchoredToWakeup = const Value.absent(),
    this.missionChainJson = const Value.absent(),
    this.pausedUntilMillis = const Value.absent(),
    this.automationsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       lookupKey = Value(lookupKey),
       displayName = Value(displayName),
       channel = Value(channel),
       handle = Value(handle),
       createdAtMillis = Value(createdAtMillis),
       cadenceType = Value(cadenceType);
  static Insertable<PersonRow> custom({
    Expression<String>? id,
    Expression<String>? lookupKey,
    Expression<String>? displayName,
    Expression<String>? channel,
    Expression<String>? handle,
    Expression<int>? createdAtMillis,
    Expression<String>? cadenceType,
    Expression<int>? nDays,
    Expression<int>? weekday,
    Expression<int>? dayOfMonth,
    Expression<int>? monthOfYear,
    Expression<bool>? anchoredToWakeup,
    Expression<String>? missionChainJson,
    Expression<int>? pausedUntilMillis,
    Expression<String>? automationsJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lookupKey != null) 'lookup_key': lookupKey,
      if (displayName != null) 'display_name': displayName,
      if (channel != null) 'channel': channel,
      if (handle != null) 'handle': handle,
      if (createdAtMillis != null) 'created_at_millis': createdAtMillis,
      if (cadenceType != null) 'cadence_type': cadenceType,
      if (nDays != null) 'n_days': nDays,
      if (weekday != null) 'weekday': weekday,
      if (dayOfMonth != null) 'day_of_month': dayOfMonth,
      if (monthOfYear != null) 'month_of_year': monthOfYear,
      if (anchoredToWakeup != null) 'anchored_to_wakeup': anchoredToWakeup,
      if (missionChainJson != null) 'mission_chain_json': missionChainJson,
      if (pausedUntilMillis != null) 'paused_until_millis': pausedUntilMillis,
      if (automationsJson != null) 'automations_json': automationsJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PeopleCompanion copyWith({
    Value<String>? id,
    Value<String>? lookupKey,
    Value<String>? displayName,
    Value<String>? channel,
    Value<String>? handle,
    Value<int>? createdAtMillis,
    Value<String>? cadenceType,
    Value<int?>? nDays,
    Value<int?>? weekday,
    Value<int?>? dayOfMonth,
    Value<int?>? monthOfYear,
    Value<bool>? anchoredToWakeup,
    Value<String?>? missionChainJson,
    Value<int?>? pausedUntilMillis,
    Value<String?>? automationsJson,
    Value<int>? rowid,
  }) {
    return PeopleCompanion(
      id: id ?? this.id,
      lookupKey: lookupKey ?? this.lookupKey,
      displayName: displayName ?? this.displayName,
      channel: channel ?? this.channel,
      handle: handle ?? this.handle,
      createdAtMillis: createdAtMillis ?? this.createdAtMillis,
      cadenceType: cadenceType ?? this.cadenceType,
      nDays: nDays ?? this.nDays,
      weekday: weekday ?? this.weekday,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      monthOfYear: monthOfYear ?? this.monthOfYear,
      anchoredToWakeup: anchoredToWakeup ?? this.anchoredToWakeup,
      missionChainJson: missionChainJson ?? this.missionChainJson,
      pausedUntilMillis: pausedUntilMillis ?? this.pausedUntilMillis,
      automationsJson: automationsJson ?? this.automationsJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (lookupKey.present) {
      map['lookup_key'] = Variable<String>(lookupKey.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (channel.present) {
      map['channel'] = Variable<String>(channel.value);
    }
    if (handle.present) {
      map['handle'] = Variable<String>(handle.value);
    }
    if (createdAtMillis.present) {
      map['created_at_millis'] = Variable<int>(createdAtMillis.value);
    }
    if (cadenceType.present) {
      map['cadence_type'] = Variable<String>(cadenceType.value);
    }
    if (nDays.present) {
      map['n_days'] = Variable<int>(nDays.value);
    }
    if (weekday.present) {
      map['weekday'] = Variable<int>(weekday.value);
    }
    if (dayOfMonth.present) {
      map['day_of_month'] = Variable<int>(dayOfMonth.value);
    }
    if (monthOfYear.present) {
      map['month_of_year'] = Variable<int>(monthOfYear.value);
    }
    if (anchoredToWakeup.present) {
      map['anchored_to_wakeup'] = Variable<bool>(anchoredToWakeup.value);
    }
    if (missionChainJson.present) {
      map['mission_chain_json'] = Variable<String>(missionChainJson.value);
    }
    if (pausedUntilMillis.present) {
      map['paused_until_millis'] = Variable<int>(pausedUntilMillis.value);
    }
    if (automationsJson.present) {
      map['automations_json'] = Variable<String>(automationsJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PeopleCompanion(')
          ..write('id: $id, ')
          ..write('lookupKey: $lookupKey, ')
          ..write('displayName: $displayName, ')
          ..write('channel: $channel, ')
          ..write('handle: $handle, ')
          ..write('createdAtMillis: $createdAtMillis, ')
          ..write('cadenceType: $cadenceType, ')
          ..write('nDays: $nDays, ')
          ..write('weekday: $weekday, ')
          ..write('dayOfMonth: $dayOfMonth, ')
          ..write('monthOfYear: $monthOfYear, ')
          ..write('anchoredToWakeup: $anchoredToWakeup, ')
          ..write('missionChainJson: $missionChainJson, ')
          ..write('pausedUntilMillis: $pausedUntilMillis, ')
          ..write('automationsJson: $automationsJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CompletionsTable extends Completions
    with TableInfo<$CompletionsTable, CompletionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CompletionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _habitIdMeta = const VerificationMeta(
    'habitId',
  );
  @override
  late final GeneratedColumn<String> habitId = GeneratedColumn<String>(
    'habit_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayMillisMeta = const VerificationMeta(
    'dayMillis',
  );
  @override
  late final GeneratedColumn<int> dayMillis = GeneratedColumn<int>(
    'day_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMillisMeta = const VerificationMeta(
    'completedAtMillis',
  );
  @override
  late final GeneratedColumn<int> completedAtMillis = GeneratedColumn<int>(
    'completed_at_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _proofModeAtTimeMeta = const VerificationMeta(
    'proofModeAtTime',
  );
  @override
  late final GeneratedColumn<String> proofModeAtTime = GeneratedColumn<String>(
    'proof_mode_at_time',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _missionResultsJsonMeta =
      const VerificationMeta('missionResultsJson');
  @override
  late final GeneratedColumn<String> missionResultsJson =
      GeneratedColumn<String>(
        'mission_results_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    habitId,
    dayMillis,
    completedAtMillis,
    source,
    proofModeAtTime,
    note,
    missionResultsJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'completions';
  @override
  VerificationContext validateIntegrity(
    Insertable<CompletionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('habit_id')) {
      context.handle(
        _habitIdMeta,
        habitId.isAcceptableOrUnknown(data['habit_id']!, _habitIdMeta),
      );
    } else if (isInserting) {
      context.missing(_habitIdMeta);
    }
    if (data.containsKey('day_millis')) {
      context.handle(
        _dayMillisMeta,
        dayMillis.isAcceptableOrUnknown(data['day_millis']!, _dayMillisMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMillisMeta);
    }
    if (data.containsKey('completed_at_millis')) {
      context.handle(
        _completedAtMillisMeta,
        completedAtMillis.isAcceptableOrUnknown(
          data['completed_at_millis']!,
          _completedAtMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completedAtMillisMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('proof_mode_at_time')) {
      context.handle(
        _proofModeAtTimeMeta,
        proofModeAtTime.isAcceptableOrUnknown(
          data['proof_mode_at_time']!,
          _proofModeAtTimeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_proofModeAtTimeMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('mission_results_json')) {
      context.handle(
        _missionResultsJsonMeta,
        missionResultsJson.isAcceptableOrUnknown(
          data['mission_results_json']!,
          _missionResultsJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CompletionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CompletionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      habitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}habit_id'],
      )!,
      dayMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_millis'],
      )!,
      completedAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at_millis'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      proofModeAtTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}proof_mode_at_time'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      missionResultsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mission_results_json'],
      ),
    );
  }

  @override
  $CompletionsTable createAlias(String alias) {
    return $CompletionsTable(attachedDatabase, alias);
  }
}

class CompletionRow extends DataClass implements Insertable<CompletionRow> {
  final String id;
  final String habitId;
  final int dayMillis;
  final int completedAtMillis;
  final String source;
  final String proofModeAtTime;
  final String? note;
  final String? missionResultsJson;
  const CompletionRow({
    required this.id,
    required this.habitId,
    required this.dayMillis,
    required this.completedAtMillis,
    required this.source,
    required this.proofModeAtTime,
    this.note,
    this.missionResultsJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['habit_id'] = Variable<String>(habitId);
    map['day_millis'] = Variable<int>(dayMillis);
    map['completed_at_millis'] = Variable<int>(completedAtMillis);
    map['source'] = Variable<String>(source);
    map['proof_mode_at_time'] = Variable<String>(proofModeAtTime);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || missionResultsJson != null) {
      map['mission_results_json'] = Variable<String>(missionResultsJson);
    }
    return map;
  }

  CompletionsCompanion toCompanion(bool nullToAbsent) {
    return CompletionsCompanion(
      id: Value(id),
      habitId: Value(habitId),
      dayMillis: Value(dayMillis),
      completedAtMillis: Value(completedAtMillis),
      source: Value(source),
      proofModeAtTime: Value(proofModeAtTime),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      missionResultsJson: missionResultsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(missionResultsJson),
    );
  }

  factory CompletionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CompletionRow(
      id: serializer.fromJson<String>(json['id']),
      habitId: serializer.fromJson<String>(json['habitId']),
      dayMillis: serializer.fromJson<int>(json['dayMillis']),
      completedAtMillis: serializer.fromJson<int>(json['completedAtMillis']),
      source: serializer.fromJson<String>(json['source']),
      proofModeAtTime: serializer.fromJson<String>(json['proofModeAtTime']),
      note: serializer.fromJson<String?>(json['note']),
      missionResultsJson: serializer.fromJson<String?>(
        json['missionResultsJson'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'habitId': serializer.toJson<String>(habitId),
      'dayMillis': serializer.toJson<int>(dayMillis),
      'completedAtMillis': serializer.toJson<int>(completedAtMillis),
      'source': serializer.toJson<String>(source),
      'proofModeAtTime': serializer.toJson<String>(proofModeAtTime),
      'note': serializer.toJson<String?>(note),
      'missionResultsJson': serializer.toJson<String?>(missionResultsJson),
    };
  }

  CompletionRow copyWith({
    String? id,
    String? habitId,
    int? dayMillis,
    int? completedAtMillis,
    String? source,
    String? proofModeAtTime,
    Value<String?> note = const Value.absent(),
    Value<String?> missionResultsJson = const Value.absent(),
  }) => CompletionRow(
    id: id ?? this.id,
    habitId: habitId ?? this.habitId,
    dayMillis: dayMillis ?? this.dayMillis,
    completedAtMillis: completedAtMillis ?? this.completedAtMillis,
    source: source ?? this.source,
    proofModeAtTime: proofModeAtTime ?? this.proofModeAtTime,
    note: note.present ? note.value : this.note,
    missionResultsJson: missionResultsJson.present
        ? missionResultsJson.value
        : this.missionResultsJson,
  );
  CompletionRow copyWithCompanion(CompletionsCompanion data) {
    return CompletionRow(
      id: data.id.present ? data.id.value : this.id,
      habitId: data.habitId.present ? data.habitId.value : this.habitId,
      dayMillis: data.dayMillis.present ? data.dayMillis.value : this.dayMillis,
      completedAtMillis: data.completedAtMillis.present
          ? data.completedAtMillis.value
          : this.completedAtMillis,
      source: data.source.present ? data.source.value : this.source,
      proofModeAtTime: data.proofModeAtTime.present
          ? data.proofModeAtTime.value
          : this.proofModeAtTime,
      note: data.note.present ? data.note.value : this.note,
      missionResultsJson: data.missionResultsJson.present
          ? data.missionResultsJson.value
          : this.missionResultsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CompletionRow(')
          ..write('id: $id, ')
          ..write('habitId: $habitId, ')
          ..write('dayMillis: $dayMillis, ')
          ..write('completedAtMillis: $completedAtMillis, ')
          ..write('source: $source, ')
          ..write('proofModeAtTime: $proofModeAtTime, ')
          ..write('note: $note, ')
          ..write('missionResultsJson: $missionResultsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    habitId,
    dayMillis,
    completedAtMillis,
    source,
    proofModeAtTime,
    note,
    missionResultsJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CompletionRow &&
          other.id == this.id &&
          other.habitId == this.habitId &&
          other.dayMillis == this.dayMillis &&
          other.completedAtMillis == this.completedAtMillis &&
          other.source == this.source &&
          other.proofModeAtTime == this.proofModeAtTime &&
          other.note == this.note &&
          other.missionResultsJson == this.missionResultsJson);
}

class CompletionsCompanion extends UpdateCompanion<CompletionRow> {
  final Value<String> id;
  final Value<String> habitId;
  final Value<int> dayMillis;
  final Value<int> completedAtMillis;
  final Value<String> source;
  final Value<String> proofModeAtTime;
  final Value<String?> note;
  final Value<String?> missionResultsJson;
  final Value<int> rowid;
  const CompletionsCompanion({
    this.id = const Value.absent(),
    this.habitId = const Value.absent(),
    this.dayMillis = const Value.absent(),
    this.completedAtMillis = const Value.absent(),
    this.source = const Value.absent(),
    this.proofModeAtTime = const Value.absent(),
    this.note = const Value.absent(),
    this.missionResultsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CompletionsCompanion.insert({
    required String id,
    required String habitId,
    required int dayMillis,
    required int completedAtMillis,
    required String source,
    required String proofModeAtTime,
    this.note = const Value.absent(),
    this.missionResultsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       habitId = Value(habitId),
       dayMillis = Value(dayMillis),
       completedAtMillis = Value(completedAtMillis),
       source = Value(source),
       proofModeAtTime = Value(proofModeAtTime);
  static Insertable<CompletionRow> custom({
    Expression<String>? id,
    Expression<String>? habitId,
    Expression<int>? dayMillis,
    Expression<int>? completedAtMillis,
    Expression<String>? source,
    Expression<String>? proofModeAtTime,
    Expression<String>? note,
    Expression<String>? missionResultsJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (habitId != null) 'habit_id': habitId,
      if (dayMillis != null) 'day_millis': dayMillis,
      if (completedAtMillis != null) 'completed_at_millis': completedAtMillis,
      if (source != null) 'source': source,
      if (proofModeAtTime != null) 'proof_mode_at_time': proofModeAtTime,
      if (note != null) 'note': note,
      if (missionResultsJson != null)
        'mission_results_json': missionResultsJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CompletionsCompanion copyWith({
    Value<String>? id,
    Value<String>? habitId,
    Value<int>? dayMillis,
    Value<int>? completedAtMillis,
    Value<String>? source,
    Value<String>? proofModeAtTime,
    Value<String?>? note,
    Value<String?>? missionResultsJson,
    Value<int>? rowid,
  }) {
    return CompletionsCompanion(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      dayMillis: dayMillis ?? this.dayMillis,
      completedAtMillis: completedAtMillis ?? this.completedAtMillis,
      source: source ?? this.source,
      proofModeAtTime: proofModeAtTime ?? this.proofModeAtTime,
      note: note ?? this.note,
      missionResultsJson: missionResultsJson ?? this.missionResultsJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (habitId.present) {
      map['habit_id'] = Variable<String>(habitId.value);
    }
    if (dayMillis.present) {
      map['day_millis'] = Variable<int>(dayMillis.value);
    }
    if (completedAtMillis.present) {
      map['completed_at_millis'] = Variable<int>(completedAtMillis.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (proofModeAtTime.present) {
      map['proof_mode_at_time'] = Variable<String>(proofModeAtTime.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (missionResultsJson.present) {
      map['mission_results_json'] = Variable<String>(missionResultsJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CompletionsCompanion(')
          ..write('id: $id, ')
          ..write('habitId: $habitId, ')
          ..write('dayMillis: $dayMillis, ')
          ..write('completedAtMillis: $completedAtMillis, ')
          ..write('source: $source, ')
          ..write('proofModeAtTime: $proofModeAtTime, ')
          ..write('note: $note, ')
          ..write('missionResultsJson: $missionResultsJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RestDayBudgetsTable extends RestDayBudgets
    with TableInfo<$RestDayBudgetsTable, RestDayBudgetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RestDayBudgetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _habitIdMeta = const VerificationMeta(
    'habitId',
  );
  @override
  late final GeneratedColumn<String> habitId = GeneratedColumn<String>(
    'habit_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yearMonthMeta = const VerificationMeta(
    'yearMonth',
  );
  @override
  late final GeneratedColumn<int> yearMonth = GeneratedColumn<int>(
    'year_month',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usedMeta = const VerificationMeta('used');
  @override
  late final GeneratedColumn<int> used = GeneratedColumn<int>(
    'used',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _monthlyLimitMeta = const VerificationMeta(
    'monthlyLimit',
  );
  @override
  late final GeneratedColumn<int> monthlyLimit = GeneratedColumn<int>(
    'monthly_limit',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    habitId,
    yearMonth,
    used,
    monthlyLimit,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rest_day_budgets';
  @override
  VerificationContext validateIntegrity(
    Insertable<RestDayBudgetRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('habit_id')) {
      context.handle(
        _habitIdMeta,
        habitId.isAcceptableOrUnknown(data['habit_id']!, _habitIdMeta),
      );
    } else if (isInserting) {
      context.missing(_habitIdMeta);
    }
    if (data.containsKey('year_month')) {
      context.handle(
        _yearMonthMeta,
        yearMonth.isAcceptableOrUnknown(data['year_month']!, _yearMonthMeta),
      );
    } else if (isInserting) {
      context.missing(_yearMonthMeta);
    }
    if (data.containsKey('used')) {
      context.handle(
        _usedMeta,
        used.isAcceptableOrUnknown(data['used']!, _usedMeta),
      );
    }
    if (data.containsKey('monthly_limit')) {
      context.handle(
        _monthlyLimitMeta,
        monthlyLimit.isAcceptableOrUnknown(
          data['monthly_limit']!,
          _monthlyLimitMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_monthlyLimitMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RestDayBudgetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RestDayBudgetRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      habitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}habit_id'],
      )!,
      yearMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year_month'],
      )!,
      used: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}used'],
      )!,
      monthlyLimit: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}monthly_limit'],
      )!,
    );
  }

  @override
  $RestDayBudgetsTable createAlias(String alias) {
    return $RestDayBudgetsTable(attachedDatabase, alias);
  }
}

class RestDayBudgetRow extends DataClass
    implements Insertable<RestDayBudgetRow> {
  final String id;
  final String habitId;
  final int yearMonth;
  final int used;
  final int monthlyLimit;
  const RestDayBudgetRow({
    required this.id,
    required this.habitId,
    required this.yearMonth,
    required this.used,
    required this.monthlyLimit,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['habit_id'] = Variable<String>(habitId);
    map['year_month'] = Variable<int>(yearMonth);
    map['used'] = Variable<int>(used);
    map['monthly_limit'] = Variable<int>(monthlyLimit);
    return map;
  }

  RestDayBudgetsCompanion toCompanion(bool nullToAbsent) {
    return RestDayBudgetsCompanion(
      id: Value(id),
      habitId: Value(habitId),
      yearMonth: Value(yearMonth),
      used: Value(used),
      monthlyLimit: Value(monthlyLimit),
    );
  }

  factory RestDayBudgetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RestDayBudgetRow(
      id: serializer.fromJson<String>(json['id']),
      habitId: serializer.fromJson<String>(json['habitId']),
      yearMonth: serializer.fromJson<int>(json['yearMonth']),
      used: serializer.fromJson<int>(json['used']),
      monthlyLimit: serializer.fromJson<int>(json['monthlyLimit']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'habitId': serializer.toJson<String>(habitId),
      'yearMonth': serializer.toJson<int>(yearMonth),
      'used': serializer.toJson<int>(used),
      'monthlyLimit': serializer.toJson<int>(monthlyLimit),
    };
  }

  RestDayBudgetRow copyWith({
    String? id,
    String? habitId,
    int? yearMonth,
    int? used,
    int? monthlyLimit,
  }) => RestDayBudgetRow(
    id: id ?? this.id,
    habitId: habitId ?? this.habitId,
    yearMonth: yearMonth ?? this.yearMonth,
    used: used ?? this.used,
    monthlyLimit: monthlyLimit ?? this.monthlyLimit,
  );
  RestDayBudgetRow copyWithCompanion(RestDayBudgetsCompanion data) {
    return RestDayBudgetRow(
      id: data.id.present ? data.id.value : this.id,
      habitId: data.habitId.present ? data.habitId.value : this.habitId,
      yearMonth: data.yearMonth.present ? data.yearMonth.value : this.yearMonth,
      used: data.used.present ? data.used.value : this.used,
      monthlyLimit: data.monthlyLimit.present
          ? data.monthlyLimit.value
          : this.monthlyLimit,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RestDayBudgetRow(')
          ..write('id: $id, ')
          ..write('habitId: $habitId, ')
          ..write('yearMonth: $yearMonth, ')
          ..write('used: $used, ')
          ..write('monthlyLimit: $monthlyLimit')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, habitId, yearMonth, used, monthlyLimit);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RestDayBudgetRow &&
          other.id == this.id &&
          other.habitId == this.habitId &&
          other.yearMonth == this.yearMonth &&
          other.used == this.used &&
          other.monthlyLimit == this.monthlyLimit);
}

class RestDayBudgetsCompanion extends UpdateCompanion<RestDayBudgetRow> {
  final Value<String> id;
  final Value<String> habitId;
  final Value<int> yearMonth;
  final Value<int> used;
  final Value<int> monthlyLimit;
  final Value<int> rowid;
  const RestDayBudgetsCompanion({
    this.id = const Value.absent(),
    this.habitId = const Value.absent(),
    this.yearMonth = const Value.absent(),
    this.used = const Value.absent(),
    this.monthlyLimit = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RestDayBudgetsCompanion.insert({
    required String id,
    required String habitId,
    required int yearMonth,
    this.used = const Value.absent(),
    required int monthlyLimit,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       habitId = Value(habitId),
       yearMonth = Value(yearMonth),
       monthlyLimit = Value(monthlyLimit);
  static Insertable<RestDayBudgetRow> custom({
    Expression<String>? id,
    Expression<String>? habitId,
    Expression<int>? yearMonth,
    Expression<int>? used,
    Expression<int>? monthlyLimit,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (habitId != null) 'habit_id': habitId,
      if (yearMonth != null) 'year_month': yearMonth,
      if (used != null) 'used': used,
      if (monthlyLimit != null) 'monthly_limit': monthlyLimit,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RestDayBudgetsCompanion copyWith({
    Value<String>? id,
    Value<String>? habitId,
    Value<int>? yearMonth,
    Value<int>? used,
    Value<int>? monthlyLimit,
    Value<int>? rowid,
  }) {
    return RestDayBudgetsCompanion(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      yearMonth: yearMonth ?? this.yearMonth,
      used: used ?? this.used,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (habitId.present) {
      map['habit_id'] = Variable<String>(habitId.value);
    }
    if (yearMonth.present) {
      map['year_month'] = Variable<int>(yearMonth.value);
    }
    if (used.present) {
      map['used'] = Variable<int>(used.value);
    }
    if (monthlyLimit.present) {
      map['monthly_limit'] = Variable<int>(monthlyLimit.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RestDayBudgetsCompanion(')
          ..write('id: $id, ')
          ..write('habitId: $habitId, ')
          ..write('yearMonth: $yearMonth, ')
          ..write('used: $used, ')
          ..write('monthlyLimit: $monthlyLimit, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingRow copyWith({String? key, String? value}) =>
      SettingRow(key: key ?? this.key, value: value ?? this.value);
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EventLogsTable extends EventLogs
    with TableInfo<$EventLogsTable, EventLogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atMillisMeta = const VerificationMeta(
    'atMillis',
  );
  @override
  late final GeneratedColumn<int> atMillis = GeneratedColumn<int>(
    'at_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detailJsonMeta = const VerificationMeta(
    'detailJson',
  );
  @override
  late final GeneratedColumn<String> detailJson = GeneratedColumn<String>(
    'detail_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, atMillis, kind, detailJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'event_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<EventLogRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('at_millis')) {
      context.handle(
        _atMillisMeta,
        atMillis.isAcceptableOrUnknown(data['at_millis']!, _atMillisMeta),
      );
    } else if (isInserting) {
      context.missing(_atMillisMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('detail_json')) {
      context.handle(
        _detailJsonMeta,
        detailJson.isAcceptableOrUnknown(data['detail_json']!, _detailJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  EventLogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EventLogRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      atMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at_millis'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      detailJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail_json'],
      ),
    );
  }

  @override
  $EventLogsTable createAlias(String alias) {
    return $EventLogsTable(attachedDatabase, alias);
  }
}

class EventLogRow extends DataClass implements Insertable<EventLogRow> {
  final String id;
  final int atMillis;
  final String kind;
  final String? detailJson;
  const EventLogRow({
    required this.id,
    required this.atMillis,
    required this.kind,
    this.detailJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['at_millis'] = Variable<int>(atMillis);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || detailJson != null) {
      map['detail_json'] = Variable<String>(detailJson);
    }
    return map;
  }

  EventLogsCompanion toCompanion(bool nullToAbsent) {
    return EventLogsCompanion(
      id: Value(id),
      atMillis: Value(atMillis),
      kind: Value(kind),
      detailJson: detailJson == null && nullToAbsent
          ? const Value.absent()
          : Value(detailJson),
    );
  }

  factory EventLogRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EventLogRow(
      id: serializer.fromJson<String>(json['id']),
      atMillis: serializer.fromJson<int>(json['atMillis']),
      kind: serializer.fromJson<String>(json['kind']),
      detailJson: serializer.fromJson<String?>(json['detailJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'atMillis': serializer.toJson<int>(atMillis),
      'kind': serializer.toJson<String>(kind),
      'detailJson': serializer.toJson<String?>(detailJson),
    };
  }

  EventLogRow copyWith({
    String? id,
    int? atMillis,
    String? kind,
    Value<String?> detailJson = const Value.absent(),
  }) => EventLogRow(
    id: id ?? this.id,
    atMillis: atMillis ?? this.atMillis,
    kind: kind ?? this.kind,
    detailJson: detailJson.present ? detailJson.value : this.detailJson,
  );
  EventLogRow copyWithCompanion(EventLogsCompanion data) {
    return EventLogRow(
      id: data.id.present ? data.id.value : this.id,
      atMillis: data.atMillis.present ? data.atMillis.value : this.atMillis,
      kind: data.kind.present ? data.kind.value : this.kind,
      detailJson: data.detailJson.present
          ? data.detailJson.value
          : this.detailJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EventLogRow(')
          ..write('id: $id, ')
          ..write('atMillis: $atMillis, ')
          ..write('kind: $kind, ')
          ..write('detailJson: $detailJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, atMillis, kind, detailJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventLogRow &&
          other.id == this.id &&
          other.atMillis == this.atMillis &&
          other.kind == this.kind &&
          other.detailJson == this.detailJson);
}

class EventLogsCompanion extends UpdateCompanion<EventLogRow> {
  final Value<String> id;
  final Value<int> atMillis;
  final Value<String> kind;
  final Value<String?> detailJson;
  final Value<int> rowid;
  const EventLogsCompanion({
    this.id = const Value.absent(),
    this.atMillis = const Value.absent(),
    this.kind = const Value.absent(),
    this.detailJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EventLogsCompanion.insert({
    required String id,
    required int atMillis,
    required String kind,
    this.detailJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       atMillis = Value(atMillis),
       kind = Value(kind);
  static Insertable<EventLogRow> custom({
    Expression<String>? id,
    Expression<int>? atMillis,
    Expression<String>? kind,
    Expression<String>? detailJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (atMillis != null) 'at_millis': atMillis,
      if (kind != null) 'kind': kind,
      if (detailJson != null) 'detail_json': detailJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EventLogsCompanion copyWith({
    Value<String>? id,
    Value<int>? atMillis,
    Value<String>? kind,
    Value<String?>? detailJson,
    Value<int>? rowid,
  }) {
    return EventLogsCompanion(
      id: id ?? this.id,
      atMillis: atMillis ?? this.atMillis,
      kind: kind ?? this.kind,
      detailJson: detailJson ?? this.detailJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (atMillis.present) {
      map['at_millis'] = Variable<int>(atMillis.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (detailJson.present) {
      map['detail_json'] = Variable<String>(detailJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventLogsCompanion(')
          ..write('id: $id, ')
          ..write('atMillis: $atMillis, ')
          ..write('kind: $kind, ')
          ..write('detailJson: $detailJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EventsTable extends Events with TableInfo<$EventsTable, EventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atMillisMeta = const VerificationMeta(
    'atMillis',
  );
  @override
  late final GeneratedColumn<int> atMillis = GeneratedColumn<int>(
    'at_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _leadTimeMillisMeta = const VerificationMeta(
    'leadTimeMillis',
  );
  @override
  late final GeneratedColumn<int> leadTimeMillis = GeneratedColumn<int>(
    'lead_time_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _missionChainJsonMeta = const VerificationMeta(
    'missionChainJson',
  );
  @override
  late final GeneratedColumn<String> missionChainJson = GeneratedColumn<String>(
    'mission_chain_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recurrenceMeta = const VerificationMeta(
    'recurrence',
  );
  @override
  late final GeneratedColumn<String> recurrence = GeneratedColumn<String>(
    'recurrence',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('none'),
  );
  static const VerificationMeta _archivedAtMillisMeta = const VerificationMeta(
    'archivedAtMillis',
  );
  @override
  late final GeneratedColumn<int> archivedAtMillis = GeneratedColumn<int>(
    'archived_at_millis',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMillisMeta = const VerificationMeta(
    'createdAtMillis',
  );
  @override
  late final GeneratedColumn<int> createdAtMillis = GeneratedColumn<int>(
    'created_at_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _automationsJsonMeta = const VerificationMeta(
    'automationsJson',
  );
  @override
  late final GeneratedColumn<String> automationsJson = GeneratedColumn<String>(
    'automations_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    atMillis,
    leadTimeMillis,
    missionChainJson,
    recurrence,
    archivedAtMillis,
    createdAtMillis,
    automationsJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'events';
  @override
  VerificationContext validateIntegrity(
    Insertable<EventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('at_millis')) {
      context.handle(
        _atMillisMeta,
        atMillis.isAcceptableOrUnknown(data['at_millis']!, _atMillisMeta),
      );
    } else if (isInserting) {
      context.missing(_atMillisMeta);
    }
    if (data.containsKey('lead_time_millis')) {
      context.handle(
        _leadTimeMillisMeta,
        leadTimeMillis.isAcceptableOrUnknown(
          data['lead_time_millis']!,
          _leadTimeMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_leadTimeMillisMeta);
    }
    if (data.containsKey('mission_chain_json')) {
      context.handle(
        _missionChainJsonMeta,
        missionChainJson.isAcceptableOrUnknown(
          data['mission_chain_json']!,
          _missionChainJsonMeta,
        ),
      );
    }
    if (data.containsKey('recurrence')) {
      context.handle(
        _recurrenceMeta,
        recurrence.isAcceptableOrUnknown(data['recurrence']!, _recurrenceMeta),
      );
    }
    if (data.containsKey('archived_at_millis')) {
      context.handle(
        _archivedAtMillisMeta,
        archivedAtMillis.isAcceptableOrUnknown(
          data['archived_at_millis']!,
          _archivedAtMillisMeta,
        ),
      );
    }
    if (data.containsKey('created_at_millis')) {
      context.handle(
        _createdAtMillisMeta,
        createdAtMillis.isAcceptableOrUnknown(
          data['created_at_millis']!,
          _createdAtMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMillisMeta);
    }
    if (data.containsKey('automations_json')) {
      context.handle(
        _automationsJsonMeta,
        automationsJson.isAcceptableOrUnknown(
          data['automations_json']!,
          _automationsJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      atMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at_millis'],
      )!,
      leadTimeMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lead_time_millis'],
      )!,
      missionChainJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mission_chain_json'],
      ),
      recurrence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence'],
      )!,
      archivedAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}archived_at_millis'],
      ),
      createdAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_millis'],
      )!,
      automationsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}automations_json'],
      ),
    );
  }

  @override
  $EventsTable createAlias(String alias) {
    return $EventsTable(attachedDatabase, alias);
  }
}

class EventRow extends DataClass implements Insertable<EventRow> {
  final String id;
  final String name;
  final int atMillis;
  final int leadTimeMillis;
  final String? missionChainJson;
  final String recurrence;
  final int? archivedAtMillis;
  final int createdAtMillis;
  final String? automationsJson;
  const EventRow({
    required this.id,
    required this.name,
    required this.atMillis,
    required this.leadTimeMillis,
    this.missionChainJson,
    required this.recurrence,
    this.archivedAtMillis,
    required this.createdAtMillis,
    this.automationsJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['at_millis'] = Variable<int>(atMillis);
    map['lead_time_millis'] = Variable<int>(leadTimeMillis);
    if (!nullToAbsent || missionChainJson != null) {
      map['mission_chain_json'] = Variable<String>(missionChainJson);
    }
    map['recurrence'] = Variable<String>(recurrence);
    if (!nullToAbsent || archivedAtMillis != null) {
      map['archived_at_millis'] = Variable<int>(archivedAtMillis);
    }
    map['created_at_millis'] = Variable<int>(createdAtMillis);
    if (!nullToAbsent || automationsJson != null) {
      map['automations_json'] = Variable<String>(automationsJson);
    }
    return map;
  }

  EventsCompanion toCompanion(bool nullToAbsent) {
    return EventsCompanion(
      id: Value(id),
      name: Value(name),
      atMillis: Value(atMillis),
      leadTimeMillis: Value(leadTimeMillis),
      missionChainJson: missionChainJson == null && nullToAbsent
          ? const Value.absent()
          : Value(missionChainJson),
      recurrence: Value(recurrence),
      archivedAtMillis: archivedAtMillis == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAtMillis),
      createdAtMillis: Value(createdAtMillis),
      automationsJson: automationsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(automationsJson),
    );
  }

  factory EventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EventRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      atMillis: serializer.fromJson<int>(json['atMillis']),
      leadTimeMillis: serializer.fromJson<int>(json['leadTimeMillis']),
      missionChainJson: serializer.fromJson<String?>(json['missionChainJson']),
      recurrence: serializer.fromJson<String>(json['recurrence']),
      archivedAtMillis: serializer.fromJson<int?>(json['archivedAtMillis']),
      createdAtMillis: serializer.fromJson<int>(json['createdAtMillis']),
      automationsJson: serializer.fromJson<String?>(json['automationsJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'atMillis': serializer.toJson<int>(atMillis),
      'leadTimeMillis': serializer.toJson<int>(leadTimeMillis),
      'missionChainJson': serializer.toJson<String?>(missionChainJson),
      'recurrence': serializer.toJson<String>(recurrence),
      'archivedAtMillis': serializer.toJson<int?>(archivedAtMillis),
      'createdAtMillis': serializer.toJson<int>(createdAtMillis),
      'automationsJson': serializer.toJson<String?>(automationsJson),
    };
  }

  EventRow copyWith({
    String? id,
    String? name,
    int? atMillis,
    int? leadTimeMillis,
    Value<String?> missionChainJson = const Value.absent(),
    String? recurrence,
    Value<int?> archivedAtMillis = const Value.absent(),
    int? createdAtMillis,
    Value<String?> automationsJson = const Value.absent(),
  }) => EventRow(
    id: id ?? this.id,
    name: name ?? this.name,
    atMillis: atMillis ?? this.atMillis,
    leadTimeMillis: leadTimeMillis ?? this.leadTimeMillis,
    missionChainJson: missionChainJson.present
        ? missionChainJson.value
        : this.missionChainJson,
    recurrence: recurrence ?? this.recurrence,
    archivedAtMillis: archivedAtMillis.present
        ? archivedAtMillis.value
        : this.archivedAtMillis,
    createdAtMillis: createdAtMillis ?? this.createdAtMillis,
    automationsJson: automationsJson.present
        ? automationsJson.value
        : this.automationsJson,
  );
  EventRow copyWithCompanion(EventsCompanion data) {
    return EventRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      atMillis: data.atMillis.present ? data.atMillis.value : this.atMillis,
      leadTimeMillis: data.leadTimeMillis.present
          ? data.leadTimeMillis.value
          : this.leadTimeMillis,
      missionChainJson: data.missionChainJson.present
          ? data.missionChainJson.value
          : this.missionChainJson,
      recurrence: data.recurrence.present
          ? data.recurrence.value
          : this.recurrence,
      archivedAtMillis: data.archivedAtMillis.present
          ? data.archivedAtMillis.value
          : this.archivedAtMillis,
      createdAtMillis: data.createdAtMillis.present
          ? data.createdAtMillis.value
          : this.createdAtMillis,
      automationsJson: data.automationsJson.present
          ? data.automationsJson.value
          : this.automationsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EventRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('atMillis: $atMillis, ')
          ..write('leadTimeMillis: $leadTimeMillis, ')
          ..write('missionChainJson: $missionChainJson, ')
          ..write('recurrence: $recurrence, ')
          ..write('archivedAtMillis: $archivedAtMillis, ')
          ..write('createdAtMillis: $createdAtMillis, ')
          ..write('automationsJson: $automationsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    atMillis,
    leadTimeMillis,
    missionChainJson,
    recurrence,
    archivedAtMillis,
    createdAtMillis,
    automationsJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.atMillis == this.atMillis &&
          other.leadTimeMillis == this.leadTimeMillis &&
          other.missionChainJson == this.missionChainJson &&
          other.recurrence == this.recurrence &&
          other.archivedAtMillis == this.archivedAtMillis &&
          other.createdAtMillis == this.createdAtMillis &&
          other.automationsJson == this.automationsJson);
}

class EventsCompanion extends UpdateCompanion<EventRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> atMillis;
  final Value<int> leadTimeMillis;
  final Value<String?> missionChainJson;
  final Value<String> recurrence;
  final Value<int?> archivedAtMillis;
  final Value<int> createdAtMillis;
  final Value<String?> automationsJson;
  final Value<int> rowid;
  const EventsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.atMillis = const Value.absent(),
    this.leadTimeMillis = const Value.absent(),
    this.missionChainJson = const Value.absent(),
    this.recurrence = const Value.absent(),
    this.archivedAtMillis = const Value.absent(),
    this.createdAtMillis = const Value.absent(),
    this.automationsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EventsCompanion.insert({
    required String id,
    required String name,
    required int atMillis,
    required int leadTimeMillis,
    this.missionChainJson = const Value.absent(),
    this.recurrence = const Value.absent(),
    this.archivedAtMillis = const Value.absent(),
    required int createdAtMillis,
    this.automationsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       atMillis = Value(atMillis),
       leadTimeMillis = Value(leadTimeMillis),
       createdAtMillis = Value(createdAtMillis);
  static Insertable<EventRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? atMillis,
    Expression<int>? leadTimeMillis,
    Expression<String>? missionChainJson,
    Expression<String>? recurrence,
    Expression<int>? archivedAtMillis,
    Expression<int>? createdAtMillis,
    Expression<String>? automationsJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (atMillis != null) 'at_millis': atMillis,
      if (leadTimeMillis != null) 'lead_time_millis': leadTimeMillis,
      if (missionChainJson != null) 'mission_chain_json': missionChainJson,
      if (recurrence != null) 'recurrence': recurrence,
      if (archivedAtMillis != null) 'archived_at_millis': archivedAtMillis,
      if (createdAtMillis != null) 'created_at_millis': createdAtMillis,
      if (automationsJson != null) 'automations_json': automationsJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EventsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? atMillis,
    Value<int>? leadTimeMillis,
    Value<String?>? missionChainJson,
    Value<String>? recurrence,
    Value<int?>? archivedAtMillis,
    Value<int>? createdAtMillis,
    Value<String?>? automationsJson,
    Value<int>? rowid,
  }) {
    return EventsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      atMillis: atMillis ?? this.atMillis,
      leadTimeMillis: leadTimeMillis ?? this.leadTimeMillis,
      missionChainJson: missionChainJson ?? this.missionChainJson,
      recurrence: recurrence ?? this.recurrence,
      archivedAtMillis: archivedAtMillis ?? this.archivedAtMillis,
      createdAtMillis: createdAtMillis ?? this.createdAtMillis,
      automationsJson: automationsJson ?? this.automationsJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (atMillis.present) {
      map['at_millis'] = Variable<int>(atMillis.value);
    }
    if (leadTimeMillis.present) {
      map['lead_time_millis'] = Variable<int>(leadTimeMillis.value);
    }
    if (missionChainJson.present) {
      map['mission_chain_json'] = Variable<String>(missionChainJson.value);
    }
    if (recurrence.present) {
      map['recurrence'] = Variable<String>(recurrence.value);
    }
    if (archivedAtMillis.present) {
      map['archived_at_millis'] = Variable<int>(archivedAtMillis.value);
    }
    if (createdAtMillis.present) {
      map['created_at_millis'] = Variable<int>(createdAtMillis.value);
    }
    if (automationsJson.present) {
      map['automations_json'] = Variable<String>(automationsJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('atMillis: $atMillis, ')
          ..write('leadTimeMillis: $leadTimeMillis, ')
          ..write('missionChainJson: $missionChainJson, ')
          ..write('recurrence: $recurrence, ')
          ..write('archivedAtMillis: $archivedAtMillis, ')
          ..write('createdAtMillis: $createdAtMillis, ')
          ..write('automationsJson: $automationsJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PersonGroupsTable extends PersonGroups
    with TableInfo<$PersonGroupsTable, PersonGroupRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PersonGroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cadenceTypeMeta = const VerificationMeta(
    'cadenceType',
  );
  @override
  late final GeneratedColumn<String> cadenceType = GeneratedColumn<String>(
    'cadence_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _semanticMeta = const VerificationMeta(
    'semantic',
  );
  @override
  late final GeneratedColumn<String> semantic = GeneratedColumn<String>(
    'semantic',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _channelMeta = const VerificationMeta(
    'channel',
  );
  @override
  late final GeneratedColumn<String> channel = GeneratedColumn<String>(
    'channel',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _handleMeta = const VerificationMeta('handle');
  @override
  late final GeneratedColumn<String> handle = GeneratedColumn<String>(
    'handle',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _missionChainJsonMeta = const VerificationMeta(
    'missionChainJson',
  );
  @override
  late final GeneratedColumn<String> missionChainJson = GeneratedColumn<String>(
    'mission_chain_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMillisMeta = const VerificationMeta(
    'createdAtMillis',
  );
  @override
  late final GeneratedColumn<int> createdAtMillis = GeneratedColumn<int>(
    'created_at_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pausedUntilMillisMeta = const VerificationMeta(
    'pausedUntilMillis',
  );
  @override
  late final GeneratedColumn<int> pausedUntilMillis = GeneratedColumn<int>(
    'paused_until_millis',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    cadenceType,
    semantic,
    channel,
    handle,
    missionChainJson,
    createdAtMillis,
    pausedUntilMillis,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'person_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<PersonGroupRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('cadence_type')) {
      context.handle(
        _cadenceTypeMeta,
        cadenceType.isAcceptableOrUnknown(
          data['cadence_type']!,
          _cadenceTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_cadenceTypeMeta);
    }
    if (data.containsKey('semantic')) {
      context.handle(
        _semanticMeta,
        semantic.isAcceptableOrUnknown(data['semantic']!, _semanticMeta),
      );
    } else if (isInserting) {
      context.missing(_semanticMeta);
    }
    if (data.containsKey('channel')) {
      context.handle(
        _channelMeta,
        channel.isAcceptableOrUnknown(data['channel']!, _channelMeta),
      );
    } else if (isInserting) {
      context.missing(_channelMeta);
    }
    if (data.containsKey('handle')) {
      context.handle(
        _handleMeta,
        handle.isAcceptableOrUnknown(data['handle']!, _handleMeta),
      );
    } else if (isInserting) {
      context.missing(_handleMeta);
    }
    if (data.containsKey('mission_chain_json')) {
      context.handle(
        _missionChainJsonMeta,
        missionChainJson.isAcceptableOrUnknown(
          data['mission_chain_json']!,
          _missionChainJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at_millis')) {
      context.handle(
        _createdAtMillisMeta,
        createdAtMillis.isAcceptableOrUnknown(
          data['created_at_millis']!,
          _createdAtMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMillisMeta);
    }
    if (data.containsKey('paused_until_millis')) {
      context.handle(
        _pausedUntilMillisMeta,
        pausedUntilMillis.isAcceptableOrUnknown(
          data['paused_until_millis']!,
          _pausedUntilMillisMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PersonGroupRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PersonGroupRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      cadenceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cadence_type'],
      )!,
      semantic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}semantic'],
      )!,
      channel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel'],
      )!,
      handle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}handle'],
      )!,
      missionChainJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mission_chain_json'],
      ),
      createdAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_millis'],
      )!,
      pausedUntilMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paused_until_millis'],
      ),
    );
  }

  @override
  $PersonGroupsTable createAlias(String alias) {
    return $PersonGroupsTable(attachedDatabase, alias);
  }
}

class PersonGroupRow extends DataClass implements Insertable<PersonGroupRow> {
  final String id;
  final String name;
  final String cadenceType;
  final String semantic;
  final String channel;
  final String handle;
  final String? missionChainJson;
  final int createdAtMillis;
  final int? pausedUntilMillis;
  const PersonGroupRow({
    required this.id,
    required this.name,
    required this.cadenceType,
    required this.semantic,
    required this.channel,
    required this.handle,
    this.missionChainJson,
    required this.createdAtMillis,
    this.pausedUntilMillis,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['cadence_type'] = Variable<String>(cadenceType);
    map['semantic'] = Variable<String>(semantic);
    map['channel'] = Variable<String>(channel);
    map['handle'] = Variable<String>(handle);
    if (!nullToAbsent || missionChainJson != null) {
      map['mission_chain_json'] = Variable<String>(missionChainJson);
    }
    map['created_at_millis'] = Variable<int>(createdAtMillis);
    if (!nullToAbsent || pausedUntilMillis != null) {
      map['paused_until_millis'] = Variable<int>(pausedUntilMillis);
    }
    return map;
  }

  PersonGroupsCompanion toCompanion(bool nullToAbsent) {
    return PersonGroupsCompanion(
      id: Value(id),
      name: Value(name),
      cadenceType: Value(cadenceType),
      semantic: Value(semantic),
      channel: Value(channel),
      handle: Value(handle),
      missionChainJson: missionChainJson == null && nullToAbsent
          ? const Value.absent()
          : Value(missionChainJson),
      createdAtMillis: Value(createdAtMillis),
      pausedUntilMillis: pausedUntilMillis == null && nullToAbsent
          ? const Value.absent()
          : Value(pausedUntilMillis),
    );
  }

  factory PersonGroupRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PersonGroupRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      cadenceType: serializer.fromJson<String>(json['cadenceType']),
      semantic: serializer.fromJson<String>(json['semantic']),
      channel: serializer.fromJson<String>(json['channel']),
      handle: serializer.fromJson<String>(json['handle']),
      missionChainJson: serializer.fromJson<String?>(json['missionChainJson']),
      createdAtMillis: serializer.fromJson<int>(json['createdAtMillis']),
      pausedUntilMillis: serializer.fromJson<int?>(json['pausedUntilMillis']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'cadenceType': serializer.toJson<String>(cadenceType),
      'semantic': serializer.toJson<String>(semantic),
      'channel': serializer.toJson<String>(channel),
      'handle': serializer.toJson<String>(handle),
      'missionChainJson': serializer.toJson<String?>(missionChainJson),
      'createdAtMillis': serializer.toJson<int>(createdAtMillis),
      'pausedUntilMillis': serializer.toJson<int?>(pausedUntilMillis),
    };
  }

  PersonGroupRow copyWith({
    String? id,
    String? name,
    String? cadenceType,
    String? semantic,
    String? channel,
    String? handle,
    Value<String?> missionChainJson = const Value.absent(),
    int? createdAtMillis,
    Value<int?> pausedUntilMillis = const Value.absent(),
  }) => PersonGroupRow(
    id: id ?? this.id,
    name: name ?? this.name,
    cadenceType: cadenceType ?? this.cadenceType,
    semantic: semantic ?? this.semantic,
    channel: channel ?? this.channel,
    handle: handle ?? this.handle,
    missionChainJson: missionChainJson.present
        ? missionChainJson.value
        : this.missionChainJson,
    createdAtMillis: createdAtMillis ?? this.createdAtMillis,
    pausedUntilMillis: pausedUntilMillis.present
        ? pausedUntilMillis.value
        : this.pausedUntilMillis,
  );
  PersonGroupRow copyWithCompanion(PersonGroupsCompanion data) {
    return PersonGroupRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      cadenceType: data.cadenceType.present
          ? data.cadenceType.value
          : this.cadenceType,
      semantic: data.semantic.present ? data.semantic.value : this.semantic,
      channel: data.channel.present ? data.channel.value : this.channel,
      handle: data.handle.present ? data.handle.value : this.handle,
      missionChainJson: data.missionChainJson.present
          ? data.missionChainJson.value
          : this.missionChainJson,
      createdAtMillis: data.createdAtMillis.present
          ? data.createdAtMillis.value
          : this.createdAtMillis,
      pausedUntilMillis: data.pausedUntilMillis.present
          ? data.pausedUntilMillis.value
          : this.pausedUntilMillis,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PersonGroupRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('cadenceType: $cadenceType, ')
          ..write('semantic: $semantic, ')
          ..write('channel: $channel, ')
          ..write('handle: $handle, ')
          ..write('missionChainJson: $missionChainJson, ')
          ..write('createdAtMillis: $createdAtMillis, ')
          ..write('pausedUntilMillis: $pausedUntilMillis')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    cadenceType,
    semantic,
    channel,
    handle,
    missionChainJson,
    createdAtMillis,
    pausedUntilMillis,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PersonGroupRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.cadenceType == this.cadenceType &&
          other.semantic == this.semantic &&
          other.channel == this.channel &&
          other.handle == this.handle &&
          other.missionChainJson == this.missionChainJson &&
          other.createdAtMillis == this.createdAtMillis &&
          other.pausedUntilMillis == this.pausedUntilMillis);
}

class PersonGroupsCompanion extends UpdateCompanion<PersonGroupRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> cadenceType;
  final Value<String> semantic;
  final Value<String> channel;
  final Value<String> handle;
  final Value<String?> missionChainJson;
  final Value<int> createdAtMillis;
  final Value<int?> pausedUntilMillis;
  final Value<int> rowid;
  const PersonGroupsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.cadenceType = const Value.absent(),
    this.semantic = const Value.absent(),
    this.channel = const Value.absent(),
    this.handle = const Value.absent(),
    this.missionChainJson = const Value.absent(),
    this.createdAtMillis = const Value.absent(),
    this.pausedUntilMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PersonGroupsCompanion.insert({
    required String id,
    required String name,
    required String cadenceType,
    required String semantic,
    required String channel,
    required String handle,
    this.missionChainJson = const Value.absent(),
    required int createdAtMillis,
    this.pausedUntilMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       cadenceType = Value(cadenceType),
       semantic = Value(semantic),
       channel = Value(channel),
       handle = Value(handle),
       createdAtMillis = Value(createdAtMillis);
  static Insertable<PersonGroupRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? cadenceType,
    Expression<String>? semantic,
    Expression<String>? channel,
    Expression<String>? handle,
    Expression<String>? missionChainJson,
    Expression<int>? createdAtMillis,
    Expression<int>? pausedUntilMillis,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (cadenceType != null) 'cadence_type': cadenceType,
      if (semantic != null) 'semantic': semantic,
      if (channel != null) 'channel': channel,
      if (handle != null) 'handle': handle,
      if (missionChainJson != null) 'mission_chain_json': missionChainJson,
      if (createdAtMillis != null) 'created_at_millis': createdAtMillis,
      if (pausedUntilMillis != null) 'paused_until_millis': pausedUntilMillis,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PersonGroupsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? cadenceType,
    Value<String>? semantic,
    Value<String>? channel,
    Value<String>? handle,
    Value<String?>? missionChainJson,
    Value<int>? createdAtMillis,
    Value<int?>? pausedUntilMillis,
    Value<int>? rowid,
  }) {
    return PersonGroupsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      cadenceType: cadenceType ?? this.cadenceType,
      semantic: semantic ?? this.semantic,
      channel: channel ?? this.channel,
      handle: handle ?? this.handle,
      missionChainJson: missionChainJson ?? this.missionChainJson,
      createdAtMillis: createdAtMillis ?? this.createdAtMillis,
      pausedUntilMillis: pausedUntilMillis ?? this.pausedUntilMillis,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (cadenceType.present) {
      map['cadence_type'] = Variable<String>(cadenceType.value);
    }
    if (semantic.present) {
      map['semantic'] = Variable<String>(semantic.value);
    }
    if (channel.present) {
      map['channel'] = Variable<String>(channel.value);
    }
    if (handle.present) {
      map['handle'] = Variable<String>(handle.value);
    }
    if (missionChainJson.present) {
      map['mission_chain_json'] = Variable<String>(missionChainJson.value);
    }
    if (createdAtMillis.present) {
      map['created_at_millis'] = Variable<int>(createdAtMillis.value);
    }
    if (pausedUntilMillis.present) {
      map['paused_until_millis'] = Variable<int>(pausedUntilMillis.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PersonGroupsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('cadenceType: $cadenceType, ')
          ..write('semantic: $semantic, ')
          ..write('channel: $channel, ')
          ..write('handle: $handle, ')
          ..write('missionChainJson: $missionChainJson, ')
          ..write('createdAtMillis: $createdAtMillis, ')
          ..write('pausedUntilMillis: $pausedUntilMillis, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PersonGroupMembersTable extends PersonGroupMembers
    with TableInfo<$PersonGroupMembersTable, PersonGroupMemberRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PersonGroupMembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _personIdMeta = const VerificationMeta(
    'personId',
  );
  @override
  late final GeneratedColumn<String> personId = GeneratedColumn<String>(
    'person_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMillisMeta = const VerificationMeta(
    'addedAtMillis',
  );
  @override
  late final GeneratedColumn<int> addedAtMillis = GeneratedColumn<int>(
    'added_at_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastContactedMillisMeta =
      const VerificationMeta('lastContactedMillis');
  @override
  late final GeneratedColumn<int> lastContactedMillis = GeneratedColumn<int>(
    'last_contacted_millis',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    groupId,
    personId,
    addedAtMillis,
    lastContactedMillis,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'person_group_members';
  @override
  VerificationContext validateIntegrity(
    Insertable<PersonGroupMemberRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('person_id')) {
      context.handle(
        _personIdMeta,
        personId.isAcceptableOrUnknown(data['person_id']!, _personIdMeta),
      );
    } else if (isInserting) {
      context.missing(_personIdMeta);
    }
    if (data.containsKey('added_at_millis')) {
      context.handle(
        _addedAtMillisMeta,
        addedAtMillis.isAcceptableOrUnknown(
          data['added_at_millis']!,
          _addedAtMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_addedAtMillisMeta);
    }
    if (data.containsKey('last_contacted_millis')) {
      context.handle(
        _lastContactedMillisMeta,
        lastContactedMillis.isAcceptableOrUnknown(
          data['last_contacted_millis']!,
          _lastContactedMillisMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {groupId, personId};
  @override
  PersonGroupMemberRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PersonGroupMemberRow(
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      personId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}person_id'],
      )!,
      addedAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at_millis'],
      )!,
      lastContactedMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_contacted_millis'],
      ),
    );
  }

  @override
  $PersonGroupMembersTable createAlias(String alias) {
    return $PersonGroupMembersTable(attachedDatabase, alias);
  }
}

class PersonGroupMemberRow extends DataClass
    implements Insertable<PersonGroupMemberRow> {
  final String groupId;
  final String personId;
  final int addedAtMillis;
  final int? lastContactedMillis;
  const PersonGroupMemberRow({
    required this.groupId,
    required this.personId,
    required this.addedAtMillis,
    this.lastContactedMillis,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['group_id'] = Variable<String>(groupId);
    map['person_id'] = Variable<String>(personId);
    map['added_at_millis'] = Variable<int>(addedAtMillis);
    if (!nullToAbsent || lastContactedMillis != null) {
      map['last_contacted_millis'] = Variable<int>(lastContactedMillis);
    }
    return map;
  }

  PersonGroupMembersCompanion toCompanion(bool nullToAbsent) {
    return PersonGroupMembersCompanion(
      groupId: Value(groupId),
      personId: Value(personId),
      addedAtMillis: Value(addedAtMillis),
      lastContactedMillis: lastContactedMillis == null && nullToAbsent
          ? const Value.absent()
          : Value(lastContactedMillis),
    );
  }

  factory PersonGroupMemberRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PersonGroupMemberRow(
      groupId: serializer.fromJson<String>(json['groupId']),
      personId: serializer.fromJson<String>(json['personId']),
      addedAtMillis: serializer.fromJson<int>(json['addedAtMillis']),
      lastContactedMillis: serializer.fromJson<int?>(
        json['lastContactedMillis'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupId': serializer.toJson<String>(groupId),
      'personId': serializer.toJson<String>(personId),
      'addedAtMillis': serializer.toJson<int>(addedAtMillis),
      'lastContactedMillis': serializer.toJson<int?>(lastContactedMillis),
    };
  }

  PersonGroupMemberRow copyWith({
    String? groupId,
    String? personId,
    int? addedAtMillis,
    Value<int?> lastContactedMillis = const Value.absent(),
  }) => PersonGroupMemberRow(
    groupId: groupId ?? this.groupId,
    personId: personId ?? this.personId,
    addedAtMillis: addedAtMillis ?? this.addedAtMillis,
    lastContactedMillis: lastContactedMillis.present
        ? lastContactedMillis.value
        : this.lastContactedMillis,
  );
  PersonGroupMemberRow copyWithCompanion(PersonGroupMembersCompanion data) {
    return PersonGroupMemberRow(
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      personId: data.personId.present ? data.personId.value : this.personId,
      addedAtMillis: data.addedAtMillis.present
          ? data.addedAtMillis.value
          : this.addedAtMillis,
      lastContactedMillis: data.lastContactedMillis.present
          ? data.lastContactedMillis.value
          : this.lastContactedMillis,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PersonGroupMemberRow(')
          ..write('groupId: $groupId, ')
          ..write('personId: $personId, ')
          ..write('addedAtMillis: $addedAtMillis, ')
          ..write('lastContactedMillis: $lastContactedMillis')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(groupId, personId, addedAtMillis, lastContactedMillis);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PersonGroupMemberRow &&
          other.groupId == this.groupId &&
          other.personId == this.personId &&
          other.addedAtMillis == this.addedAtMillis &&
          other.lastContactedMillis == this.lastContactedMillis);
}

class PersonGroupMembersCompanion
    extends UpdateCompanion<PersonGroupMemberRow> {
  final Value<String> groupId;
  final Value<String> personId;
  final Value<int> addedAtMillis;
  final Value<int?> lastContactedMillis;
  final Value<int> rowid;
  const PersonGroupMembersCompanion({
    this.groupId = const Value.absent(),
    this.personId = const Value.absent(),
    this.addedAtMillis = const Value.absent(),
    this.lastContactedMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PersonGroupMembersCompanion.insert({
    required String groupId,
    required String personId,
    required int addedAtMillis,
    this.lastContactedMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : groupId = Value(groupId),
       personId = Value(personId),
       addedAtMillis = Value(addedAtMillis);
  static Insertable<PersonGroupMemberRow> custom({
    Expression<String>? groupId,
    Expression<String>? personId,
    Expression<int>? addedAtMillis,
    Expression<int>? lastContactedMillis,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupId != null) 'group_id': groupId,
      if (personId != null) 'person_id': personId,
      if (addedAtMillis != null) 'added_at_millis': addedAtMillis,
      if (lastContactedMillis != null)
        'last_contacted_millis': lastContactedMillis,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PersonGroupMembersCompanion copyWith({
    Value<String>? groupId,
    Value<String>? personId,
    Value<int>? addedAtMillis,
    Value<int?>? lastContactedMillis,
    Value<int>? rowid,
  }) {
    return PersonGroupMembersCompanion(
      groupId: groupId ?? this.groupId,
      personId: personId ?? this.personId,
      addedAtMillis: addedAtMillis ?? this.addedAtMillis,
      lastContactedMillis: lastContactedMillis ?? this.lastContactedMillis,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (personId.present) {
      map['person_id'] = Variable<String>(personId.value);
    }
    if (addedAtMillis.present) {
      map['added_at_millis'] = Variable<int>(addedAtMillis.value);
    }
    if (lastContactedMillis.present) {
      map['last_contacted_millis'] = Variable<int>(lastContactedMillis.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PersonGroupMembersCompanion(')
          ..write('groupId: $groupId, ')
          ..write('personId: $personId, ')
          ..write('addedAtMillis: $addedAtMillis, ')
          ..write('lastContactedMillis: $lastContactedMillis, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TemplatesTable extends Templates
    with TableInfo<$TemplatesTable, TemplateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconNameMeta = const VerificationMeta(
    'iconName',
  );
  @override
  late final GeneratedColumn<String> iconName = GeneratedColumn<String>(
    'icon_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isBuiltInMeta = const VerificationMeta(
    'isBuiltIn',
  );
  @override
  late final GeneratedColumn<bool> isBuiltIn = GeneratedColumn<bool>(
    'is_built_in',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_built_in" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMillisMeta = const VerificationMeta(
    'createdAtMillis',
  );
  @override
  late final GeneratedColumn<int> createdAtMillis = GeneratedColumn<int>(
    'created_at_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastUsedAtMillisMeta = const VerificationMeta(
    'lastUsedAtMillis',
  );
  @override
  late final GeneratedColumn<int> lastUsedAtMillis = GeneratedColumn<int>(
    'last_used_at_millis',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    iconName,
    entityType,
    payloadJson,
    isBuiltIn,
    createdAtMillis,
    lastUsedAtMillis,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<TemplateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('icon_name')) {
      context.handle(
        _iconNameMeta,
        iconName.isAcceptableOrUnknown(data['icon_name']!, _iconNameMeta),
      );
    } else if (isInserting) {
      context.missing(_iconNameMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('is_built_in')) {
      context.handle(
        _isBuiltInMeta,
        isBuiltIn.isAcceptableOrUnknown(data['is_built_in']!, _isBuiltInMeta),
      );
    }
    if (data.containsKey('created_at_millis')) {
      context.handle(
        _createdAtMillisMeta,
        createdAtMillis.isAcceptableOrUnknown(
          data['created_at_millis']!,
          _createdAtMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMillisMeta);
    }
    if (data.containsKey('last_used_at_millis')) {
      context.handle(
        _lastUsedAtMillisMeta,
        lastUsedAtMillis.isAcceptableOrUnknown(
          data['last_used_at_millis']!,
          _lastUsedAtMillisMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TemplateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TemplateRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      iconName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_name'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      isBuiltIn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_built_in'],
      )!,
      createdAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_millis'],
      )!,
      lastUsedAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_used_at_millis'],
      ),
    );
  }

  @override
  $TemplatesTable createAlias(String alias) {
    return $TemplatesTable(attachedDatabase, alias);
  }
}

class TemplateRow extends DataClass implements Insertable<TemplateRow> {
  final String id;
  final String name;
  final String description;
  final String iconName;
  final String entityType;
  final String payloadJson;
  final bool isBuiltIn;
  final int createdAtMillis;
  final int? lastUsedAtMillis;
  const TemplateRow({
    required this.id,
    required this.name,
    required this.description,
    required this.iconName,
    required this.entityType,
    required this.payloadJson,
    required this.isBuiltIn,
    required this.createdAtMillis,
    this.lastUsedAtMillis,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['description'] = Variable<String>(description);
    map['icon_name'] = Variable<String>(iconName);
    map['entity_type'] = Variable<String>(entityType);
    map['payload_json'] = Variable<String>(payloadJson);
    map['is_built_in'] = Variable<bool>(isBuiltIn);
    map['created_at_millis'] = Variable<int>(createdAtMillis);
    if (!nullToAbsent || lastUsedAtMillis != null) {
      map['last_used_at_millis'] = Variable<int>(lastUsedAtMillis);
    }
    return map;
  }

  TemplatesCompanion toCompanion(bool nullToAbsent) {
    return TemplatesCompanion(
      id: Value(id),
      name: Value(name),
      description: Value(description),
      iconName: Value(iconName),
      entityType: Value(entityType),
      payloadJson: Value(payloadJson),
      isBuiltIn: Value(isBuiltIn),
      createdAtMillis: Value(createdAtMillis),
      lastUsedAtMillis: lastUsedAtMillis == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUsedAtMillis),
    );
  }

  factory TemplateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TemplateRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String>(json['description']),
      iconName: serializer.fromJson<String>(json['iconName']),
      entityType: serializer.fromJson<String>(json['entityType']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      isBuiltIn: serializer.fromJson<bool>(json['isBuiltIn']),
      createdAtMillis: serializer.fromJson<int>(json['createdAtMillis']),
      lastUsedAtMillis: serializer.fromJson<int?>(json['lastUsedAtMillis']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String>(description),
      'iconName': serializer.toJson<String>(iconName),
      'entityType': serializer.toJson<String>(entityType),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'isBuiltIn': serializer.toJson<bool>(isBuiltIn),
      'createdAtMillis': serializer.toJson<int>(createdAtMillis),
      'lastUsedAtMillis': serializer.toJson<int?>(lastUsedAtMillis),
    };
  }

  TemplateRow copyWith({
    String? id,
    String? name,
    String? description,
    String? iconName,
    String? entityType,
    String? payloadJson,
    bool? isBuiltIn,
    int? createdAtMillis,
    Value<int?> lastUsedAtMillis = const Value.absent(),
  }) => TemplateRow(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    iconName: iconName ?? this.iconName,
    entityType: entityType ?? this.entityType,
    payloadJson: payloadJson ?? this.payloadJson,
    isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    createdAtMillis: createdAtMillis ?? this.createdAtMillis,
    lastUsedAtMillis: lastUsedAtMillis.present
        ? lastUsedAtMillis.value
        : this.lastUsedAtMillis,
  );
  TemplateRow copyWithCompanion(TemplatesCompanion data) {
    return TemplateRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      iconName: data.iconName.present ? data.iconName.value : this.iconName,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      isBuiltIn: data.isBuiltIn.present ? data.isBuiltIn.value : this.isBuiltIn,
      createdAtMillis: data.createdAtMillis.present
          ? data.createdAtMillis.value
          : this.createdAtMillis,
      lastUsedAtMillis: data.lastUsedAtMillis.present
          ? data.lastUsedAtMillis.value
          : this.lastUsedAtMillis,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TemplateRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('iconName: $iconName, ')
          ..write('entityType: $entityType, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('isBuiltIn: $isBuiltIn, ')
          ..write('createdAtMillis: $createdAtMillis, ')
          ..write('lastUsedAtMillis: $lastUsedAtMillis')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    iconName,
    entityType,
    payloadJson,
    isBuiltIn,
    createdAtMillis,
    lastUsedAtMillis,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TemplateRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.iconName == this.iconName &&
          other.entityType == this.entityType &&
          other.payloadJson == this.payloadJson &&
          other.isBuiltIn == this.isBuiltIn &&
          other.createdAtMillis == this.createdAtMillis &&
          other.lastUsedAtMillis == this.lastUsedAtMillis);
}

class TemplatesCompanion extends UpdateCompanion<TemplateRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> description;
  final Value<String> iconName;
  final Value<String> entityType;
  final Value<String> payloadJson;
  final Value<bool> isBuiltIn;
  final Value<int> createdAtMillis;
  final Value<int?> lastUsedAtMillis;
  final Value<int> rowid;
  const TemplatesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.iconName = const Value.absent(),
    this.entityType = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.isBuiltIn = const Value.absent(),
    this.createdAtMillis = const Value.absent(),
    this.lastUsedAtMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TemplatesCompanion.insert({
    required String id,
    required String name,
    required String description,
    required String iconName,
    required String entityType,
    required String payloadJson,
    this.isBuiltIn = const Value.absent(),
    required int createdAtMillis,
    this.lastUsedAtMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       description = Value(description),
       iconName = Value(iconName),
       entityType = Value(entityType),
       payloadJson = Value(payloadJson),
       createdAtMillis = Value(createdAtMillis);
  static Insertable<TemplateRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? iconName,
    Expression<String>? entityType,
    Expression<String>? payloadJson,
    Expression<bool>? isBuiltIn,
    Expression<int>? createdAtMillis,
    Expression<int>? lastUsedAtMillis,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (iconName != null) 'icon_name': iconName,
      if (entityType != null) 'entity_type': entityType,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (isBuiltIn != null) 'is_built_in': isBuiltIn,
      if (createdAtMillis != null) 'created_at_millis': createdAtMillis,
      if (lastUsedAtMillis != null) 'last_used_at_millis': lastUsedAtMillis,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TemplatesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? description,
    Value<String>? iconName,
    Value<String>? entityType,
    Value<String>? payloadJson,
    Value<bool>? isBuiltIn,
    Value<int>? createdAtMillis,
    Value<int?>? lastUsedAtMillis,
    Value<int>? rowid,
  }) {
    return TemplatesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconName: iconName ?? this.iconName,
      entityType: entityType ?? this.entityType,
      payloadJson: payloadJson ?? this.payloadJson,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      createdAtMillis: createdAtMillis ?? this.createdAtMillis,
      lastUsedAtMillis: lastUsedAtMillis ?? this.lastUsedAtMillis,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (iconName.present) {
      map['icon_name'] = Variable<String>(iconName.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (isBuiltIn.present) {
      map['is_built_in'] = Variable<bool>(isBuiltIn.value);
    }
    if (createdAtMillis.present) {
      map['created_at_millis'] = Variable<int>(createdAtMillis.value);
    }
    if (lastUsedAtMillis.present) {
      map['last_used_at_millis'] = Variable<int>(lastUsedAtMillis.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TemplatesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('iconName: $iconName, ')
          ..write('entityType: $entityType, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('isBuiltIn: $isBuiltIn, ')
          ..write('createdAtMillis: $createdAtMillis, ')
          ..write('lastUsedAtMillis: $lastUsedAtMillis, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $HabitsTable habits = $HabitsTable(this);
  late final $PeopleTable people = $PeopleTable(this);
  late final $CompletionsTable completions = $CompletionsTable(this);
  late final $RestDayBudgetsTable restDayBudgets = $RestDayBudgetsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $EventLogsTable eventLogs = $EventLogsTable(this);
  late final $EventsTable events = $EventsTable(this);
  late final $PersonGroupsTable personGroups = $PersonGroupsTable(this);
  late final $PersonGroupMembersTable personGroupMembers =
      $PersonGroupMembersTable(this);
  late final $TemplatesTable templates = $TemplatesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    habits,
    people,
    completions,
    restDayBudgets,
    settings,
    eventLogs,
    events,
    personGroups,
    personGroupMembers,
    templates,
  ];
}

typedef $$HabitsTableCreateCompanionBuilder =
    HabitsCompanion Function({
      required String id,
      required String name,
      required String proofMode,
      required int createdAtMillis,
      Value<int> restDaysPerMonth,
      required String scheduleType,
      Value<String?> weekdays,
      Value<int?> hour,
      Value<int?> minute,
      Value<int?> nDays,
      Value<int?> referenceDateMillis,
      Value<String?> targetHabitId,
      Value<int?> lastAnchorMillis,
      Value<int?> dayOfMonth,
      Value<int?> nth,
      Value<int?> weekday,
      Value<int?> referenceDayOfMonth,
      Value<int?> endHour,
      Value<int?> endMinute,
      Value<int?> targetHours,
      Value<String?> missionChainJson,
      Value<String> category,
      Value<int> colorSeed,
      Value<String?> iconName,
      Value<int?> pausedUntilMillis,
      Value<String?> automationsJson,
      Value<int?> graceWindowOverrideMillis,
      Value<int> rowid,
    });
typedef $$HabitsTableUpdateCompanionBuilder =
    HabitsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> proofMode,
      Value<int> createdAtMillis,
      Value<int> restDaysPerMonth,
      Value<String> scheduleType,
      Value<String?> weekdays,
      Value<int?> hour,
      Value<int?> minute,
      Value<int?> nDays,
      Value<int?> referenceDateMillis,
      Value<String?> targetHabitId,
      Value<int?> lastAnchorMillis,
      Value<int?> dayOfMonth,
      Value<int?> nth,
      Value<int?> weekday,
      Value<int?> referenceDayOfMonth,
      Value<int?> endHour,
      Value<int?> endMinute,
      Value<int?> targetHours,
      Value<String?> missionChainJson,
      Value<String> category,
      Value<int> colorSeed,
      Value<String?> iconName,
      Value<int?> pausedUntilMillis,
      Value<String?> automationsJson,
      Value<int?> graceWindowOverrideMillis,
      Value<int> rowid,
    });

class $$HabitsTableFilterComposer
    extends Composer<_$AppDatabase, $HabitsTable> {
  $$HabitsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get proofMode => $composableBuilder(
    column: $table.proofMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get restDaysPerMonth => $composableBuilder(
    column: $table.restDaysPerMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scheduleType => $composableBuilder(
    column: $table.scheduleType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get weekdays => $composableBuilder(
    column: $table.weekdays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hour => $composableBuilder(
    column: $table.hour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minute => $composableBuilder(
    column: $table.minute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nDays => $composableBuilder(
    column: $table.nDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get referenceDateMillis => $composableBuilder(
    column: $table.referenceDateMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetHabitId => $composableBuilder(
    column: $table.targetHabitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastAnchorMillis => $composableBuilder(
    column: $table.lastAnchorMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nth => $composableBuilder(
    column: $table.nth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weekday => $composableBuilder(
    column: $table.weekday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get referenceDayOfMonth => $composableBuilder(
    column: $table.referenceDayOfMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endHour => $composableBuilder(
    column: $table.endHour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetHours => $composableBuilder(
    column: $table.targetHours,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get missionChainJson => $composableBuilder(
    column: $table.missionChainJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorSeed => $composableBuilder(
    column: $table.colorSeed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconName => $composableBuilder(
    column: $table.iconName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pausedUntilMillis => $composableBuilder(
    column: $table.pausedUntilMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get automationsJson => $composableBuilder(
    column: $table.automationsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get graceWindowOverrideMillis => $composableBuilder(
    column: $table.graceWindowOverrideMillis,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HabitsTableOrderingComposer
    extends Composer<_$AppDatabase, $HabitsTable> {
  $$HabitsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get proofMode => $composableBuilder(
    column: $table.proofMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get restDaysPerMonth => $composableBuilder(
    column: $table.restDaysPerMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheduleType => $composableBuilder(
    column: $table.scheduleType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get weekdays => $composableBuilder(
    column: $table.weekdays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hour => $composableBuilder(
    column: $table.hour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minute => $composableBuilder(
    column: $table.minute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nDays => $composableBuilder(
    column: $table.nDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get referenceDateMillis => $composableBuilder(
    column: $table.referenceDateMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetHabitId => $composableBuilder(
    column: $table.targetHabitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastAnchorMillis => $composableBuilder(
    column: $table.lastAnchorMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nth => $composableBuilder(
    column: $table.nth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weekday => $composableBuilder(
    column: $table.weekday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get referenceDayOfMonth => $composableBuilder(
    column: $table.referenceDayOfMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endHour => $composableBuilder(
    column: $table.endHour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetHours => $composableBuilder(
    column: $table.targetHours,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get missionChainJson => $composableBuilder(
    column: $table.missionChainJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorSeed => $composableBuilder(
    column: $table.colorSeed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconName => $composableBuilder(
    column: $table.iconName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pausedUntilMillis => $composableBuilder(
    column: $table.pausedUntilMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get automationsJson => $composableBuilder(
    column: $table.automationsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get graceWindowOverrideMillis => $composableBuilder(
    column: $table.graceWindowOverrideMillis,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HabitsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HabitsTable> {
  $$HabitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get proofMode =>
      $composableBuilder(column: $table.proofMode, builder: (column) => column);

  GeneratedColumn<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => column,
  );

  GeneratedColumn<int> get restDaysPerMonth => $composableBuilder(
    column: $table.restDaysPerMonth,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scheduleType => $composableBuilder(
    column: $table.scheduleType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get weekdays =>
      $composableBuilder(column: $table.weekdays, builder: (column) => column);

  GeneratedColumn<int> get hour =>
      $composableBuilder(column: $table.hour, builder: (column) => column);

  GeneratedColumn<int> get minute =>
      $composableBuilder(column: $table.minute, builder: (column) => column);

  GeneratedColumn<int> get nDays =>
      $composableBuilder(column: $table.nDays, builder: (column) => column);

  GeneratedColumn<int> get referenceDateMillis => $composableBuilder(
    column: $table.referenceDateMillis,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetHabitId => $composableBuilder(
    column: $table.targetHabitId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastAnchorMillis => $composableBuilder(
    column: $table.lastAnchorMillis,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nth =>
      $composableBuilder(column: $table.nth, builder: (column) => column);

  GeneratedColumn<int> get weekday =>
      $composableBuilder(column: $table.weekday, builder: (column) => column);

  GeneratedColumn<int> get referenceDayOfMonth => $composableBuilder(
    column: $table.referenceDayOfMonth,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endHour =>
      $composableBuilder(column: $table.endHour, builder: (column) => column);

  GeneratedColumn<int> get endMinute =>
      $composableBuilder(column: $table.endMinute, builder: (column) => column);

  GeneratedColumn<int> get targetHours => $composableBuilder(
    column: $table.targetHours,
    builder: (column) => column,
  );

  GeneratedColumn<String> get missionChainJson => $composableBuilder(
    column: $table.missionChainJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get colorSeed =>
      $composableBuilder(column: $table.colorSeed, builder: (column) => column);

  GeneratedColumn<String> get iconName =>
      $composableBuilder(column: $table.iconName, builder: (column) => column);

  GeneratedColumn<int> get pausedUntilMillis => $composableBuilder(
    column: $table.pausedUntilMillis,
    builder: (column) => column,
  );

  GeneratedColumn<String> get automationsJson => $composableBuilder(
    column: $table.automationsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get graceWindowOverrideMillis => $composableBuilder(
    column: $table.graceWindowOverrideMillis,
    builder: (column) => column,
  );
}

class $$HabitsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HabitsTable,
          HabitRow,
          $$HabitsTableFilterComposer,
          $$HabitsTableOrderingComposer,
          $$HabitsTableAnnotationComposer,
          $$HabitsTableCreateCompanionBuilder,
          $$HabitsTableUpdateCompanionBuilder,
          (HabitRow, BaseReferences<_$AppDatabase, $HabitsTable, HabitRow>),
          HabitRow,
          PrefetchHooks Function()
        > {
  $$HabitsTableTableManager(_$AppDatabase db, $HabitsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HabitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HabitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HabitsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> proofMode = const Value.absent(),
                Value<int> createdAtMillis = const Value.absent(),
                Value<int> restDaysPerMonth = const Value.absent(),
                Value<String> scheduleType = const Value.absent(),
                Value<String?> weekdays = const Value.absent(),
                Value<int?> hour = const Value.absent(),
                Value<int?> minute = const Value.absent(),
                Value<int?> nDays = const Value.absent(),
                Value<int?> referenceDateMillis = const Value.absent(),
                Value<String?> targetHabitId = const Value.absent(),
                Value<int?> lastAnchorMillis = const Value.absent(),
                Value<int?> dayOfMonth = const Value.absent(),
                Value<int?> nth = const Value.absent(),
                Value<int?> weekday = const Value.absent(),
                Value<int?> referenceDayOfMonth = const Value.absent(),
                Value<int?> endHour = const Value.absent(),
                Value<int?> endMinute = const Value.absent(),
                Value<int?> targetHours = const Value.absent(),
                Value<String?> missionChainJson = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<int> colorSeed = const Value.absent(),
                Value<String?> iconName = const Value.absent(),
                Value<int?> pausedUntilMillis = const Value.absent(),
                Value<String?> automationsJson = const Value.absent(),
                Value<int?> graceWindowOverrideMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HabitsCompanion(
                id: id,
                name: name,
                proofMode: proofMode,
                createdAtMillis: createdAtMillis,
                restDaysPerMonth: restDaysPerMonth,
                scheduleType: scheduleType,
                weekdays: weekdays,
                hour: hour,
                minute: minute,
                nDays: nDays,
                referenceDateMillis: referenceDateMillis,
                targetHabitId: targetHabitId,
                lastAnchorMillis: lastAnchorMillis,
                dayOfMonth: dayOfMonth,
                nth: nth,
                weekday: weekday,
                referenceDayOfMonth: referenceDayOfMonth,
                endHour: endHour,
                endMinute: endMinute,
                targetHours: targetHours,
                missionChainJson: missionChainJson,
                category: category,
                colorSeed: colorSeed,
                iconName: iconName,
                pausedUntilMillis: pausedUntilMillis,
                automationsJson: automationsJson,
                graceWindowOverrideMillis: graceWindowOverrideMillis,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String proofMode,
                required int createdAtMillis,
                Value<int> restDaysPerMonth = const Value.absent(),
                required String scheduleType,
                Value<String?> weekdays = const Value.absent(),
                Value<int?> hour = const Value.absent(),
                Value<int?> minute = const Value.absent(),
                Value<int?> nDays = const Value.absent(),
                Value<int?> referenceDateMillis = const Value.absent(),
                Value<String?> targetHabitId = const Value.absent(),
                Value<int?> lastAnchorMillis = const Value.absent(),
                Value<int?> dayOfMonth = const Value.absent(),
                Value<int?> nth = const Value.absent(),
                Value<int?> weekday = const Value.absent(),
                Value<int?> referenceDayOfMonth = const Value.absent(),
                Value<int?> endHour = const Value.absent(),
                Value<int?> endMinute = const Value.absent(),
                Value<int?> targetHours = const Value.absent(),
                Value<String?> missionChainJson = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<int> colorSeed = const Value.absent(),
                Value<String?> iconName = const Value.absent(),
                Value<int?> pausedUntilMillis = const Value.absent(),
                Value<String?> automationsJson = const Value.absent(),
                Value<int?> graceWindowOverrideMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HabitsCompanion.insert(
                id: id,
                name: name,
                proofMode: proofMode,
                createdAtMillis: createdAtMillis,
                restDaysPerMonth: restDaysPerMonth,
                scheduleType: scheduleType,
                weekdays: weekdays,
                hour: hour,
                minute: minute,
                nDays: nDays,
                referenceDateMillis: referenceDateMillis,
                targetHabitId: targetHabitId,
                lastAnchorMillis: lastAnchorMillis,
                dayOfMonth: dayOfMonth,
                nth: nth,
                weekday: weekday,
                referenceDayOfMonth: referenceDayOfMonth,
                endHour: endHour,
                endMinute: endMinute,
                targetHours: targetHours,
                missionChainJson: missionChainJson,
                category: category,
                colorSeed: colorSeed,
                iconName: iconName,
                pausedUntilMillis: pausedUntilMillis,
                automationsJson: automationsJson,
                graceWindowOverrideMillis: graceWindowOverrideMillis,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HabitsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HabitsTable,
      HabitRow,
      $$HabitsTableFilterComposer,
      $$HabitsTableOrderingComposer,
      $$HabitsTableAnnotationComposer,
      $$HabitsTableCreateCompanionBuilder,
      $$HabitsTableUpdateCompanionBuilder,
      (HabitRow, BaseReferences<_$AppDatabase, $HabitsTable, HabitRow>),
      HabitRow,
      PrefetchHooks Function()
    >;
typedef $$PeopleTableCreateCompanionBuilder =
    PeopleCompanion Function({
      required String id,
      required String lookupKey,
      required String displayName,
      required String channel,
      required String handle,
      required int createdAtMillis,
      required String cadenceType,
      Value<int?> nDays,
      Value<int?> weekday,
      Value<int?> dayOfMonth,
      Value<int?> monthOfYear,
      Value<bool> anchoredToWakeup,
      Value<String?> missionChainJson,
      Value<int?> pausedUntilMillis,
      Value<String?> automationsJson,
      Value<int> rowid,
    });
typedef $$PeopleTableUpdateCompanionBuilder =
    PeopleCompanion Function({
      Value<String> id,
      Value<String> lookupKey,
      Value<String> displayName,
      Value<String> channel,
      Value<String> handle,
      Value<int> createdAtMillis,
      Value<String> cadenceType,
      Value<int?> nDays,
      Value<int?> weekday,
      Value<int?> dayOfMonth,
      Value<int?> monthOfYear,
      Value<bool> anchoredToWakeup,
      Value<String?> missionChainJson,
      Value<int?> pausedUntilMillis,
      Value<String?> automationsJson,
      Value<int> rowid,
    });

class $$PeopleTableFilterComposer
    extends Composer<_$AppDatabase, $PeopleTable> {
  $$PeopleTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lookupKey => $composableBuilder(
    column: $table.lookupKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channel => $composableBuilder(
    column: $table.channel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get handle => $composableBuilder(
    column: $table.handle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cadenceType => $composableBuilder(
    column: $table.cadenceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nDays => $composableBuilder(
    column: $table.nDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weekday => $composableBuilder(
    column: $table.weekday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get monthOfYear => $composableBuilder(
    column: $table.monthOfYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get anchoredToWakeup => $composableBuilder(
    column: $table.anchoredToWakeup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get missionChainJson => $composableBuilder(
    column: $table.missionChainJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pausedUntilMillis => $composableBuilder(
    column: $table.pausedUntilMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get automationsJson => $composableBuilder(
    column: $table.automationsJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PeopleTableOrderingComposer
    extends Composer<_$AppDatabase, $PeopleTable> {
  $$PeopleTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lookupKey => $composableBuilder(
    column: $table.lookupKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channel => $composableBuilder(
    column: $table.channel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get handle => $composableBuilder(
    column: $table.handle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cadenceType => $composableBuilder(
    column: $table.cadenceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nDays => $composableBuilder(
    column: $table.nDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weekday => $composableBuilder(
    column: $table.weekday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get monthOfYear => $composableBuilder(
    column: $table.monthOfYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get anchoredToWakeup => $composableBuilder(
    column: $table.anchoredToWakeup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get missionChainJson => $composableBuilder(
    column: $table.missionChainJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pausedUntilMillis => $composableBuilder(
    column: $table.pausedUntilMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get automationsJson => $composableBuilder(
    column: $table.automationsJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PeopleTableAnnotationComposer
    extends Composer<_$AppDatabase, $PeopleTable> {
  $$PeopleTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get lookupKey =>
      $composableBuilder(column: $table.lookupKey, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get channel =>
      $composableBuilder(column: $table.channel, builder: (column) => column);

  GeneratedColumn<String> get handle =>
      $composableBuilder(column: $table.handle, builder: (column) => column);

  GeneratedColumn<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cadenceType => $composableBuilder(
    column: $table.cadenceType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nDays =>
      $composableBuilder(column: $table.nDays, builder: (column) => column);

  GeneratedColumn<int> get weekday =>
      $composableBuilder(column: $table.weekday, builder: (column) => column);

  GeneratedColumn<int> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => column,
  );

  GeneratedColumn<int> get monthOfYear => $composableBuilder(
    column: $table.monthOfYear,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get anchoredToWakeup => $composableBuilder(
    column: $table.anchoredToWakeup,
    builder: (column) => column,
  );

  GeneratedColumn<String> get missionChainJson => $composableBuilder(
    column: $table.missionChainJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pausedUntilMillis => $composableBuilder(
    column: $table.pausedUntilMillis,
    builder: (column) => column,
  );

  GeneratedColumn<String> get automationsJson => $composableBuilder(
    column: $table.automationsJson,
    builder: (column) => column,
  );
}

class $$PeopleTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PeopleTable,
          PersonRow,
          $$PeopleTableFilterComposer,
          $$PeopleTableOrderingComposer,
          $$PeopleTableAnnotationComposer,
          $$PeopleTableCreateCompanionBuilder,
          $$PeopleTableUpdateCompanionBuilder,
          (PersonRow, BaseReferences<_$AppDatabase, $PeopleTable, PersonRow>),
          PersonRow,
          PrefetchHooks Function()
        > {
  $$PeopleTableTableManager(_$AppDatabase db, $PeopleTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PeopleTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PeopleTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PeopleTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> lookupKey = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> channel = const Value.absent(),
                Value<String> handle = const Value.absent(),
                Value<int> createdAtMillis = const Value.absent(),
                Value<String> cadenceType = const Value.absent(),
                Value<int?> nDays = const Value.absent(),
                Value<int?> weekday = const Value.absent(),
                Value<int?> dayOfMonth = const Value.absent(),
                Value<int?> monthOfYear = const Value.absent(),
                Value<bool> anchoredToWakeup = const Value.absent(),
                Value<String?> missionChainJson = const Value.absent(),
                Value<int?> pausedUntilMillis = const Value.absent(),
                Value<String?> automationsJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PeopleCompanion(
                id: id,
                lookupKey: lookupKey,
                displayName: displayName,
                channel: channel,
                handle: handle,
                createdAtMillis: createdAtMillis,
                cadenceType: cadenceType,
                nDays: nDays,
                weekday: weekday,
                dayOfMonth: dayOfMonth,
                monthOfYear: monthOfYear,
                anchoredToWakeup: anchoredToWakeup,
                missionChainJson: missionChainJson,
                pausedUntilMillis: pausedUntilMillis,
                automationsJson: automationsJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String lookupKey,
                required String displayName,
                required String channel,
                required String handle,
                required int createdAtMillis,
                required String cadenceType,
                Value<int?> nDays = const Value.absent(),
                Value<int?> weekday = const Value.absent(),
                Value<int?> dayOfMonth = const Value.absent(),
                Value<int?> monthOfYear = const Value.absent(),
                Value<bool> anchoredToWakeup = const Value.absent(),
                Value<String?> missionChainJson = const Value.absent(),
                Value<int?> pausedUntilMillis = const Value.absent(),
                Value<String?> automationsJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PeopleCompanion.insert(
                id: id,
                lookupKey: lookupKey,
                displayName: displayName,
                channel: channel,
                handle: handle,
                createdAtMillis: createdAtMillis,
                cadenceType: cadenceType,
                nDays: nDays,
                weekday: weekday,
                dayOfMonth: dayOfMonth,
                monthOfYear: monthOfYear,
                anchoredToWakeup: anchoredToWakeup,
                missionChainJson: missionChainJson,
                pausedUntilMillis: pausedUntilMillis,
                automationsJson: automationsJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PeopleTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PeopleTable,
      PersonRow,
      $$PeopleTableFilterComposer,
      $$PeopleTableOrderingComposer,
      $$PeopleTableAnnotationComposer,
      $$PeopleTableCreateCompanionBuilder,
      $$PeopleTableUpdateCompanionBuilder,
      (PersonRow, BaseReferences<_$AppDatabase, $PeopleTable, PersonRow>),
      PersonRow,
      PrefetchHooks Function()
    >;
typedef $$CompletionsTableCreateCompanionBuilder =
    CompletionsCompanion Function({
      required String id,
      required String habitId,
      required int dayMillis,
      required int completedAtMillis,
      required String source,
      required String proofModeAtTime,
      Value<String?> note,
      Value<String?> missionResultsJson,
      Value<int> rowid,
    });
typedef $$CompletionsTableUpdateCompanionBuilder =
    CompletionsCompanion Function({
      Value<String> id,
      Value<String> habitId,
      Value<int> dayMillis,
      Value<int> completedAtMillis,
      Value<String> source,
      Value<String> proofModeAtTime,
      Value<String?> note,
      Value<String?> missionResultsJson,
      Value<int> rowid,
    });

class $$CompletionsTableFilterComposer
    extends Composer<_$AppDatabase, $CompletionsTable> {
  $$CompletionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get habitId => $composableBuilder(
    column: $table.habitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dayMillis => $composableBuilder(
    column: $table.dayMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAtMillis => $composableBuilder(
    column: $table.completedAtMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get proofModeAtTime => $composableBuilder(
    column: $table.proofModeAtTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get missionResultsJson => $composableBuilder(
    column: $table.missionResultsJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CompletionsTableOrderingComposer
    extends Composer<_$AppDatabase, $CompletionsTable> {
  $$CompletionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get habitId => $composableBuilder(
    column: $table.habitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dayMillis => $composableBuilder(
    column: $table.dayMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAtMillis => $composableBuilder(
    column: $table.completedAtMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get proofModeAtTime => $composableBuilder(
    column: $table.proofModeAtTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get missionResultsJson => $composableBuilder(
    column: $table.missionResultsJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CompletionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CompletionsTable> {
  $$CompletionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get habitId =>
      $composableBuilder(column: $table.habitId, builder: (column) => column);

  GeneratedColumn<int> get dayMillis =>
      $composableBuilder(column: $table.dayMillis, builder: (column) => column);

  GeneratedColumn<int> get completedAtMillis => $composableBuilder(
    column: $table.completedAtMillis,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get proofModeAtTime => $composableBuilder(
    column: $table.proofModeAtTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get missionResultsJson => $composableBuilder(
    column: $table.missionResultsJson,
    builder: (column) => column,
  );
}

class $$CompletionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CompletionsTable,
          CompletionRow,
          $$CompletionsTableFilterComposer,
          $$CompletionsTableOrderingComposer,
          $$CompletionsTableAnnotationComposer,
          $$CompletionsTableCreateCompanionBuilder,
          $$CompletionsTableUpdateCompanionBuilder,
          (
            CompletionRow,
            BaseReferences<_$AppDatabase, $CompletionsTable, CompletionRow>,
          ),
          CompletionRow,
          PrefetchHooks Function()
        > {
  $$CompletionsTableTableManager(_$AppDatabase db, $CompletionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CompletionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CompletionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CompletionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> habitId = const Value.absent(),
                Value<int> dayMillis = const Value.absent(),
                Value<int> completedAtMillis = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> proofModeAtTime = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> missionResultsJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CompletionsCompanion(
                id: id,
                habitId: habitId,
                dayMillis: dayMillis,
                completedAtMillis: completedAtMillis,
                source: source,
                proofModeAtTime: proofModeAtTime,
                note: note,
                missionResultsJson: missionResultsJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String habitId,
                required int dayMillis,
                required int completedAtMillis,
                required String source,
                required String proofModeAtTime,
                Value<String?> note = const Value.absent(),
                Value<String?> missionResultsJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CompletionsCompanion.insert(
                id: id,
                habitId: habitId,
                dayMillis: dayMillis,
                completedAtMillis: completedAtMillis,
                source: source,
                proofModeAtTime: proofModeAtTime,
                note: note,
                missionResultsJson: missionResultsJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CompletionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CompletionsTable,
      CompletionRow,
      $$CompletionsTableFilterComposer,
      $$CompletionsTableOrderingComposer,
      $$CompletionsTableAnnotationComposer,
      $$CompletionsTableCreateCompanionBuilder,
      $$CompletionsTableUpdateCompanionBuilder,
      (
        CompletionRow,
        BaseReferences<_$AppDatabase, $CompletionsTable, CompletionRow>,
      ),
      CompletionRow,
      PrefetchHooks Function()
    >;
typedef $$RestDayBudgetsTableCreateCompanionBuilder =
    RestDayBudgetsCompanion Function({
      required String id,
      required String habitId,
      required int yearMonth,
      Value<int> used,
      required int monthlyLimit,
      Value<int> rowid,
    });
typedef $$RestDayBudgetsTableUpdateCompanionBuilder =
    RestDayBudgetsCompanion Function({
      Value<String> id,
      Value<String> habitId,
      Value<int> yearMonth,
      Value<int> used,
      Value<int> monthlyLimit,
      Value<int> rowid,
    });

class $$RestDayBudgetsTableFilterComposer
    extends Composer<_$AppDatabase, $RestDayBudgetsTable> {
  $$RestDayBudgetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get habitId => $composableBuilder(
    column: $table.habitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get yearMonth => $composableBuilder(
    column: $table.yearMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get used => $composableBuilder(
    column: $table.used,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get monthlyLimit => $composableBuilder(
    column: $table.monthlyLimit,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RestDayBudgetsTableOrderingComposer
    extends Composer<_$AppDatabase, $RestDayBudgetsTable> {
  $$RestDayBudgetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get habitId => $composableBuilder(
    column: $table.habitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get yearMonth => $composableBuilder(
    column: $table.yearMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get used => $composableBuilder(
    column: $table.used,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get monthlyLimit => $composableBuilder(
    column: $table.monthlyLimit,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RestDayBudgetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RestDayBudgetsTable> {
  $$RestDayBudgetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get habitId =>
      $composableBuilder(column: $table.habitId, builder: (column) => column);

  GeneratedColumn<int> get yearMonth =>
      $composableBuilder(column: $table.yearMonth, builder: (column) => column);

  GeneratedColumn<int> get used =>
      $composableBuilder(column: $table.used, builder: (column) => column);

  GeneratedColumn<int> get monthlyLimit => $composableBuilder(
    column: $table.monthlyLimit,
    builder: (column) => column,
  );
}

class $$RestDayBudgetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RestDayBudgetsTable,
          RestDayBudgetRow,
          $$RestDayBudgetsTableFilterComposer,
          $$RestDayBudgetsTableOrderingComposer,
          $$RestDayBudgetsTableAnnotationComposer,
          $$RestDayBudgetsTableCreateCompanionBuilder,
          $$RestDayBudgetsTableUpdateCompanionBuilder,
          (
            RestDayBudgetRow,
            BaseReferences<
              _$AppDatabase,
              $RestDayBudgetsTable,
              RestDayBudgetRow
            >,
          ),
          RestDayBudgetRow,
          PrefetchHooks Function()
        > {
  $$RestDayBudgetsTableTableManager(
    _$AppDatabase db,
    $RestDayBudgetsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RestDayBudgetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RestDayBudgetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RestDayBudgetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> habitId = const Value.absent(),
                Value<int> yearMonth = const Value.absent(),
                Value<int> used = const Value.absent(),
                Value<int> monthlyLimit = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RestDayBudgetsCompanion(
                id: id,
                habitId: habitId,
                yearMonth: yearMonth,
                used: used,
                monthlyLimit: monthlyLimit,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String habitId,
                required int yearMonth,
                Value<int> used = const Value.absent(),
                required int monthlyLimit,
                Value<int> rowid = const Value.absent(),
              }) => RestDayBudgetsCompanion.insert(
                id: id,
                habitId: habitId,
                yearMonth: yearMonth,
                used: used,
                monthlyLimit: monthlyLimit,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RestDayBudgetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RestDayBudgetsTable,
      RestDayBudgetRow,
      $$RestDayBudgetsTableFilterComposer,
      $$RestDayBudgetsTableOrderingComposer,
      $$RestDayBudgetsTableAnnotationComposer,
      $$RestDayBudgetsTableCreateCompanionBuilder,
      $$RestDayBudgetsTableUpdateCompanionBuilder,
      (
        RestDayBudgetRow,
        BaseReferences<_$AppDatabase, $RestDayBudgetsTable, RestDayBudgetRow>,
      ),
      RestDayBudgetRow,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          SettingRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      SettingRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (SettingRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>),
      SettingRow,
      PrefetchHooks Function()
    >;
typedef $$EventLogsTableCreateCompanionBuilder =
    EventLogsCompanion Function({
      required String id,
      required int atMillis,
      required String kind,
      Value<String?> detailJson,
      Value<int> rowid,
    });
typedef $$EventLogsTableUpdateCompanionBuilder =
    EventLogsCompanion Function({
      Value<String> id,
      Value<int> atMillis,
      Value<String> kind,
      Value<String?> detailJson,
      Value<int> rowid,
    });

class $$EventLogsTableFilterComposer
    extends Composer<_$AppDatabase, $EventLogsTable> {
  $$EventLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get atMillis => $composableBuilder(
    column: $table.atMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detailJson => $composableBuilder(
    column: $table.detailJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EventLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $EventLogsTable> {
  $$EventLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get atMillis => $composableBuilder(
    column: $table.atMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detailJson => $composableBuilder(
    column: $table.detailJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EventLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EventLogsTable> {
  $$EventLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get atMillis =>
      $composableBuilder(column: $table.atMillis, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get detailJson => $composableBuilder(
    column: $table.detailJson,
    builder: (column) => column,
  );
}

class $$EventLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EventLogsTable,
          EventLogRow,
          $$EventLogsTableFilterComposer,
          $$EventLogsTableOrderingComposer,
          $$EventLogsTableAnnotationComposer,
          $$EventLogsTableCreateCompanionBuilder,
          $$EventLogsTableUpdateCompanionBuilder,
          (
            EventLogRow,
            BaseReferences<_$AppDatabase, $EventLogsTable, EventLogRow>,
          ),
          EventLogRow,
          PrefetchHooks Function()
        > {
  $$EventLogsTableTableManager(_$AppDatabase db, $EventLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> atMillis = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> detailJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventLogsCompanion(
                id: id,
                atMillis: atMillis,
                kind: kind,
                detailJson: detailJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int atMillis,
                required String kind,
                Value<String?> detailJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventLogsCompanion.insert(
                id: id,
                atMillis: atMillis,
                kind: kind,
                detailJson: detailJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EventLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EventLogsTable,
      EventLogRow,
      $$EventLogsTableFilterComposer,
      $$EventLogsTableOrderingComposer,
      $$EventLogsTableAnnotationComposer,
      $$EventLogsTableCreateCompanionBuilder,
      $$EventLogsTableUpdateCompanionBuilder,
      (
        EventLogRow,
        BaseReferences<_$AppDatabase, $EventLogsTable, EventLogRow>,
      ),
      EventLogRow,
      PrefetchHooks Function()
    >;
typedef $$EventsTableCreateCompanionBuilder =
    EventsCompanion Function({
      required String id,
      required String name,
      required int atMillis,
      required int leadTimeMillis,
      Value<String?> missionChainJson,
      Value<String> recurrence,
      Value<int?> archivedAtMillis,
      required int createdAtMillis,
      Value<String?> automationsJson,
      Value<int> rowid,
    });
typedef $$EventsTableUpdateCompanionBuilder =
    EventsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> atMillis,
      Value<int> leadTimeMillis,
      Value<String?> missionChainJson,
      Value<String> recurrence,
      Value<int?> archivedAtMillis,
      Value<int> createdAtMillis,
      Value<String?> automationsJson,
      Value<int> rowid,
    });

class $$EventsTableFilterComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get atMillis => $composableBuilder(
    column: $table.atMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get leadTimeMillis => $composableBuilder(
    column: $table.leadTimeMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get missionChainJson => $composableBuilder(
    column: $table.missionChainJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrence => $composableBuilder(
    column: $table.recurrence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get archivedAtMillis => $composableBuilder(
    column: $table.archivedAtMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get automationsJson => $composableBuilder(
    column: $table.automationsJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EventsTableOrderingComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get atMillis => $composableBuilder(
    column: $table.atMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get leadTimeMillis => $composableBuilder(
    column: $table.leadTimeMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get missionChainJson => $composableBuilder(
    column: $table.missionChainJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrence => $composableBuilder(
    column: $table.recurrence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get archivedAtMillis => $composableBuilder(
    column: $table.archivedAtMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get automationsJson => $composableBuilder(
    column: $table.automationsJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get atMillis =>
      $composableBuilder(column: $table.atMillis, builder: (column) => column);

  GeneratedColumn<int> get leadTimeMillis => $composableBuilder(
    column: $table.leadTimeMillis,
    builder: (column) => column,
  );

  GeneratedColumn<String> get missionChainJson => $composableBuilder(
    column: $table.missionChainJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurrence => $composableBuilder(
    column: $table.recurrence,
    builder: (column) => column,
  );

  GeneratedColumn<int> get archivedAtMillis => $composableBuilder(
    column: $table.archivedAtMillis,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => column,
  );

  GeneratedColumn<String> get automationsJson => $composableBuilder(
    column: $table.automationsJson,
    builder: (column) => column,
  );
}

class $$EventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EventsTable,
          EventRow,
          $$EventsTableFilterComposer,
          $$EventsTableOrderingComposer,
          $$EventsTableAnnotationComposer,
          $$EventsTableCreateCompanionBuilder,
          $$EventsTableUpdateCompanionBuilder,
          (EventRow, BaseReferences<_$AppDatabase, $EventsTable, EventRow>),
          EventRow,
          PrefetchHooks Function()
        > {
  $$EventsTableTableManager(_$AppDatabase db, $EventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> atMillis = const Value.absent(),
                Value<int> leadTimeMillis = const Value.absent(),
                Value<String?> missionChainJson = const Value.absent(),
                Value<String> recurrence = const Value.absent(),
                Value<int?> archivedAtMillis = const Value.absent(),
                Value<int> createdAtMillis = const Value.absent(),
                Value<String?> automationsJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventsCompanion(
                id: id,
                name: name,
                atMillis: atMillis,
                leadTimeMillis: leadTimeMillis,
                missionChainJson: missionChainJson,
                recurrence: recurrence,
                archivedAtMillis: archivedAtMillis,
                createdAtMillis: createdAtMillis,
                automationsJson: automationsJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required int atMillis,
                required int leadTimeMillis,
                Value<String?> missionChainJson = const Value.absent(),
                Value<String> recurrence = const Value.absent(),
                Value<int?> archivedAtMillis = const Value.absent(),
                required int createdAtMillis,
                Value<String?> automationsJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventsCompanion.insert(
                id: id,
                name: name,
                atMillis: atMillis,
                leadTimeMillis: leadTimeMillis,
                missionChainJson: missionChainJson,
                recurrence: recurrence,
                archivedAtMillis: archivedAtMillis,
                createdAtMillis: createdAtMillis,
                automationsJson: automationsJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EventsTable,
      EventRow,
      $$EventsTableFilterComposer,
      $$EventsTableOrderingComposer,
      $$EventsTableAnnotationComposer,
      $$EventsTableCreateCompanionBuilder,
      $$EventsTableUpdateCompanionBuilder,
      (EventRow, BaseReferences<_$AppDatabase, $EventsTable, EventRow>),
      EventRow,
      PrefetchHooks Function()
    >;
typedef $$PersonGroupsTableCreateCompanionBuilder =
    PersonGroupsCompanion Function({
      required String id,
      required String name,
      required String cadenceType,
      required String semantic,
      required String channel,
      required String handle,
      Value<String?> missionChainJson,
      required int createdAtMillis,
      Value<int?> pausedUntilMillis,
      Value<int> rowid,
    });
typedef $$PersonGroupsTableUpdateCompanionBuilder =
    PersonGroupsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> cadenceType,
      Value<String> semantic,
      Value<String> channel,
      Value<String> handle,
      Value<String?> missionChainJson,
      Value<int> createdAtMillis,
      Value<int?> pausedUntilMillis,
      Value<int> rowid,
    });

class $$PersonGroupsTableFilterComposer
    extends Composer<_$AppDatabase, $PersonGroupsTable> {
  $$PersonGroupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cadenceType => $composableBuilder(
    column: $table.cadenceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get semantic => $composableBuilder(
    column: $table.semantic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channel => $composableBuilder(
    column: $table.channel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get handle => $composableBuilder(
    column: $table.handle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get missionChainJson => $composableBuilder(
    column: $table.missionChainJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pausedUntilMillis => $composableBuilder(
    column: $table.pausedUntilMillis,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PersonGroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $PersonGroupsTable> {
  $$PersonGroupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cadenceType => $composableBuilder(
    column: $table.cadenceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get semantic => $composableBuilder(
    column: $table.semantic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channel => $composableBuilder(
    column: $table.channel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get handle => $composableBuilder(
    column: $table.handle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get missionChainJson => $composableBuilder(
    column: $table.missionChainJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pausedUntilMillis => $composableBuilder(
    column: $table.pausedUntilMillis,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PersonGroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PersonGroupsTable> {
  $$PersonGroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get cadenceType => $composableBuilder(
    column: $table.cadenceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get semantic =>
      $composableBuilder(column: $table.semantic, builder: (column) => column);

  GeneratedColumn<String> get channel =>
      $composableBuilder(column: $table.channel, builder: (column) => column);

  GeneratedColumn<String> get handle =>
      $composableBuilder(column: $table.handle, builder: (column) => column);

  GeneratedColumn<String> get missionChainJson => $composableBuilder(
    column: $table.missionChainJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pausedUntilMillis => $composableBuilder(
    column: $table.pausedUntilMillis,
    builder: (column) => column,
  );
}

class $$PersonGroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PersonGroupsTable,
          PersonGroupRow,
          $$PersonGroupsTableFilterComposer,
          $$PersonGroupsTableOrderingComposer,
          $$PersonGroupsTableAnnotationComposer,
          $$PersonGroupsTableCreateCompanionBuilder,
          $$PersonGroupsTableUpdateCompanionBuilder,
          (
            PersonGroupRow,
            BaseReferences<_$AppDatabase, $PersonGroupsTable, PersonGroupRow>,
          ),
          PersonGroupRow,
          PrefetchHooks Function()
        > {
  $$PersonGroupsTableTableManager(_$AppDatabase db, $PersonGroupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PersonGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PersonGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PersonGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> cadenceType = const Value.absent(),
                Value<String> semantic = const Value.absent(),
                Value<String> channel = const Value.absent(),
                Value<String> handle = const Value.absent(),
                Value<String?> missionChainJson = const Value.absent(),
                Value<int> createdAtMillis = const Value.absent(),
                Value<int?> pausedUntilMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PersonGroupsCompanion(
                id: id,
                name: name,
                cadenceType: cadenceType,
                semantic: semantic,
                channel: channel,
                handle: handle,
                missionChainJson: missionChainJson,
                createdAtMillis: createdAtMillis,
                pausedUntilMillis: pausedUntilMillis,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String cadenceType,
                required String semantic,
                required String channel,
                required String handle,
                Value<String?> missionChainJson = const Value.absent(),
                required int createdAtMillis,
                Value<int?> pausedUntilMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PersonGroupsCompanion.insert(
                id: id,
                name: name,
                cadenceType: cadenceType,
                semantic: semantic,
                channel: channel,
                handle: handle,
                missionChainJson: missionChainJson,
                createdAtMillis: createdAtMillis,
                pausedUntilMillis: pausedUntilMillis,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PersonGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PersonGroupsTable,
      PersonGroupRow,
      $$PersonGroupsTableFilterComposer,
      $$PersonGroupsTableOrderingComposer,
      $$PersonGroupsTableAnnotationComposer,
      $$PersonGroupsTableCreateCompanionBuilder,
      $$PersonGroupsTableUpdateCompanionBuilder,
      (
        PersonGroupRow,
        BaseReferences<_$AppDatabase, $PersonGroupsTable, PersonGroupRow>,
      ),
      PersonGroupRow,
      PrefetchHooks Function()
    >;
typedef $$PersonGroupMembersTableCreateCompanionBuilder =
    PersonGroupMembersCompanion Function({
      required String groupId,
      required String personId,
      required int addedAtMillis,
      Value<int?> lastContactedMillis,
      Value<int> rowid,
    });
typedef $$PersonGroupMembersTableUpdateCompanionBuilder =
    PersonGroupMembersCompanion Function({
      Value<String> groupId,
      Value<String> personId,
      Value<int> addedAtMillis,
      Value<int?> lastContactedMillis,
      Value<int> rowid,
    });

class $$PersonGroupMembersTableFilterComposer
    extends Composer<_$AppDatabase, $PersonGroupMembersTable> {
  $$PersonGroupMembersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get personId => $composableBuilder(
    column: $table.personId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAtMillis => $composableBuilder(
    column: $table.addedAtMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastContactedMillis => $composableBuilder(
    column: $table.lastContactedMillis,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PersonGroupMembersTableOrderingComposer
    extends Composer<_$AppDatabase, $PersonGroupMembersTable> {
  $$PersonGroupMembersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get personId => $composableBuilder(
    column: $table.personId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAtMillis => $composableBuilder(
    column: $table.addedAtMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastContactedMillis => $composableBuilder(
    column: $table.lastContactedMillis,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PersonGroupMembersTableAnnotationComposer
    extends Composer<_$AppDatabase, $PersonGroupMembersTable> {
  $$PersonGroupMembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get personId =>
      $composableBuilder(column: $table.personId, builder: (column) => column);

  GeneratedColumn<int> get addedAtMillis => $composableBuilder(
    column: $table.addedAtMillis,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastContactedMillis => $composableBuilder(
    column: $table.lastContactedMillis,
    builder: (column) => column,
  );
}

class $$PersonGroupMembersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PersonGroupMembersTable,
          PersonGroupMemberRow,
          $$PersonGroupMembersTableFilterComposer,
          $$PersonGroupMembersTableOrderingComposer,
          $$PersonGroupMembersTableAnnotationComposer,
          $$PersonGroupMembersTableCreateCompanionBuilder,
          $$PersonGroupMembersTableUpdateCompanionBuilder,
          (
            PersonGroupMemberRow,
            BaseReferences<
              _$AppDatabase,
              $PersonGroupMembersTable,
              PersonGroupMemberRow
            >,
          ),
          PersonGroupMemberRow,
          PrefetchHooks Function()
        > {
  $$PersonGroupMembersTableTableManager(
    _$AppDatabase db,
    $PersonGroupMembersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PersonGroupMembersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PersonGroupMembersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PersonGroupMembersTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> groupId = const Value.absent(),
                Value<String> personId = const Value.absent(),
                Value<int> addedAtMillis = const Value.absent(),
                Value<int?> lastContactedMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PersonGroupMembersCompanion(
                groupId: groupId,
                personId: personId,
                addedAtMillis: addedAtMillis,
                lastContactedMillis: lastContactedMillis,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String groupId,
                required String personId,
                required int addedAtMillis,
                Value<int?> lastContactedMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PersonGroupMembersCompanion.insert(
                groupId: groupId,
                personId: personId,
                addedAtMillis: addedAtMillis,
                lastContactedMillis: lastContactedMillis,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PersonGroupMembersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PersonGroupMembersTable,
      PersonGroupMemberRow,
      $$PersonGroupMembersTableFilterComposer,
      $$PersonGroupMembersTableOrderingComposer,
      $$PersonGroupMembersTableAnnotationComposer,
      $$PersonGroupMembersTableCreateCompanionBuilder,
      $$PersonGroupMembersTableUpdateCompanionBuilder,
      (
        PersonGroupMemberRow,
        BaseReferences<
          _$AppDatabase,
          $PersonGroupMembersTable,
          PersonGroupMemberRow
        >,
      ),
      PersonGroupMemberRow,
      PrefetchHooks Function()
    >;
typedef $$TemplatesTableCreateCompanionBuilder =
    TemplatesCompanion Function({
      required String id,
      required String name,
      required String description,
      required String iconName,
      required String entityType,
      required String payloadJson,
      Value<bool> isBuiltIn,
      required int createdAtMillis,
      Value<int?> lastUsedAtMillis,
      Value<int> rowid,
    });
typedef $$TemplatesTableUpdateCompanionBuilder =
    TemplatesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> description,
      Value<String> iconName,
      Value<String> entityType,
      Value<String> payloadJson,
      Value<bool> isBuiltIn,
      Value<int> createdAtMillis,
      Value<int?> lastUsedAtMillis,
      Value<int> rowid,
    });

class $$TemplatesTableFilterComposer
    extends Composer<_$AppDatabase, $TemplatesTable> {
  $$TemplatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconName => $composableBuilder(
    column: $table.iconName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isBuiltIn => $composableBuilder(
    column: $table.isBuiltIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastUsedAtMillis => $composableBuilder(
    column: $table.lastUsedAtMillis,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TemplatesTableOrderingComposer
    extends Composer<_$AppDatabase, $TemplatesTable> {
  $$TemplatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconName => $composableBuilder(
    column: $table.iconName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isBuiltIn => $composableBuilder(
    column: $table.isBuiltIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastUsedAtMillis => $composableBuilder(
    column: $table.lastUsedAtMillis,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TemplatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TemplatesTable> {
  $$TemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get iconName =>
      $composableBuilder(column: $table.iconName, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isBuiltIn =>
      $composableBuilder(column: $table.isBuiltIn, builder: (column) => column);

  GeneratedColumn<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastUsedAtMillis => $composableBuilder(
    column: $table.lastUsedAtMillis,
    builder: (column) => column,
  );
}

class $$TemplatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TemplatesTable,
          TemplateRow,
          $$TemplatesTableFilterComposer,
          $$TemplatesTableOrderingComposer,
          $$TemplatesTableAnnotationComposer,
          $$TemplatesTableCreateCompanionBuilder,
          $$TemplatesTableUpdateCompanionBuilder,
          (
            TemplateRow,
            BaseReferences<_$AppDatabase, $TemplatesTable, TemplateRow>,
          ),
          TemplateRow,
          PrefetchHooks Function()
        > {
  $$TemplatesTableTableManager(_$AppDatabase db, $TemplatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TemplatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TemplatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> iconName = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<bool> isBuiltIn = const Value.absent(),
                Value<int> createdAtMillis = const Value.absent(),
                Value<int?> lastUsedAtMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TemplatesCompanion(
                id: id,
                name: name,
                description: description,
                iconName: iconName,
                entityType: entityType,
                payloadJson: payloadJson,
                isBuiltIn: isBuiltIn,
                createdAtMillis: createdAtMillis,
                lastUsedAtMillis: lastUsedAtMillis,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String description,
                required String iconName,
                required String entityType,
                required String payloadJson,
                Value<bool> isBuiltIn = const Value.absent(),
                required int createdAtMillis,
                Value<int?> lastUsedAtMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TemplatesCompanion.insert(
                id: id,
                name: name,
                description: description,
                iconName: iconName,
                entityType: entityType,
                payloadJson: payloadJson,
                isBuiltIn: isBuiltIn,
                createdAtMillis: createdAtMillis,
                lastUsedAtMillis: lastUsedAtMillis,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TemplatesTable,
      TemplateRow,
      $$TemplatesTableFilterComposer,
      $$TemplatesTableOrderingComposer,
      $$TemplatesTableAnnotationComposer,
      $$TemplatesTableCreateCompanionBuilder,
      $$TemplatesTableUpdateCompanionBuilder,
      (
        TemplateRow,
        BaseReferences<_$AppDatabase, $TemplatesTable, TemplateRow>,
      ),
      TemplateRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$HabitsTableTableManager get habits =>
      $$HabitsTableTableManager(_db, _db.habits);
  $$PeopleTableTableManager get people =>
      $$PeopleTableTableManager(_db, _db.people);
  $$CompletionsTableTableManager get completions =>
      $$CompletionsTableTableManager(_db, _db.completions);
  $$RestDayBudgetsTableTableManager get restDayBudgets =>
      $$RestDayBudgetsTableTableManager(_db, _db.restDayBudgets);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$EventLogsTableTableManager get eventLogs =>
      $$EventLogsTableTableManager(_db, _db.eventLogs);
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db, _db.events);
  $$PersonGroupsTableTableManager get personGroups =>
      $$PersonGroupsTableTableManager(_db, _db.personGroups);
  $$PersonGroupMembersTableTableManager get personGroupMembers =>
      $$PersonGroupMembersTableTableManager(_db, _db.personGroupMembers);
  $$TemplatesTableTableManager get templates =>
      $$TemplatesTableTableManager(_db, _db.templates);
}
