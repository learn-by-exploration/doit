// Tests for CallInterceptorService (v1.0 / Phase F PR 1 /
// ADR-019 / SYS-075).
//
// Coverage:
//   - `init()` is idempotent.
//   - The broadcast events stream republishes every
//     CallEvent pushed by the source.
//   - `configure(enabled, contactIds)` forwards both
//     parameters to the source.
//   - `currentRingerMode()` forwards to the source and
//     decodes the wire string.
//   - `setRingerMode(mode)` forwards to the source as a
//     wire string.
//   - `restorePriorRinger()` forwards to the source.
//   - `resetForTesting()` cancels the source subscription,
//     stops the source, and clears the contact-id cache.
//   - Multiple listeners on the broadcast stream all
//     receive every push.
//   - `callMatches` top-level predicate covers all three
//     TriggerCallIncoming leaves and the contact-id filter.
//   - `RingerMode.wireName` / `fromWire` round-trip and the
//     unknown-string fallback to `normal`.

import 'package:doit/services/call_interceptor.dart';
import 'package:doit/triggers/trigger.dart'
    show
        TriggerCallIncomingAny,
        TriggerCallIncomingKnownContact,
        TriggerCallIncomingUnknownContact;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

CallIncomingAny callAny({String number = '+15551234567'}) => CallIncomingAny(
  number: number,
  displayName: '',
  at: DateTime(2026, 6, 20, 9),
);

CallRingerOverridden callRingerOverridden({
  String number = '+15551234567',
  RingerMode priorMode = RingerMode.silent,
  RingerMode targetMode = RingerMode.normal,
}) => CallRingerOverridden(
  number: number,
  displayName: '',
  at: DateTime(2026, 6, 20, 9),
  priorMode: priorMode,
  targetMode: targetMode,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RingerMode wire codec', () {
    test('wireName + fromWire round-trip', () {
      for (final m in RingerMode.values) {
        expect(RingerMode.fromWire(m.wireName), m);
      }
    });

    test('fromWire falls back to normal on unknown value', () {
      expect(RingerMode.fromWire(null), RingerMode.normal);
      expect(RingerMode.fromWire(''), RingerMode.normal);
      expect(RingerMode.fromWire('nope'), RingerMode.normal);
    });
  });

  group('callMatches top-level predicate', () {
    test('TriggerCallIncomingAny matches every CallIncomingAny', () {
      expect(callMatches(const TriggerCallIncomingAny(), callAny()), true);
      expect(
        callMatches(const TriggerCallIncomingAny(), callAny(number: '+1')),
        true,
      );
    });

    test('TriggerCallIncomingAny does NOT match CallRingerOverridden', () {
      expect(
        callMatches(const TriggerCallIncomingAny(), callRingerOverridden()),
        false,
      );
    });

    test('TriggerCallIncomingKnownContact matches when number is in '
        'contactIds', () {
      const ids = <String>{'+15551234567'};
      expect(
        callMatches(
          const TriggerCallIncomingKnownContact(),
          callAny(),
          contactIds: ids,
        ),
        true,
      );
      expect(
        callMatches(
          const TriggerCallIncomingKnownContact(),
          callAny(number: '+15559999999'),
          contactIds: ids,
        ),
        false,
      );
    });

    test('TriggerCallIncomingUnknownContact matches when number is NOT '
        'in contactIds', () {
      const ids = <String>{'+15551234567'};
      expect(
        callMatches(
          const TriggerCallIncomingUnknownContact(),
          callAny(),
          contactIds: ids,
        ),
        false,
      );
      expect(
        callMatches(
          const TriggerCallIncomingUnknownContact(),
          callAny(number: '+15559999999'),
          contactIds: ids,
        ),
        true,
      );
    });

    test('empty contactIds makes UnknownContact always match', () {
      expect(
        callMatches(const TriggerCallIncomingUnknownContact(), callAny()),
        true,
      );
      expect(
        callMatches(const TriggerCallIncomingKnownContact(), callAny()),
        false,
      );
    });

    test('Known/Unknown predicates ignore CallRingerOverridden (not an '
        'incoming event)', () {
      // Both leaves reject non-CallIncomingAny events so a
      // ringer-override side-effect never re-fires a
      // call-routine.
      expect(
        callMatches(
          const TriggerCallIncomingKnownContact(),
          callRingerOverridden(),
          contactIds: const {'+15551234567'},
        ),
        false,
      );
      expect(
        callMatches(
          const TriggerCallIncomingUnknownContact(),
          callRingerOverridden(),
        ),
        false,
      );
    });
  });

  group('CallInterceptorService', () {
    late CallInterceptorService service;
    late ScriptedCallSource source;

    setUp(() {
      service = CallInterceptorService.instance;
      service.resetForTesting();
      source = ScriptedCallSource();
      service.debugSetSource(source);
    });

    tearDown(() {
      service.resetForTesting();
    });

    test('init() is idempotent', () async {
      await service.init();
      await service.init(); // second call must not throw
      expect(source.startCalls, 1, reason: 'start() must run once total.');
    });

    test('events stream republishes every source push', () async {
      await service.init();
      final fired = <CallEvent>[];
      final sub = service.events.listen(fired.add);

      source.push(callAny());
      source.push(callRingerOverridden());
      await Future<void>.delayed(Duration.zero);

      expect(fired, hasLength(2));
      expect(fired[0], isA<CallIncomingAny>());
      expect(fired[1], isA<CallRingerOverridden>());
      await sub.cancel();
    });

    test('configure(enabled, contactIds) forwards to the source', () async {
      await service.init();
      await service.configure(
        enabled: true,
        contactIds: ['+15551112222', '+15553334444'],
      );
      expect(source.lastEnabled, true);
      expect(source.lastContactIds, ['+15551112222', '+15553334444']);
      // contactIds cache is updated and exposed via getter.
      expect(service.contactIds, {'+15551112222', '+15553334444'});
    });

    test('configure without contactIds keeps prior contact list', () async {
      await service.init();
      await service.configure(enabled: true, contactIds: ['+15551112222']);
      await service.configure(enabled: false);
      expect(source.lastEnabled, false);
      // contactIds cache still contains the previous set.
      expect(service.contactIds, {'+15551112222'});
    });

    test('currentRingerMode() reads from the source', () async {
      await service.init();
      source.scriptedRingerMode = RingerMode.silent;
      final mode = await service.currentRingerMode();
      expect(mode, RingerMode.silent);
    });

    test('setRingerMode(mode) forwards the wire name to the source', () async {
      await service.init();
      await service.setRingerMode(RingerMode.vibrate);
      expect(source.lastRingerMode, RingerMode.vibrate);
    });

    test('restorePriorRinger() forwards to the source', () async {
      await service.init();
      await service.restorePriorRinger();
      await service.restorePriorRinger(); // idempotent
      expect(source.restorePriorRingerCalls, 2);
    });

    test(
      'resetForTesting() cancels the subscription and stops the source',
      () async {
        await service.init();
        service.resetForTesting();
        expect(source.stopCalls, 1);
        // A second reset is a no-op.
        service.resetForTesting();
        expect(source.stopCalls, 1);
      },
    );

    test('a source that throws on start() rethrows (the ready gate '
        'cannot complete with a broken source)', () async {
      service.resetForTesting();
      final failing = ScriptedCallSource()
        ..startError = StateError('plugin missing');
      service.debugSetSource(failing);
      await expectLater(service.init(), throwsA(isA<StateError>()));
    });

    test('multiple listeners all receive every push', () async {
      await service.init();
      final a = <CallEvent>[];
      final b = <CallEvent>[];
      final sa = service.events.listen(a.add);
      final sb = service.events.listen(b.add);

      source.push(callAny());
      source.push(callAny(number: '+15559999999'));
      await Future<void>.delayed(Duration.zero);

      expect(a, hasLength(2));
      expect(b, hasLength(2));
      await sa.cancel();
      await sb.cancel();
    });

    // These tests drive the production _MethodChannelCallSource
    // end-to-end: the service is reset and init() wires the
    // production channel handler (the test does NOT call
    // debugSetSource here), the simulated Kotlin-side push
    // travels via TestDefaultBinaryMessenger, and the broadcast
    // stream receives the decoded event.
    test('decodes an "incoming" event from the method channel as '
        'CallIncomingAny', () async {
      service.resetForTesting();
      await service.init();
      final received = <CallEvent>[];
      final sub = service.events.listen(received.add);

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'doit/call_interceptor',
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('onCallEvent', {
                'kind': 'incoming',
                'number': '+15551234567',
                'displayName': 'Alice',
                'atMs': 0,
              }),
            ),
            (_) {},
          );
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received.first, isA<CallIncomingAny>());
      expect((received.first as CallIncomingAny).number, '+15551234567');
      await sub.cancel();
    });

    test('decodes a "ringerOverridden" event from the method channel as '
        'CallRingerOverridden', () async {
      service.resetForTesting();
      await service.init();
      final received = <CallEvent>[];
      final sub = service.events.listen(received.add);

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'doit/call_interceptor',
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('onCallEvent', {
                'kind': 'ringerOverridden',
                'number': '+15551234567',
                'displayName': '',
                'atMs': 0,
                'priorMode': 'silent',
                'targetMode': 'normal',
              }),
            ),
            (_) {},
          );
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received.first, isA<CallRingerOverridden>());
      final r = received.first as CallRingerOverridden;
      expect(r.priorMode, RingerMode.silent);
      expect(r.targetMode, RingerMode.normal);
      await sub.cancel();
    });
  });
}
