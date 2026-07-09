// v1.8-pr-e2 / SYS-195 / ADR-126: PersonChannel.launch() unit tests.
//
// Each channel subclass must build the right deep-link `Uri`:
// - ChannelDialer    → tel:+<E164>
// - ChannelWhatsApp  → https://wa.me/<digits>?text=<body>
// - ChannelTelegram  → https://t.me/<handle>?text=<body>  (strips @)
// - ChannelSignal    → https://signal.me/#eu/<digits>
// - ChannelSms       → sms:+<E164>?body=<body>
//
// These tests are pure-Dart (no Flutter binding); they run in the
// default test zone. `url_launcher` is invoked at the platform layer
// (Kotlin side / `Intent.ACTION_*`); the model only returns the Uri
// the caller hands to `launchUrl` or the notification tap path.

import 'package:doit/people/person.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChannelDialer.launch()', () {
    test('returns tel:<number>', () {
      const c = ChannelDialer('+15555550100');
      expect(c.launch(), Uri.parse('tel:+15555550100'));
    });

    test(
      'returns tel:<number> even when body is passed (dialer ignores body)',
      () {
        const c = ChannelDialer('+15555550100');
        expect(c.launch(body: 'ignored'), Uri.parse('tel:+15555550100'));
      },
    );

    test('throws ArgumentError for empty handle', () {
      const c = ChannelDialer('');
      expect(() => c.launch(), throwsArgumentError);
    });

    test('tag returns "dialer"', () {
      expect(const ChannelDialer('+1').tag, 'dialer');
    });
  });

  group('ChannelWhatsApp.launch()', () {
    test('returns https://wa.me/<digits> for E.164 number', () {
      const c = ChannelWhatsApp('+15555550100');
      expect(c.launch(), Uri.parse('https://wa.me/15555550100'));
    });

    test(
      'strips non-digit chars from the number (handles user-typed formatting)',
      () {
        const c = ChannelWhatsApp('+1 (555) 555-0100');
        expect(c.launch(), Uri.parse('https://wa.me/15555550100'));
      },
    );

    test('appends ?text=<urlencoded body>', () {
      const c = ChannelWhatsApp('+15555550100');
      final uri = c.launch(body: 'hi there');
      expect(uri.scheme, 'https');
      expect(uri.host, 'wa.me');
      expect(uri.path, '/15555550100');
      expect(uri.queryParameters['text'], 'hi there');
    });

    test('omits ?text= when body is null or empty', () {
      const c = ChannelWhatsApp('+15555550100');
      // ignore: avoid_redundant_argument_values
      expect(c.launch(body: null).queryParameters.containsKey('text'), isFalse);
      expect(c.launch(body: '').queryParameters.containsKey('text'), isFalse);
    });

    test('URL-encodes special characters in the body', () {
      const c = ChannelWhatsApp('+15555550100');
      final uri = c.launch(body: 'hi & bye?');
      // & and ? must be percent-encoded so the URI parses cleanly.
      // Dart's Uri percent-encodes spaces as `+` (form-style) or
      // `%20` (RFC 3986) depending on context — accept either.
      final s = uri.toString();
      expect(
        s,
        anyOf(contains('hi+%26+bye%3F'), contains('hi%20%26%20bye%3F')),
      );
      // Round-trip the URI and confirm the body decodes back to original.
      expect(Uri.decodeComponent(uri.queryParameters['text']!), 'hi & bye?');
    });

    test('throws ArgumentError for empty handle', () {
      const c = ChannelWhatsApp('');
      expect(() => c.launch(), throwsArgumentError);
    });

    test('tag returns "whatsapp"', () {
      expect(const ChannelWhatsApp('+1').tag, 'whatsapp');
    });
  });

  group('ChannelTelegram.launch()', () {
    test('returns https://t.me/<handle>', () {
      const c = ChannelTelegram('alice');
      expect(c.launch(), Uri.parse('https://t.me/alice'));
    });

    test('strips a leading @ from the handle', () {
      const c = ChannelTelegram('@alice');
      expect(c.launch(), Uri.parse('https://t.me/alice'));
    });

    test('appends ?text=<urlencoded body>', () {
      const c = ChannelTelegram('alice');
      final uri = c.launch(body: 'hello');
      expect(uri.scheme, 'https');
      expect(uri.host, 't.me');
      expect(uri.path, '/alice');
      expect(uri.queryParameters['text'], 'hello');
    });

    test('throws ArgumentError for empty handle', () {
      const c = ChannelTelegram('');
      expect(() => c.launch(), throwsArgumentError);
    });

    test('tag returns "telegram"', () {
      expect(const ChannelTelegram('alice').tag, 'telegram');
    });
  });

  group('ChannelSignal.launch()', () {
    test('returns https://signal.me/#eu/<digits>', () {
      const c = ChannelSignal('+15555550100');
      expect(c.launch(), Uri.parse('https://signal.me/#eu/15555550100'));
    });

    test('strips non-digit chars from the number', () {
      const c = ChannelSignal('+1 (555) 555-0100');
      expect(c.launch(), Uri.parse('https://signal.me/#eu/15555550100'));
    });

    test('ignores body (Signal does not pre-fill a message)', () {
      const c = ChannelSignal('+15555550100');
      expect(
        c.launch(body: 'ignored'),
        Uri.parse('https://signal.me/#eu/15555550100'),
      );
    });

    test('throws ArgumentError for empty handle', () {
      const c = ChannelSignal('');
      expect(() => c.launch(), throwsArgumentError);
    });

    test('tag returns "signal"', () {
      expect(const ChannelSignal('+1').tag, 'signal');
    });
  });

  group('ChannelSms.launch()', () {
    test('returns sms:<number>', () {
      const c = ChannelSms('+15555550100');
      expect(c.launch(), Uri.parse('sms:+15555550100'));
    });

    test('appends ?body=<urlencoded body>', () {
      const c = ChannelSms('+15555550100');
      final uri = c.launch(body: 'hello world');
      expect(uri.scheme, 'sms');
      expect(uri.path, '+15555550100');
      expect(uri.queryParameters['body'], 'hello world');
    });

    test('omits ?body= when body is null or empty', () {
      const c = ChannelSms('+15555550100');
      // ignore: avoid_redundant_argument_values
      expect(c.launch(body: null).queryParameters.containsKey('body'), isFalse);
      expect(c.launch(body: '').queryParameters.containsKey('body'), isFalse);
    });

    test('throws ArgumentError for empty handle', () {
      const c = ChannelSms('');
      expect(() => c.launch(), throwsArgumentError);
    });

    test('tag returns "sms"', () {
      expect(const ChannelSms('+1').tag, 'sms');
    });
  });

  group('tag discrimination', () {
    test('every channel reports a non-empty unique tag', () {
      const channels = <PersonChannel>[
        ChannelDialer('+1'),
        ChannelWhatsApp('+1'),
        ChannelTelegram('a'),
        ChannelSignal('+1'),
        ChannelSms('+1'),
      ];
      final tags = channels.map((c) => c.tag).toList();
      // All non-empty.
      expect(tags.every((t) => t.isNotEmpty), isTrue);
      // All distinct.
      expect(
        tags.toSet().length,
        channels.length,
        reason: 'tags must be unique per subclass',
      );
    });
  });

  // v1.8-pr-e2 / SYS-195 / ADR-126: the `fromTag` factory
  // is the reverse of `tag` — the Dart side stores
  // `ScheduledMessage.channelTag` + `channelHandle` as plain
  // strings (Drift TEXT columns) and rebuilds the
  // `PersonChannel` on read.
  group('PersonChannel.fromTag', () {
    test('dialer tag → ChannelDialer', () {
      final c = PersonChannel.fromTag('dialer', '+15555550100');
      expect(c, isA<ChannelDialer>());
      expect((c as ChannelDialer).phoneNumber, '+15555550100');
    });

    test('whatsapp tag → ChannelWhatsApp', () {
      final c = PersonChannel.fromTag('whatsapp', '+15555550100');
      expect(c, isA<ChannelWhatsApp>());
    });

    test('telegram tag → ChannelTelegram', () {
      final c = PersonChannel.fromTag('telegram', 'alice');
      expect(c, isA<ChannelTelegram>());
      expect((c as ChannelTelegram).username, 'alice');
    });

    test('signal tag → ChannelSignal', () {
      final c = PersonChannel.fromTag('signal', '+15555550100');
      expect(c, isA<ChannelSignal>());
    });

    test('sms tag → ChannelSms', () {
      final c = PersonChannel.fromTag('sms', '+15555550100');
      expect(c, isA<ChannelSms>());
    });

    test('unknown tag throws ArgumentError', () {
      expect(() => PersonChannel.fromTag('mystery', '+1'), throwsArgumentError);
    });

    test('round-trip: tag → fromTag(tag, h).tag === tag', () {
      // The fromTag factory must produce a channel whose
      // `tag` getter is identical to the input tag (so
      // a fromTag() + tag round-trip is the identity).
      for (final tag in ['dialer', 'whatsapp', 'telegram', 'signal', 'sms']) {
        final c = PersonChannel.fromTag(tag, '+1');
        expect(c.tag, tag, reason: 'round-trip must be identity for $tag');
      }
    });
  });
}
