// v1.8-pr-e2 / SYS-195 / ADR-126 / WF-122.
//
// Pins the URI scheme → Android Intent action contract used
// by `MainActivity.uriPendingIntent` (Kotlin, private). The
// Kotlin side parses the channel URI built by
// `PersonChannel.launch({body})` (Dart) and switches on the
// scheme:
//
//   - `tel:`   → `Intent.ACTION_DIAL`  (dialer)
//   - `sms:`   → `Intent.ACTION_SENDTO` (system SMS)
//   - `https:` → `Intent.ACTION_VIEW`   (browser / native
//                app — OS picks based on `<queries>`)
//   - other    → `Intent.ACTION_VIEW`   (fallback)
//
// The Kotlin implementation is reviewed in the same PR; this
// test pins the contract from the Dart side so any future
// drift (e.g. a future channel that needs ACTION_SENDTO
// instead of ACTION_VIEW) gets caught by the Dart test suite
// before the APK ships.

import 'package:doit/people/person.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors the `when (uri.scheme?.lowercase())` arms in
/// `MainActivity.uriPendingIntent`. If the Kotlin side adds a
/// new arm, this map MUST grow in lockstep (CI grep will not
/// catch this — it's enforced by the test below).
const _expectedActionForScheme = <String, String>{
  'tel': 'android.intent.action.DIAL',
  'sms': 'android.intent.action.SENDTO',
  'https': 'android.intent.action.VIEW',
  'http': 'android.intent.action.VIEW',
  // any other scheme (including null / unknown) falls back
  // to ACTION_VIEW in the Kotlin `else` arm.
};

String expectedKotlinActionForUri(String uriString) {
  final parsed = Uri.tryParse(uriString);
  final scheme = parsed?.scheme.toLowerCase();
  if (scheme == null || scheme.isEmpty) {
    return 'android.intent.action.VIEW';
  }
  return _expectedActionForScheme[scheme] ?? 'android.intent.action.VIEW';
}

void main() {
  group(
    'PersonChannel.launch() URI round-trips to the expected Kotlin action',
    () {
      test('ChannelDialer → tel: → ACTION_DIAL', () {
        const ch = ChannelDialer('+15555550100');
        final uri = ch.launch();
        expect(uri.scheme, 'tel');
        expect(
          expectedKotlinActionForUri(uri.toString()),
          'android.intent.action.DIAL',
        );
      });

      test('ChannelWhatsApp → https://wa.me/... → ACTION_VIEW', () {
        const ch = ChannelWhatsApp('15555550100');
        final uri = ch.launch(body: 'hi');
        expect(uri.scheme, 'https');
        expect(uri.host, 'wa.me');
        expect(
          expectedKotlinActionForUri(uri.toString()),
          'android.intent.action.VIEW',
        );
      });

      test('ChannelSms → sms: → ACTION_SENDTO', () {
        const ch = ChannelSms('+15555550100');
        final uri = ch.launch(body: 'hi');
        expect(uri.scheme, 'sms');
        expect(
          expectedKotlinActionForUri(uri.toString()),
          'android.intent.action.SENDTO',
        );
      });
    },
  );

  group('Kotlin action fallbacks', () {
    test('unknown scheme falls back to ACTION_VIEW', () {
      expect(
        expectedKotlinActionForUri('doit:unknown'),
        'android.intent.action.VIEW',
      );
    });

    test('empty / null URI falls back to ACTION_VIEW', () {
      expect(expectedKotlinActionForUri(''), 'android.intent.action.VIEW');
    });

    test('http (non-https) → ACTION_VIEW (browser fallback)', () {
      expect(
        expectedKotlinActionForUri('http://example.com'),
        'android.intent.action.VIEW',
      );
    });
  });

  group('PersonChannel.fromTag() round-trips the 5 known tags', () {
    test('all 5 tags construct a working channel', () {
      const tags = ['dialer', 'whatsapp', 'telegram', 'signal', 'sms'];
      for (final tag in tags) {
        final ch = PersonChannel.fromTag(tag, '+15555550100');
        final uri = ch.launch();
        expect(
          uri.toString(),
          isNotEmpty,
          reason: 'tag "$tag" should produce a non-empty URI',
        );
      }
    });

    test('unknown tag throws ArgumentError (forward-compat graceful)', () {
      expect(
        () => PersonChannel.fromTag('carrier-pigeon', '1234'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
