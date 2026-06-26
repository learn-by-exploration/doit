// Unit tests for WidgetStateCache (v1.4a / Phase 28 /
// SYS-115 / ADR-045 / WF-042).
//
// Coverage:
//   - save-then-load round-trips
//   - load returns null on empty prefs
//   - clear removes the key
//   - save overwrites previous
//   - corrupt cache (non-JSON) is dropped, load returns null
//   - resetForTesting clears the in-process snapshot

import 'package:doit/widget/doit_widget_state.dart';
import 'package:doit/widget/widget_state_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    WidgetStateCache.instance.resetForTesting();
  });

  DoitWidgetState sample() => DoitWidgetState(
    habitId: 'h1',
    habitName: 'Read',
    streakNumber: 7,
    isCompletedToday: false,
    reliability: DoitWidgetReliability.optimal,
    asOf: DateTime(2026, 6, 15, 10),
  );

  test('save-then-load round-trips', () async {
    final cache = WidgetStateCache.instance;
    final state = sample();
    await cache.save(state);
    final loaded = await cache.load();
    expect(loaded, equals(state));
  });

  test('load returns null on empty prefs', () async {
    final cache = WidgetStateCache.instance;
    expect(await cache.load(), isNull);
    expect(cache.cached, isNull);
  });

  test('clear removes the key', () async {
    final cache = WidgetStateCache.instance;
    await cache.save(sample());
    await cache.clear();
    expect(await cache.load(), isNull);
    expect(cache.cached, isNull);
  });

  test('save overwrites previous', () async {
    final cache = WidgetStateCache.instance;
    await cache.save(sample());
    final newer = sample().copyWith(streakNumber: 99);
    await cache.save(newer);
    final loaded = await cache.load();
    expect(loaded!.streakNumber, 99);
  });

  test('corrupt cache is dropped', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      WidgetStateCache.cacheKey: 'not-json{',
    });
    WidgetStateCache.instance.resetForTesting();
    expect(await WidgetStateCache.instance.load(), isNull);
  });
}
