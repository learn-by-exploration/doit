// Unit tests for the Action sealed hierarchy.

import 'package:doit/triggers/action.dart';
import 'package:doit/triggers/trigger.dart' show SilentMode;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ActionNotify', () {
    test('validates non-empty title and body', () {
      expect(
        const ActionNotify(title: 'x', body: 'y').validate(),
        isA<ActionNotify>(),
      );
    });

    test('rejects empty title / body (after trim)', () {
      expect(
        () => const ActionNotify(title: '', body: 'y').validate(),
        throwsA(isA<ActionNotifyEmptyTitle>()),
      );
      expect(
        () => const ActionNotify(title: '  ', body: 'y').validate(),
        throwsA(isA<ActionNotifyEmptyTitle>()),
      );
      expect(
        () => const ActionNotify(title: 'x', body: '').validate(),
        throwsA(isA<ActionNotifyEmptyBody>()),
      );
    });

    test('equality by title + body', () {
      expect(
        const ActionNotify(title: 'a', body: 'b'),
        equals(const ActionNotify(title: 'a', body: 'b')),
      );
    });
  });

  group('ActionFullscreen', () {
    test('validates trivially', () {
      expect(const ActionFullscreen().validate(), isA<ActionFullscreen>());
    });
  });

  group('ActionCallIntercept', () {
    test('all 3 decisions validate', () {
      for (final d in CallInterceptDecision.values) {
        expect(
          ActionCallIntercept(decision: d).validate(),
          isA<ActionCallIntercept>(),
        );
      }
    });

    test('equality by decision', () {
      expect(
        const ActionCallIntercept(decision: CallInterceptDecision.decline),
        equals(
          const ActionCallIntercept(decision: CallInterceptDecision.decline),
        ),
      );
      expect(
        const ActionCallIntercept(decision: CallInterceptDecision.decline),
        isNot(
          equals(
            const ActionCallIntercept(decision: CallInterceptDecision.mute),
          ),
        ),
      );
    });
  });

  group('ActionOverrideSilent', () {
    test('all 3 modes validate', () {
      for (final m in SilentMode.values) {
        expect(
          ActionOverrideSilent(targetMode: m).validate(),
          isA<ActionOverrideSilent>(),
        );
      }
    });
  });

  group('ActionOpenApp', () {
    test('rejects empty route', () {
      expect(
        () => const ActionOpenApp(route: '').validate(),
        throwsA(isA<ActionOpenAppEmptyRoute>()),
      );
      expect(
        () => const ActionOpenApp(route: '   ').validate(),
        throwsA(isA<ActionOpenAppEmptyRoute>()),
      );
    });

    test('accepts non-empty route', () {
      expect(
        const ActionOpenApp(route: 'do/abc').validate(),
        isA<ActionOpenApp>(),
      );
    });
  });
}
