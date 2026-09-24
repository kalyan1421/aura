import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/net/api_models.dart';
import 'package:aura/src/features/progress/progress_view.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('localization', () {
    test('locale tags round-trip, incl. romanized script codes', () {
      final l = localeFromTag('te-Latn');
      expect(l.languageCode, 'te');
      expect(l.scriptCode, 'Latn');
      expect(tagFromLocale(l), 'te-Latn');
      expect(
        AppLocalizations.supportedLocales.map(tagFromLocale),
        containsAll(['en', 'te', 'te-Latn', 'hi', 'hi-Latn']),
      );
    });

    testWidgets('Tenglish UI copy; system strings fall back to English', (
      tester,
    ) async {
      late AppLocalizations l;
      late MaterialLocalizations m;
      await tester.pumpWidget(
        localized(
          Builder(
            builder: (context) {
              l = AppLocalizations.of(context);
              m = MaterialLocalizations.of(context);
              return const SizedBox();
            },
          ),
          locale: localeFromTag('te-Latn'),
        ),
      );
      expect(l.checkin_title, 'Meeku ippudu ela anipistondi?');
      expect(l.home_glowStreak(3), 'Glow streak · 3 rojulu');
      expect(m.okButtonLabel, 'OK');
    });

    testWidgets('Telugu script UI copy', (tester) async {
      late AppLocalizations l;
      await tester.pumpWidget(
        localized(
          Builder(
            builder: (context) {
              l = AppLocalizations.of(context);
              return const SizedBox();
            },
          ),
          locale: const Locale('te'),
        ),
      );
      expect(l.help_button, 'నాకు ఇప్పుడే సహాయం కావాలి');
    });

    for (final (tag, title, help) in const [
      ('hi', 'अभी कैसा लग रहा है?', 'मुझे अभी मदद चाहिए'),
      ('hi-Latn', 'Abhi kaisa lag raha hai?', 'Mujhe abhi madad chahiye'),
    ]) {
      testWidgets('$tag UI copy (Milestone B), no English fallback; system '
          'strings: Devanagari for hi, English for Hinglish', (tester) async {
        late AppLocalizations l;
        late MaterialLocalizations m;
        await tester.pumpWidget(
          localized(
            Builder(
              builder: (context) {
                l = AppLocalizations.of(context);
                m = MaterialLocalizations.of(context);
                return const SizedBox();
              },
            ),
            locale: localeFromTag(tag),
          ),
        );
        expect(l.checkin_title, title);
        expect(l.help_button, help);
        expect(l.localeName, tag.replaceAll('-', '_'));
        if (tag == 'hi-Latn') {
          expect(m.okButtonLabel, 'OK');
        } else {
          expect(m.okButtonLabel, isNot('OK'));
        }
      });
    }
  });

  group('computeProgressView', () {
    const tz = 'Asia/Kolkata';
    final today = LocalDay.parse('2026-10-08');
    final events = [
      ProgressEvent.checkIn(
        id: 'c1',
        deviceTs: testNow,
        localDay: today,
        quadrant: Quadrant.sunrise,
      ),
    ];

    test('offline: the local projection (optimistic)', () {
      final v = computeProgressView(
        events: events,
        loaded: true,
        snapshot: null,
        pending: 1,
        now: testNow,
        timezone: tz,
        lastHue: null,
      );
      expect(v.todayStarlight, 10);
      expect(v.awards['c1'], 10);
      expect(v.provisional, isTrue);
      expect(v.avatar.hue, closeTo(45, 0.01));
    });

    Snapshot snap(int total, String stage) => Snapshot(
      avatar: SnapshotAvatar(stage: stage, hue: 175),
      streak: const SnapshotStreak(
        glowStreak: 5,
        lifetimeGlowDays: 9,
        restBank: 2,
        lastActiveDay: '2026-10-08',
      ),
      starlight: SnapshotStarlight(total: total, today: 12),
      serverTime: '2026-10-08T10:00:00Z',
      auraDay: '2026-10-08',
    );

    test('synced: the server snapshot wins (DS-5)', () {
      final v = computeProgressView(
        events: events,
        loaded: true,
        snapshot: snap(450, 'glow'),
        pending: 0,
        now: testNow,
        timezone: tz,
        lastHue: null,
      );
      expect(v.totalStarlight, 450);
      expect(v.todayStarlight, 12);
      expect(v.avatar.stage, AuraStage.glow);
      expect(v.streak.glowStreak, 5);
      expect(v.provisional, isFalse);
    });

    test('pending writes never show a lower stage than the server', () {
      final v = computeProgressView(
        events: events,
        loaded: true,
        snapshot: snap(1300, 'radiance'),
        pending: 1,
        now: testNow,
        timezone: tz,
        lastHue: null,
      );
      expect(v.avatar.stage, AuraStage.radiance);
      expect(v.totalStarlight, 1300);
    });
  });
}
