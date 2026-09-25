import 'package:aura/src/features/rooms/intention_copy.dart';
import 'package:aura/src/features/rooms/room_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rooms_fakes.dart';

/// Tonight's intention words from the console (`GET /v1/intentions`,
/// contracts/api/v1-rooms.md §1.10): the room shows the server's line for
/// the app's language first, then the bundled string, and hides the card for
/// a key it has no words for.
Map<String, dynamic> _litWith(String key) {
  final d = detailJson(state: 'lantern_hour', lantern: true);
  final room = d['room'] as Map<String, dynamic>;
  room['lantern'] = {'level': 1, 'maxLevel': 5, 'active': true};
  room['intention'] = {'key': key, 'holds': 3, 'open': true};
  (d['me'] as Map<String, dynamic>)['holdingIntention'] = false;
  return d;
}

const _words = {
  'lights_low': {
    'en': 'Lights low for the last hour',
    'te': 'చివరి గంట లైట్లు తక్కువగా',
    'te-Latn': 'Chivari ganta lights takkuva ga',
    'hi': 'आख़िरी घंटे में रोशनी धीमी',
    'hi-Latn': 'Aakhri ghante mein roshni dheemi',
  },
  'gentle_with_myself': {
    'en': 'Be kind to myself tonight',
    'te': 'ఈ రాత్రి నా పట్ల దయగా',
    'te-Latn': 'Ee raatri naa patla daya ga',
    'hi': 'आज रात खुद पर मेहरबानी',
    'hi-Latn': 'Aaj raat khud par meharbaani',
  },
};

void main() {
  group('parsing and language', () {
    test('keeps well-formed keys and lines, drops the rest', () {
      final copy = parseIntentionCopy({
        'version': 'v1',
        'intentions': [
          {'key': 'lights_low', 'texts': _words['lights_low']},
          {
            'key': 'Bad Key',
            'texts': {'en': 'x'},
          },
          {'key': 'no_texts'},
          {
            'key': 'blank',
            'texts': {'en': '  '},
          },
          'nonsense',
        ],
      });
      expect(copy.keys, ['lights_low']);
      expect(copy['lights_low']!['te-Latn'], 'Chivari ganta lights takkuva ga');
      expect(parseIntentionCopy(null), isEmpty);
      expect(parseIntentionCopy({'intentions': 'x'}), isEmpty);
    });

    test('the app locale picks its line (romanized locales by script)', () {
      expect(intentionLocaleTag(const Locale('en')), 'en');
      expect(intentionLocaleTag(const Locale('te')), 'te');
      expect(
        intentionLocaleTag(
          const Locale.fromSubtags(languageCode: 'te', scriptCode: 'Latn'),
        ),
        'te-Latn',
      );
      expect(
        intentionLocaleTag(
          const Locale.fromSubtags(languageCode: 'hi', scriptCode: 'Latn'),
        ),
        'hi-Latn',
      );
      expect(intentionLocaleTag(const Locale('fr')), 'en');
      expect(
        serverIntentionText(_words, 'lights_low', const Locale('hi')),
        'आख़िरी घंटे में रोशनी धीमी',
      );
      expect(serverIntentionText(_words, 'nope', const Locale('en')), isNull);
      expect(
        serverIntentionText(null, 'lights_low', const Locale('en')),
        isNull,
      );
    });
  });

  group('room screen', () {
    Future<void> close(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('a preset this build does not bundle shows with the '
        "server's words", (tester) async {
      await pumpRooms(
        tester,
        const RoomScreen(roomId: roomId),
        api: FakeRoomsApi(detail: _litWith('lights_low')),
        channels: FakeChannels(),
        tag: 'te-Latn',
        extra: [intentionCopyProvider.overrideWith((ref) async => _words)],
      );
      expect(find.byKey(const ValueKey('room-intention-card')), findsOneWidget);
      expect(find.text('Chivari ganta lights takkuva ga'), findsOneWidget);
      await close(tester);
    });

    testWidgets("the console's rewording wins over the bundled line", (
      tester,
    ) async {
      await pumpRooms(
        tester,
        const RoomScreen(roomId: roomId),
        api: FakeRoomsApi(detail: _litWith('gentle_with_myself')),
        channels: FakeChannels(),
        extra: [intentionCopyProvider.overrideWith((ref) async => _words)],
      );
      expect(find.text('Be kind to myself tonight'), findsOneWidget);
      expect(find.text('Be gentle with myself tonight'), findsNothing);
      await close(tester);
    });

    testWidgets('no server words (offline, older server): the bundled line; '
        'an unknown key still hides the card', (tester) async {
      await pumpRooms(
        tester,
        const RoomScreen(roomId: roomId),
        api: FakeRoomsApi(detail: _litWith('gentle_with_myself')),
        channels: FakeChannels(),
        extra: [intentionCopyProvider.overrideWith((ref) async => const {})],
      );
      expect(find.text('Be gentle with myself tonight'), findsOneWidget);
      await close(tester);
      await pumpRooms(
        tester,
        const RoomScreen(roomId: roomId),
        api: FakeRoomsApi(detail: _litWith('lights_low')),
        channels: FakeChannels(),
        extra: [intentionCopyProvider.overrideWith((ref) async => const {})],
      );
      expect(find.byKey(const ValueKey('room-intention-card')), findsNothing);
      await close(tester);
    });
  });
}
