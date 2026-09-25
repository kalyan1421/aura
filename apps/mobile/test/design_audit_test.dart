// Design critique fixes (docs/design/design-critique.md): the token
// contrast the fixes rely on, the one chip selected state, the shared
// gesture tray, and the release guards (debug tools, legal placeholders).
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:aura/src/core/env/env.dart';
import 'package:aura/src/core/theme/app_theme.dart';
import 'package:aura/src/core/theme/aura_tokens.dart';
import 'package:aura/src/features/rooms/gesture_tray.dart';
import 'package:aura/src/features/rooms/room_copy.dart';
import 'package:aura/src/features/rooms/room_models.dart';
import 'package:aura/src/features/rooms/room_widgets.dart';
import 'package:aura/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// WCAG 2 relative luminance of an opaque colour.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG 2 contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('token contrast (WCAG 2)', () {
    const grounds = {
      'sky': AuraColors.sky,
      'skyHigh': AuraColors.skyHigh,
      'surface': AuraColors.surface,
    };

    test('control outline is ≥ 3:1 on every ground a control sits on '
        '(1.4.11 non-text contrast)', () {
      for (final MapEntry(key: name, value: ground) in grounds.entries) {
        expect(
          contrast(AuraColors.controlOutline, ground),
          greaterThanOrEqualTo(3),
          reason: 'controlOutline on $name',
        );
      }
      // The old outline stays a decorative hairline: below 3:1 on purpose.
      expect(contrast(AuraColors.outline, AuraColors.surface), lessThan(3));
    });

    test('a selected chip differs from an unselected one by ≥ 3:1, and its '
        'label is ≥ 4.5:1', () {
      expect(
        contrast(AuraColors.accent, AuraColors.surface),
        greaterThanOrEqualTo(3),
      );
      expect(
        contrast(AuraColors.onAccent, AuraColors.accent),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(AuraColors.text, AuraColors.surface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('the off switch: knob and track outline ≥ 3:1', () {
      expect(
        contrast(AuraColors.textMuted, AuraColors.skyHigh),
        greaterThanOrEqualTo(3),
      );
      for (final ground in grounds.values) {
        expect(
          contrast(AuraColors.controlOutline, ground),
          greaterThanOrEqualTo(3),
        );
      }
    });

    test('the danger tone is ≥ 4.5:1 text on the sky and on cards', () {
      for (final MapEntry(key: name, value: ground) in grounds.entries) {
        expect(
          contrast(AuraColors.danger, ground),
          greaterThanOrEqualTo(4.5),
          reason: 'danger on $name',
        );
      }
    });
  });

  group('one chip selected state', () {
    test('theme: lavender fill, dark label, a check, 3:1 idle outline', () {
      final theme = buildAuraTheme(const Locale('en')).chipTheme;
      expect(theme.selectedColor, AuraColors.accent);
      expect(theme.checkmarkColor, AuraColors.onAccent);
      expect(theme.showCheckmark, isTrue);
      final side = theme.side! as WidgetStateBorderSide;
      expect(side.resolve({})!.color, AuraColors.controlOutline);
      expect(side.resolve({WidgetState.selected})!.color, AuraColors.accent);
      expect(
        chipLabelColor.resolve({WidgetState.selected}),
        AuraColors.onAccent,
      );
      expect(chipLabelColor.resolve({}), AuraColors.text);
    });

    testWidgets('a selected FilterChip and ChoiceChip read as selected and '
        'draw on the lavender fill', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        localized(
          Scaffold(
            body: Wrap(
              children: [
                FilterChip(
                  key: const ValueKey('f'),
                  label: const Text('Sleep'),
                  selected: true,
                  onSelected: (_) {},
                ),
                ChoiceChip(
                  key: const ValueKey('c'),
                  label: const Text('4-7-8'),
                  selected: true,
                  onSelected: (_) {},
                ),
                ChoiceChip(
                  key: const ValueKey('u'),
                  label: const Text('Box'),
                  selected: false,
                  onSelected: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final key in ['f', 'c']) {
        expect(
          tester.getSemantics(find.byKey(ValueKey(key))),
          isSemantics(isSelected: true),
          reason: key,
        );
      }
      expect(
        tester.getSemantics(find.byKey(const ValueKey('u'))),
        isSemantics(isSelected: false),
      );
      // The selected label is drawn in the dark on-accent colour.
      final label = tester.widget<DefaultTextStyle>(
        find
            .ancestor(
              of: find.text('Sleep'),
              matching: find.byType(DefaultTextStyle),
            )
            .first,
      );
      expect(label.style.color, AuraColors.onAccent);
      handle.dispose();
    });
  });

  group('GestureTray', () {
    testWidgets('both densities: the eight presets in one order with the '
        'shared icons', (tester) async {
      for (final density in GestureTrayDensity.values) {
        final sent = <GestureType>[];
        await tester.pumpWidget(
          localized(
            Scaffold(
              body: Builder(
                builder: (context) => SingleChildScrollView(
                  child: GestureTray(
                    density: density,
                    items: presetGestureItems(
                      AppLocalizations.of(context),
                      hint: 'Sends to everyone here',
                      onSend: sent.add,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final tiles = tester
            .widgetList<GestureTile>(find.byType(GestureTile))
            .toList();
        expect(tiles, hasLength(GestureType.values.length));
        for (final (i, g) in GestureType.values.indexed) {
          expect(tiles[i].icon, gestureIcon(g), reason: '$density ${g.wire}');
          expect(tiles[i].tileKey, ValueKey('gesture-${g.wire}'));
        }
        await tester.ensureVisible(find.byKey(const ValueKey('gesture-hug')));
        await tester.tap(find.byKey(const ValueKey('gesture-hug')));
        expect(sent, [GestureType.hug], reason: '$density');
      }
    });
  });

  group('release guards', () {
    test('debug tools (Avatar lab) are never on in a release build', () {
      expect(Env.debugToolsAllowed(release: true, requested: true), isFalse);
      expect(Env.debugToolsAllowed(release: true, requested: false), isFalse);
      expect(Env.debugToolsAllowed(release: false, requested: true), isTrue);
      expect(Env.debugToolsAllowed(release: false, requested: false), isFalse);
      // Settings and the /debug route are both gated on it.
      final settings = File('lib/src/features/settings/settings_screen.dart')
          .readAsStringSync();
      expect(settings, contains('if (Env.debugTools)'));
      final routes = File('lib/src/core/router/routes.dart').readAsStringSync();
      expect(routes, contains('Env.debugTools ? null : Routes.root'));
      final env = File('lib/src/core/env/env.dart').readAsStringSync();
      expect(env, contains('static const bool debugTools = !kReleaseMode &&'));
    });

    test('the local placeholders are what the release guard rejects', () {
      // Debug / test builds show obvious placeholders on purpose.
      for (final v in [
        Env.grievanceOfficerName,
        Env.grievanceOfficerEmail,
        Env.supportEmail,
        Env.privacyPolicyUrl,
        Env.termsUrl,
      ]) {
        expect(Env.isPlaceholderLegal(v), isTrue, reason: v);
      }
      expect(Env.isPlaceholderLegal(''), isTrue);
      expect(Env.isPlaceholderLegal('grievance@akvega.in'), isFalse);
      expect(Env.isPlaceholderLegal('A. Kalyan'), isFalse);
    });

    group('ios/scripts/release_legal_check.sh', () {
      const script = 'ios/scripts/release_legal_check.sh';
      String defines(Map<String, String> values) => [
        for (final MapEntry(:key, :value) in values.entries)
          base64.encode(utf8.encode('$key=$value')),
      ].join(',');
      const real = {
        'AURA_GRIEVANCE_NAME': 'A. Officer',
        'AURA_GRIEVANCE_EMAIL': 'grievance@akvega.in',
        'AURA_SUPPORT_EMAIL': 'support@akvega.in',
        'AURA_PRIVACY_URL': 'https://akvega.in/aura/privacy',
        'AURA_TERMS_URL': 'https://akvega.in/aura/terms',
      };
      Future<ProcessResult> run(
        String configuration,
        Map<String, String> values, {
        bool allow = false,
      }) => Process.run(
        'sh',
        [script],
        environment: {
          'CONFIGURATION': configuration,
          'DART_DEFINES': defines(values),
          if (allow) 'AURA_ALLOW_PLACEHOLDER_LEGAL': '1',
        },
      );

      test('release with real values passes', () async {
        final r = await run('Release', real);
        expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      });

      test('release with a placeholder or a missing value fails', () async {
        final placeholder = await run('Release', {
          ...real,
          'AURA_GRIEVANCE_NAME': 'Grievance Officer (placeholder)',
        });
        expect(placeholder.exitCode, isNot(0));
        expect('${placeholder.stderr}', contains('AURA_GRIEVANCE_NAME'));

        final example = await run('Release', {
          ...real,
          'AURA_SUPPORT_EMAIL': 'support@example.com',
        });
        expect(example.exitCode, isNot(0));

        final missing = await run('Release', {
          for (final e in real.entries)
            if (e.key != 'AURA_GRIEVANCE_EMAIL') e.key: e.value,
        });
        expect(missing.exitCode, isNot(0));
        expect('${missing.stderr}', contains('AURA_GRIEVANCE_EMAIL'));
      });

      test(
        'debug and profile are untouched; the override only warns',
        () async {
          expect((await run('Debug', const {})).exitCode, 0);
          expect((await run('Profile', const {})).exitCode, 0);
          final allowed = await run('Release', const {}, allow: true);
          expect(allowed.exitCode, 0);
          expect('${allowed.stdout}', contains('warning'));
        },
      );

      test('wired into the Runner target and the Android release build', () {
        final pbx = File('ios/Runner.xcodeproj/project.pbxproj')
            .readAsStringSync();
        expect(pbx, contains('scripts/release_legal_check.sh'));
        expect(pbx, contains('/* Release legal check */,'));
        final gradle = File('android/app/build.gradle.kts').readAsStringSync();
        expect(gradle, contains('val verifyReleaseLegal by tasks.registering'));
        expect(
          gradle,
          contains(
            'tasks.matching { it.name == "preReleaseBuild" }.configureEach '
            '{ dependsOn(verifyReleaseLegal) }',
          ),
        );
        for (final marker in Env.placeholderMarkers) {
          expect(gradle, contains('"$marker"'), reason: marker);
          expect(
            File(script).readAsStringSync(),
            contains('*$marker*'),
            reason: marker,
          );
        }
      });
    });
  });
}
