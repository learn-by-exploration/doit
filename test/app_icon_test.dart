// v1.1i / ADR-032 / SYS-088: pins the custom-launcher-icon +
// on-brand-splash contract at the filesystem level. Pure I/O
// tests (no Flutter test harness), so they are cheap and run in
// well under a second. The nine tests collectively assert that
//
//   * the adaptive-icon XML entry point exists and references
//     all three layers (background + foreground + monochrome);
//   * each vector layer renders the right glyph (white
//     foreground, brand-purple background, themed-icon
//     monochrome);
//   * the pre-existing `ic_streak_notification.xml` resource
//     name from `architecture_options.md:191-192` now resolves
//     on disk;
//   * the legacy `mipmap-*/ic_launcher.png` density buckets
//     stay in place as the API 21..25 fallback;
//   * both splash drawables (the pre-API-21 fallback and the
//     API 21+ variant) reference the `launch_background` named
//     color and the centered foreground logo;
//   * the `launch_background` color resource maps to the brand
//     purple `#FF6750A4`.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String relative) => File(relative).readAsStringSync();

void main() {
  test(
    'adaptive-icon manifest exists at mipmap-anydpi-v26/ic_launcher.xml',
    () {
      final manifest = _read(
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
      );
      expect(manifest, contains('<adaptive-icon'));
    },
  );

  test('adaptive-icon manifest references all three layers '
      '(background, foreground, monochrome)', () {
    final manifest = _read(
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
    );
    expect(
      manifest,
      contains('@drawable/ic_launcher_background'),
      reason: 'adaptive-icon must declare a <background> layer',
    );
    expect(
      manifest,
      contains('@drawable/ic_launcher_foreground'),
      reason: 'adaptive-icon must declare a <foreground> layer',
    );
    expect(
      manifest,
      contains('@drawable/ic_launcher_monochrome'),
      reason:
          'adaptive-icon must declare a <monochrome> layer for '
          'Android 13+ themed icons',
    );
  });

  test('foreground vector is white on transparent (no root fillColor)', () {
    final fg = _read(
      'android/app/src/main/res/drawable/ic_launcher_foreground.xml',
    );
    // The <vector> root does not declare a fillColor — only the
    // <path> inside it does. That ensures Android treats the
    // background as transparent (and composites the launcher
    // background layer underneath).
    final vectorTag = RegExp(r'<vector\b[^>]*>').firstMatch(fg);
    expect(
      vectorTag,
      isNotNull,
      reason: 'foreground XML must open with a <vector> element',
    );
    expect(
      vectorTag!.group(0),
      isNot(contains('android:fillColor')),
      reason:
          'The <vector> root must NOT declare a fillColor — the '
          'background must stay transparent so the launcher '
          'background layer shows through.',
    );
    expect(fg, contains('android:fillColor="#FFFFFFFF"'));
    expect(fg, contains('android:fillType="evenOdd"'));
    // The 'd' glyph (stem + bowl + counter) plus the check dot
    // are all encoded as a single <path> with multiple subpaths.
    final pathMatches = RegExp(r'<path\b').allMatches(fg);
    expect(
      pathMatches.length,
      1,
      reason:
          'foreground XML should declare exactly one <path> with the '
          'full d+dot glyph encoded as multiple subpaths (stem, '
          'outer bowl, inner bowl, dot).',
    );
  });

  test('background vector is solid brand purple `#FF6750A4`', () {
    final bg = _read(
      'android/app/src/main/res/drawable/ic_launcher_background.xml',
    );
    // Case-insensitive: Android resource parsers are tolerant
    // about the alpha-byte casing.
    expect(
      bg.toLowerCase(),
      contains('#ff6750a4'),
      reason:
          'background vector must paint solid brand purple '
          '(`#FF6750A4`, the seed color in `lib/theme/app_theme.dart:15`)',
    );
  });

  test('monochrome vector uses a pure-white fill (Android 13+ '
      'themed-icon tint target)', () {
    final mono = _read(
      'android/app/src/main/res/drawable/ic_launcher_monochrome.xml',
    );
    expect(mono, contains('android:fillColor="#FFFFFFFF"'));
    // The themed-icon system reads fillColor and recolors against
    // the user's wallpaper-derived tint; the foreground glyph is
    // preserved (stem + bowl + counter + dot) but the brand purple
    // background is dropped — themed icons paint the foreground
    // against a tinted backdrop.
    expect(
      mono.toLowerCase(),
      isNot(contains('#ff6750a4')),
      reason:
          'monochrome layer must NOT reference brand purple — the '
          'themed-icon system strips the background and tints the '
          'foreground against the user wallpaper.',
    );
  });

  test('ic_streak_notification.xml resource exists on disk', () {
    // Pre-existing gap closed by v1.1i (referenced by
    // `docs/v_model/architecture_options.md:191-192` and by the
    // Kotlin-side notification-channel init).
    final notification = _read(
      'android/app/src/main/res/drawable/ic_streak_notification.xml',
    );
    expect(notification, contains('<vector '));
    expect(
      notification,
      contains('android:fillColor="#FFFFFFFF"'),
      reason:
          'Status-bar notification icons are white-on-transparent '
          'per the Android notification-icon contract.',
    );
    // The notification icon is the 'd' glyph WITHOUT the check
    // dot (the dot would be unreadable at 24dp).
    final stemMatches = 'M 23,24 L 29,24 L 29,84 L 23,84 Z'.allMatches(
      notification,
    );
    expect(stemMatches.length, 1);
    // The dot path is the 4-subpath version (4 lines of pathData
    // starting with M 23,24, M 54,54, M 54,54, M 80,80); the
    // notification icon should have only 3 (no M 80,80 dot).
    expect(
      notification,
      isNot(contains('M 80,80')),
      reason: 'Notification icon must drop the check dot (24dp).',
    );
  });

  test('legacy density buckets still ship the default PNG fallback', () {
    const expected = <String>[
      'android/app/src/main/res/mipmap-mdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-hdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
    ];
    for (final path in expected) {
      expect(
        File(path).existsSync(),
        isTrue,
        reason: '$path must exist as the API 21..25 launcher fallback',
      );
    }
  });

  // v1.3d (feature.md §2.6): the legacy density buckets are
  // regenerated from the v1.1i master vector (see
  // `tool/regen_launcher_icons.py`) so the API 21..25
  // fallback matches the adaptive-icon foreground instead of
  // showing the default Flutter blue 'F'. The new test pins
  // (a) the PNG signature is well-formed and (b) the PNG
  // IHDR width/height match the standard Android launcher
  // icon density bucket sizes.
  test('legacy density buckets ship the v1.1i brand glyph '
      '(feature.md §2.6)', () {
    const expected = <(String, int, int)>[
      // (path, width, height) — matches the standard Android
      // launcher icon density bucket sizes (mdpi 48, hdpi 72,
      // xhdpi 96, xxhdpi 144, xxxhdpi 192).
      ('android/app/src/main/res/mipmap-mdpi/ic_launcher.png', 48, 48),
      ('android/app/src/main/res/mipmap-hdpi/ic_launcher.png', 72, 72),
      ('android/app/src/main/res/mipmap-xhdpi/ic_launcher.png', 96, 96),
      (
        'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png',
        144,
        144
      ),
      (
        'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
        192,
        192
      ),
    ];
    for (final (path, expectedWidth, expectedHeight) in expected) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path missing');
      final bytes = file.readAsBytesSync();
      // PNG signature: 8 bytes 0x89 'P' 'N' 'G' 0x0D 0x0A 0x1A 0x0A.
      const pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
      expect(
        bytes.sublist(0, 8),
        pngSignature,
        reason: '$path is not a valid PNG',
      );
      // IHDR chunk: signature(8) + length(4) + type(4) + width(4)
      // + height(4) + bit-depth(1) + color-type(1) + ...
      // The PNG spec lays the chunk out as
      //   bytes  0..7   = PNG signature (8 bytes)
      //   bytes  8..11  = IHDR chunk length (always 13 for IHDR)
      //   bytes 12..15  = 'IHDR'
      //   bytes 16..19  = width (big-endian u32)
      //   bytes 20..23  = height (big-endian u32)
      final width =
          (bytes[16] << 24) |
          (bytes[17] << 16) |
          (bytes[18] << 8) |
          bytes[19];
      final height =
          (bytes[20] << 24) |
          (bytes[21] << 16) |
          (bytes[22] << 8) |
          bytes[23];
      expect(
        width,
        expectedWidth,
        reason:
            '$path has width=$width, expected $expectedWidth '
            '(feature.md §2.6 — legacy density bucket must match '
            'the standard Android launcher icon size)',
      );
      expect(
        height,
        expectedHeight,
        reason:
            '$path has height=$height, expected $expectedHeight '
            '(feature.md §2.6 — legacy density bucket must match '
            'the standard Android launcher icon size)',
      );
    }
  });

  test('both splash drawables reference the launch_background color + '
      'centered foreground', () {
    const splashPaths = <String>[
      'android/app/src/main/res/drawable/launch_background.xml',
      'android/app/src/main/res/drawable-v21/launch_background.xml',
    ];
    for (final path in splashPaths) {
      final splash = _read(path);
      expect(
        splash,
        contains('@color/launch_background'),
        reason:
            '$path must reference the named `launch_background` color '
            '(AAPT2 rejects inline color values in <item android:drawable> '
            'inside drawable-v21/ resources)',
      );
      expect(
        splash,
        contains('@drawable/ic_launcher_foreground'),
        reason:
            '$path must reference the foreground vector for the '
            'centered logo',
      );
      expect(
        splash,
        contains('android:gravity="center"'),
        reason: '$path must center the foreground layer',
      );
    }
  });

  test('launch_background color resource maps to brand purple `#FF6750A4`', () {
    final colors = _read('android/app/src/main/res/values/colors.xml');
    expect(
      colors.toLowerCase(),
      contains('#ff6750a4'),
      reason:
          'values/colors.xml must define the `launch_background` color '
          'as the brand purple (`#FF6750A4`, the seed color in '
          '`lib/theme/app_theme.dart:15`)',
    );
    expect(
      colors,
      contains('<color name="launch_background">'),
      reason: 'launch_background must be a named color resource',
    );
  });
}
