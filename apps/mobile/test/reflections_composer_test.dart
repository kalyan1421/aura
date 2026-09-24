import 'dart:async';

import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/net/aura_api.dart';
import 'package:aura/src/core/remote_config/remote_config.dart';
import 'package:aura/src/features/reflections/reflection_draft.dart';
import 'package:aura/src/features/safety/safety_center_screen.dart';
import 'package:aura/src/features/support/support_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reflections_fakes.dart';
import 'rooms_fakes.dart';

/// The reflection composer (F6, PRD 14-states "Reflection composer"):
/// characters are grapheme clusters and 201 disables Send (REQ-REF-01);
/// contact details never leave the phone (REQ-REF-02); a crisis-lexicon hit
/// opens the support sheet at once and still sends (REQ-REF-04); a
/// rejection keeps the words; limits, pause, offline and "Sending gently…";
/// the draft (and its id) survive closing and failures.

Finder _send() => find.byKey(const ValueKey('reflection-send'));
Finder _field() => find.byKey(const ValueKey('reflection-field'));

bool _sendEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_send()).onPressed != null;

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('reflections-share')));
  await settleSheet(tester);
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_field(), text);
  await tester.pump();
}

Future<void> _tapSend(WidgetTester tester) async {
  await tester.ensureVisible(_send());
  await tester.tap(_send());
  await settleRooms(tester);
}

void main() {
  group('length (REQ-REF-01)', () {
    testWidgets('the counter counts characters as a person sees them, not '
        'UTF-16 units', (tester) async {
      await pumpReflections(
        tester,
        rooms: FakeRoomsApi(),
        reflections: FakeReflectionsApi(),
      );
      await _open(tester);
      expect(find.text('0/200'), findsOneWidget);
      // 11 UTF-16 units, 5 characters (contract §0).
      await _type(tester, 'నమస్తే 🙏🏽');
      expect(find.text('5/200'), findsOneWidget);
      await _type(tester, '👩‍👩‍👧 hi');
      expect(find.text('4/200'), findsOneWidget);
      await closeAll(tester);
    });

    testWidgets('200 characters can be sent; 201 disables Send', (
      tester,
    ) async {
      await pumpReflections(
        tester,
        rooms: FakeRoomsApi(),
        reflections: FakeReflectionsApi(),
      );
      await _open(tester);
      // Each 🙏🏽 is 4 UTF-16 units but one character.
      await _type(tester, '🙏🏽' * 200);
      expect(find.text('200/200'), findsOneWidget);
      expect(_sendEnabled(tester), isTrue);
      await _type(tester, '${'🙏🏽' * 200}a');
      expect(find.text('201/200'), findsOneWidget);
      expect(_sendEnabled(tester), isFalse);
      expect(
        find.text('A little shorter, please: up to 200 characters.'),
        findsOneWidget,
      );
      await closeAll(tester);
    });

    testWidgets('empty or blank: Send stays disabled', (tester) async {
      await pumpReflections(
        tester,
        rooms: FakeRoomsApi(),
        reflections: FakeReflectionsApi(),
      );
      await _open(tester);
      expect(_sendEnabled(tester), isFalse);
      await _type(tester, '   ');
      expect(_sendEnabled(tester), isFalse);
      await closeAll(tester);
    });
  });

  testWidgets('"2 of 3 left today" from the composer state', (tester) async {
    await pumpReflections(
      tester,
      rooms: FakeRoomsApi(),
      reflections: FakeReflectionsApi(
        composer: composerJson(remainingInRoom: 2),
      ),
    );
    expect(find.text('2 of 3 left today'), findsOneWidget);
    await _open(tester);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('reflection-composer')),
        matching: find.text('2 of 3 left today'),
      ),
      findsOneWidget,
    );
    await closeAll(tester);
  });

  group('on-device checks', () {
    for (final text in [
      '98765 43210',
      'insta: @quietcomet',
      'name@okaxis',
      'తొమ్మిది ఎనిమిది ఏడు ఆరు ఐదు నాలుగు మూడు రెండు ఒకటి సున్నా',
      'check www.example.com',
    ]) {
      testWidgets('contact details / link "$text": the 14-states words, '
          'nothing is sent (REQ-REF-02)', (tester) async {
        final api = FakeReflectionsApi();
        await pumpReflections(tester, rooms: FakeRoomsApi(), reflections: api);
        await _open(tester);
        await _type(tester, text);
        await _tapSend(tester);
        expect(
          find.text(
            "Phone numbers, links and handles can't be shared here. It keeps "
            'everyone safer.',
          ),
          findsOneWidget,
        );
        expect(api.count('send'), 0);
        // The words stay to edit; the sheet stays open.
        expect(
          find.byKey(const ValueKey('reflection-composer')),
          findsOneWidget,
        );
        expect(find.text(text), findsOneWidget);
        await closeAll(tester);
      });
    }

    testWidgets('grooming phrases are not blocked on the phone (the server '
        'decides)', (tester) async {
      final api = FakeReflectionsApi();
      await pumpReflections(tester, rooms: FakeRoomsApi(), reflections: api);
      await _open(tester);
      await _type(tester, 'How old are you?');
      await _tapSend(tester);
      expect(api.count('send'), 1);
      await closeAll(tester);
    });

    testWidgets('a crisis-lexicon hit opens the support sheet at once and is '
        'still sent (REQ-REF-04); no rejection wording', (tester) async {
      final api = FakeReflectionsApi()
        ..outcome = (id, text) =>
            outcomeJson(id, status: 'crisis_diverted', showSupport: true);
      await pumpReflections(tester, rooms: FakeRoomsApi(), reflections: api);
      await _open(tester);
      // A phone number too: crisis wins.
      await _type(tester, 'I want to kill myself 98765 43210');
      await tester.tap(_send());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SupportSheet), findsOneWidget);
      expect(find.text('It sounds like a lot right now.'), findsOneWidget);
      expect(find.text("You don't have to carry it alone."), findsOneWidget);
      // "Back to the room" closes it (F9 support sheet, reflection origin).
      expect(
        tester.widget<SupportSheet>(find.byType(SupportSheet)).origin,
        SupportOrigin.reflection,
      );
      expect(find.textContaining("can't go up"), findsNothing);
      expect(find.textContaining("can't be shared"), findsNothing);
      await settleRooms(tester);
      expect(api.sends, hasLength(1));
      expect(api.sends.single.text, 'I want to kill myself 98765 43210');
      await closeAll(tester);
    });

    testWidgets('diverted by the server (no local hit): the support sheet, '
        'no rejection wording, the draft is cleared', (tester) async {
      final api = FakeReflectionsApi()
        ..outcome = (id, text) =>
            outcomeJson(id, status: 'crisis_diverted', showSupport: true);
      final db = await pumpReflections(
        tester,
        rooms: FakeRoomsApi(),
        reflections: api,
      );
      await _open(tester);
      await _type(tester, 'everything feels heavy today');
      await _tapSend(tester);
      await settleSheet(tester);
      expect(find.byType(SupportSheet), findsOneWidget);
      expect(find.byKey(const ValueKey('reflection-composer')), findsNothing);
      final draft = await tester.runAsync(
        () => db.getValue(ReflectionDraftStore.keyFor(roomId)),
      );
      expect(draft, isNull);
      await closeAll(tester);
    });
  });

  group('outcomes', () {
    testWidgets('published: the sheet closes and your card shows', (
      tester,
    ) async {
      final api = FakeReflectionsApi();
      await pumpReflections(tester, rooms: FakeRoomsApi(), reflections: api);
      await _open(tester);
      await _type(tester, 'first Diwali alone in this city');
      await _tapSend(tester);
      await settleSheet(tester);
      expect(find.byKey(const ValueKey('reflection-composer')), findsNothing);
      expect(find.text('Your reflection'), findsOneWidget);
      expect(find.text('first Diwali alone in this city'), findsOneWidget);
      expect(find.text('2 of 3 left today'), findsOneWidget);
      await closeAll(tester);
    });

    testWidgets('rejected: gentle words by category, the text stays to edit, '
        'and the next Send is a new reflection', (tester) async {
      final api = FakeReflectionsApi()
        ..outcome = (id, text) =>
            outcomeJson(id, status: 'rejected', rejectReason: 'hurtful');
      await pumpReflections(tester, rooms: FakeRoomsApi(), reflections: api);
      await _open(tester);
      await _type(tester, 'something unkind');
      await _tapSend(tester);
      expect(
        find.text(
          "This one can't go up here. It may hurt someone or share personal "
          'details. Your words are still here to edit.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('reflection-composer')), findsOneWidget);
      expect(find.text('something unkind'), findsOneWidget);
      await _type(tester, 'something kinder');
      await _tapSend(tester);
      expect(api.attempts, hasLength(2));
      expect(api.attempts[1], isNot(api.attempts[0]));
      await closeAll(tester);
    });

    testWidgets('rejected for contact details by the server: the PRD words', (
      tester,
    ) async {
      final api = FakeReflectionsApi()
        ..outcome = (id, text) => outcomeJson(
          id,
          status: 'rejected',
          rejectReason: 'contact_details',
        );
      await pumpReflections(tester, rooms: FakeRoomsApi(), reflections: api);
      await _open(tester);
      await _type(tester, 'find me later');
      await _tapSend(tester);
      expect(
        find.text(
          "Reflections can't include contact details. Want to try without it?",
        ),
        findsOneWidget,
      );
      await closeAll(tester);
    });

    testWidgets('pending: "Sending gently…", then the sheet closes and the '
        'card says "Still checking"', (tester) async {
      final api = FakeReflectionsApi()
        ..outcome = (id, text) => outcomeJson(
          id,
          status: 'pending',
          review: 'soon',
          reflection: reflectionJson(
            id,
            memberId: meId,
            pseudonym: 'Soft Harbor',
            isMine: true,
            status: 'pending',
            text: text,
            review: 'soon',
          ),
        );
      await pumpReflections(tester, rooms: FakeRoomsApi(), reflections: api);
      await _open(tester);
      await _type(tester, 'a long day');
      await _tapSend(tester);
      expect(find.text('Sending gently…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await settleSheet(tester);
      expect(find.byKey(const ValueKey('reflection-composer')), findsNothing);
      expect(
        find.text('Still checking. You can keep reading.'),
        findsOneWidget,
      );
      expect(find.text('Only you can see this'), findsOneWidget);
      await closeAll(tester);
    });

    testWidgets('held overnight: "This may take until morning"', (
      tester,
    ) async {
      final api = FakeReflectionsApi()
        ..outcome = (id, text) => outcomeJson(
          id,
          status: 'held',
          review: 'overnight',
          reflection: reflectionJson(
            id,
            memberId: meId,
            pseudonym: 'Soft Harbor',
            isMine: true,
            status: 'held',
            text: text,
            review: 'overnight',
          ),
        );
      await pumpReflections(tester, rooms: FakeRoomsApi(), reflections: api);
      await _open(tester);
      await _type(tester, 'a long day');
      await _tapSend(tester);
      await settleSheet(tester);
      expect(
        find.text('Waiting for a quick check. This may take until morning.'),
        findsWidgets,
      );
      await closeAll(tester);
    });
  });

  group('limits and pauses', () {
    testWidgets('3 sent today: no composer, "That\'s 3 reflections for '
        'today. Gestures are always open."', (tester) async {
      await pumpReflections(
        tester,
        rooms: FakeRoomsApi(),
        reflections: FakeReflectionsApi(
          composer: composerJson(state: 'limit_reached', remainingInRoom: 0),
        ),
      );
      expect(find.byKey(const ValueKey('reflections-share')), findsNothing);
      expect(
        find.text("That's 3 reflections for today. Gestures are always open."),
        findsOneWidget,
      );
      await closeAll(tester);
    });

    testWidgets('429 reflection_room_limit on Send: the limit words, Send '
        'rests, the draft stays', (tester) async {
      final api = FakeReflectionsApi(
        composer: composerJson(remainingInRoom: 1),
      );
      api.fail['send'] = const ApiException(
        code: 'reflection_room_limit',
        status: 429,
      );
      await pumpReflections(tester, rooms: FakeRoomsApi(), reflections: api);
      await _open(tester);
      // What the server says from now on.
      api.composer = composerJson(state: 'limit_reached', remainingInRoom: 0);
      await _type(tester, 'one more');
      await _tapSend(tester);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('reflection-composer')),
          matching: find.text(
            "That's 3 reflections for today. Gestures are always open.",
          ),
        ),
        findsOneWidget,
      );
      expect(_sendEnabled(tester), isFalse);
      expect(find.text('one more'), findsOneWidget);
      await closeAll(tester);
    });

    testWidgets('paused by the server: "Reflections are resting for a bit. '
        'Gestures still work."', (tester) async {
      await pumpReflections(
        tester,
        rooms: FakeRoomsApi(),
        reflections: FakeReflectionsApi(
          composer: composerJson(state: 'paused'),
        ),
      );
      expect(find.byKey(const ValueKey('reflections-share')), findsNothing);
      expect(
        find.text('Reflections are resting for a bit. Gestures still work.'),
        findsOneWidget,
      );
      await closeAll(tester);
    });

    for (final flags in [
      const RemoteFlags({'reflections_composer': FlagValue(enabled: false)}),
      const RemoteFlags({'reduced_mode': FlagValue(enabled: true)}),
    ]) {
      testWidgets('paused by the remote flags (${flags.keys.single})', (
        tester,
      ) async {
        await pumpReflections(
          tester,
          rooms: FakeRoomsApi(),
          reflections: FakeReflectionsApi(),
          flags: flags,
        );
        expect(find.byKey(const ValueKey('reflections-share')), findsNothing);
        expect(
          find.text('Reflections are resting for a bit. Gestures still work.'),
          findsOneWidget,
        );
        await closeAll(tester);
      });
    }

    testWidgets('503 reflections_paused on Send: the paused words', (
      tester,
    ) async {
      final api = FakeReflectionsApi();
      api.fail['send'] = const ApiException(
        code: 'reflections_paused',
        status: 503,
      );
      await pumpReflections(tester, rooms: FakeRoomsApi(), reflections: api);
      await _open(tester);
      api.composer = composerJson(state: 'paused');
      await _type(tester, 'hello');
      await _tapSend(tester);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('reflection-composer')),
          matching: find.text(
            'Reflections are resting for a bit. Gestures still work.',
          ),
        ),
        findsOneWidget,
      );
      await closeAll(tester);
    });

    testWidgets('slow: "Reflections are slower right now"', (tester) async {
      await pumpReflections(
        tester,
        rooms: FakeRoomsApi(),
        reflections: FakeReflectionsApi(composer: composerJson(slow: true)),
      );
      expect(find.text('Reflections are slower right now'), findsOneWidget);
      await closeAll(tester);
    });
  });

  group('drafts and connection', () {
    testWidgets('offline: Send is disabled and the draft is kept', (
      tester,
    ) async {
      final net = StreamController<bool>.broadcast();
      addTearDown(net.close);
      final api = FakeReflectionsApi();
      await pumpReflections(
        tester,
        rooms: FakeRoomsApi(),
        reflections: api,
        connectivity: net.stream,
      );
      await _open(tester);
      net.add(false);
      await settleRooms(tester);
      await _type(tester, 'written on the train');
      expect(_sendEnabled(tester), isFalse);
      expect(
        find.text("Draft kept. You can send it once you're back online."),
        findsOneWidget,
      );
      net.add(true);
      await settleRooms(tester);
      expect(_sendEnabled(tester), isTrue);
      await _tapSend(tester);
      expect(api.sends.single.text, 'written on the train');
      await closeAll(tester);
    });

    testWidgets('closing keeps the draft; it comes back when reopened', (
      tester,
    ) async {
      final db = await pumpReflections(
        tester,
        rooms: FakeRoomsApi(),
        reflections: FakeReflectionsApi(),
      );
      await _open(tester);
      await _type(tester, 'half a thought');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey('reflection-composer-close')));
      await settleSheet(tester);
      expect(find.byKey(const ValueKey('reflection-composer')), findsNothing);
      final saved = await tester.runAsync(
        () => ReflectionDraftStore(KvStore(db)).load(roomId),
      );
      expect(saved?.text, 'half a thought');
      await _open(tester);
      await settleRooms(tester);
      expect(find.text('half a thought'), findsOneWidget);
      await closeAll(tester);
    });

    testWidgets('a failed send keeps the words and retries with the same '
        'reflectionId (idempotent)', (tester) async {
      final api = FakeReflectionsApi();
      api.fail['send'] = const ApiException(
        code: 'connectionTimeout',
        isNetwork: true,
      );
      await pumpReflections(tester, rooms: FakeRoomsApi(), reflections: api);
      await _open(tester);
      await _type(tester, 'try again');
      await _tapSend(tester);
      expect(
        find.text(
          "It didn't send just now. Your words are still here: try again in "
          'a moment.',
        ),
        findsOneWidget,
      );
      expect(find.text('try again'), findsOneWidget);
      await _tapSend(tester);
      expect(api.attempts, hasLength(2));
      expect(api.attempts[0], api.attempts[1]);
      expect(api.sends, hasLength(1));
      await closeAll(tester);
    });
  });

  testWidgets('"I need help now" sits under the composer and opens the '
      'Safety Center', (tester) async {
    await pumpReflections(
      tester,
      rooms: FakeRoomsApi(),
      reflections: FakeReflectionsApi(),
    );
    await _open(tester);
    final help = find.byKey(const ValueKey('reflection-help'));
    expect(help, findsOneWidget);
    expect(find.text('I need help now'), findsOneWidget);
    await tester.ensureVisible(help);
    await tester.tap(help);
    await settleSheet(tester);
    expect(find.byType(SafetyCenterScreen), findsOneWidget);
    await closeAll(tester);
  });
}
