// v1.8-pr-e2 / SYS-195 / ADR-126 / WF-122.
//
// Pins the Android 11+ package-visibility contract declared
// in `android/app/src/main/AndroidManifest.xml`. The
// `<queries>` block tells the OS which packages + intent
// shapes our `url_launcher` calls are allowed to resolve on
// Android 11+ (API 30+). Without the entries in this block,
// every channel launch (WhatsApp / Telegram / Signal / SMS /
// dialer) silently resolves `false` on a device that has the
// target app installed but the app is not on the OS
// pre-installed list (most modern devices).
//
// The Kotlin-side builder (`MainActivity.uriPendingIntent`)
// is reviewed alongside this test; the test pins the
// manifest half of the contract only.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

void main() {
  test(
    'AndroidManifest declares the WhatsApp / Telegram / Signal packages + sms/tel intents under <queries>',
    () {
      // The manifest is at android/app/src/main/AndroidManifest.xml
      // relative to the package root. The Flutter test runner
      // runs from the package root, so a relative path works.
      final manifestPath = p.join(
        'android',
        'app',
        'src',
        'main',
        'AndroidManifest.xml',
      );
      final file = File(manifestPath);
      expect(
        file.existsSync(),
        isTrue,
        reason: 'AndroidManifest.xml not found at $manifestPath',
      );

      final doc = XmlDocument.parse(file.readAsStringSync());

      // Find the top-level <queries> block.
      final queries = doc.findAllElements('queries').toList();
      expect(queries, hasLength(1), reason: 'expected exactly one <queries>');

      final inner = queries.first;

      // --- package visibility: WhatsApp / Telegram / Signal ---
      final packages = inner
          .findElements('package')
          .map((e) => e.getAttribute('android:name'))
          .whereType<String>()
          .toSet();
      expect(packages.contains('com.whatsapp'), isTrue);
      expect(packages.contains('com.whatsapp.w4b'), isTrue);
      expect(packages.contains('org.telegram.messenger'), isTrue);
      expect(packages.contains('org.thoughtcrime.securesms'), isTrue);

      // --- intent visibility: sms + tel ---
      final intentEntries = inner.findElements('intent').toList();
      expect(intentEntries, isNotEmpty);

      String? smsAction;
      String? smsScheme;
      String? telAction;
      String? telScheme;
      for (final intent in intentEntries) {
        final actionEl = intent.findElements('action');
        final dataEl = intent.findElements('data');
        final action = actionEl.isEmpty
            ? null
            : actionEl.first.getAttribute('android:name');
        final data = dataEl.isEmpty
            ? null
            : dataEl.first.getAttribute('android:scheme');
        if (action == 'android.intent.action.SENDTO' && data == 'sms') {
          smsAction = action;
          smsScheme = data;
        }
        if (action == 'android.intent.action.DIAL' && data == 'tel') {
          telAction = action;
          telScheme = data;
        }
      }
      expect(smsAction, 'android.intent.action.SENDTO');
      expect(smsScheme, 'sms');
      expect(telAction, 'android.intent.action.DIAL');
      expect(telScheme, 'tel');
    },
  );
}
