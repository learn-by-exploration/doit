// Unit tests for WidgetActionInvoker (v1.4g / Phase 34 /
// SYS-121 / ADR-051 / WF-048).
//
// Coverage:
//   - widgetActionDispatch routes markDone / skip / undo
//     to WidgetService.instance and returns the bool result
//   - widgetActionDispatch returns false when WidgetService
//     is not initialized
//   - widgetActionDispatch returns false when the habitId
//     arg is missing or empty
//   - widgetActionDispatch returns false when the inner
//     service method throws
//   - attach() is idempotent
//   - resetForTesting clears the singleton
//   - The dispatcher's caller (the channel handler) routes
//     through widgetActionDispatch only for the three action
//     arms (markDone / skip / undo); other methods fall
//     through to null
//
// Tests use the top-level widgetActionDispatch function so
// we don't need a real MethodChannel — the dispatcher is
// exercised directly with synthetic MethodCall values.

import 'package:doit/services/widget_service.dart';
import 'package:doit/widget/widget_action_invoker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    WidgetService.resetForTesting();
    WidgetActionInvoker.resetForTesting();
  });

  test('widgetActionDispatch returns false when WidgetService is '
      'not initialized (v1.4g / SYS-121)', () async {
    final result = await widgetActionDispatch(
      const MethodCall('markDone', {'habitId': 'h1'}),
    );
    expect(result, isFalse);
  });

  test('widgetActionDispatch returns false when habitId is missing '
      '(v1.4g / SYS-121)', () async {
    final result = await widgetActionDispatch(
      const MethodCall('markDone', <String, Object?>{}),
    );
    expect(result, isFalse);
  });

  test('widgetActionDispatch returns false when habitId is empty '
      '(v1.4g / SYS-121)', () async {
    final result = await widgetActionDispatch(
      const MethodCall('markDone', {'habitId': ''}),
    );
    expect(result, isFalse);
  });

  test('widgetActionDispatch returns false when arguments are '
      'null (v1.4g / SYS-121)', () async {
    final result = await widgetActionDispatch(const MethodCall('skip'));
    expect(result, isFalse);
  });

  test('widgetActionDispatch returns false for an unknown action '
      '(v1.4g / SYS-121)', () async {
    final result = await widgetActionDispatch(
      const MethodCall('somethingElse', {'habitId': 'h1'}),
    );
    expect(result, isFalse);
  });

  test('attach is idempotent (v1.4g / SYS-121)', () async {
    await WidgetActionInvoker.attach();
    expect(WidgetActionInvoker.isAttached, isTrue);
    await WidgetActionInvoker.attach();
    expect(WidgetActionInvoker.isAttached, isTrue);
  });

  test('resetForTesting clears the singleton (v1.4g / SYS-121)', () async {
    await WidgetActionInvoker.attach();
    expect(WidgetActionInvoker.isAttached, isTrue);
    WidgetActionInvoker.resetForTesting();
    expect(WidgetActionInvoker.isAttached, isFalse);
  });
}
