import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/net/aura_api.dart';
import 'package:aura/src/core/remote_config/remote_config.dart';
import 'package:aura/src/core/remote_config/remote_config_providers.dart';
import 'package:aura/src/core/theme/app_theme.dart';
import 'package:aura/src/features/rooms/room_guidelines.dart';
import 'package:aura/src/features/rooms/room_join_screen.dart';
import 'package:aura/src/features/rooms/room_navigation.dart';
import 'package:aura/src/features/rooms/room_offer.dart';
import 'package:aura/src/features/rooms/room_screen.dart';
import 'package:aura/src/features/rooms/rooms_home_screen.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'rooms_fakes.dart';

/// Remote flags in the rooms UI (PRD 19 REQ-ADM-12): the kill switches the
/// server enforces also hide / grey the app's entry points — the rooms kill
/// switch (`rooms_enabled` → 503 rooms_paused) and the Hindi + Hinglish pool
/// (`rooms_pool_hi` → 409 language_pool_unavailable) — one-line reads of
/// `remoteFlagsProvider`. The server still decides; these only avoid a call
/// the server would refuse.

class _FixedFlags extends RemoteFlagsNotifier {
  _FixedFlags(this.flags);

  final RemoteFlags flags;

  @override
  RemoteFlags build() => flags;
}

RemoteFlags _flags({bool rooms = true, bool hiPool = false}) => RemoteFlags({
  'rooms_enabled': FlagValue(enabled: rooms),
  'rooms_pool_hi': FlagValue(enabled: hiPool),
});

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  required FakeRoomsApi api,
  required RemoteFlags flags,
  String tag = 'en',
}) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final db = memoryDb();
  await tester.runAsync(
    () => db.setValue(roomGuidelinesKey, '$roomGuidelinesVersion'),
  );
  final locale = localeFromTag(tag);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...roomsTestOverrides(db: db, api: api, locale: tag),
        remoteFlagsProvider.overrideWith(() => _FixedFlags(flags)),
      ],
      child: MaterialApp(
        theme: buildAuraTheme(locale),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...systemLocalizationDelegates,
        ],
        home: home,
      ),
    ),
  );
  await settleIo(tester);
  await settleRooms(tester);
}

Future<void> _end(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

const _request = RoomJoinRequest(quadrant: Quadrant.rain, moodId: 'lonely');

void main() {
  testWidgets('rooms kill switch off: the check-in offer says rooms are '
      'resting, with no button and no call', (tester) async {
    final api = FakeRoomsApi();
    await _pump(
      tester,
      const Scaffold(
        body: RoomOfferButton(quadrant: Quadrant.rain, moodId: 'lonely'),
      ),
      api: api,
      flags: _flags(rooms: false),
    );
    expect(find.byKey(const ValueKey('room-offer-paused')), findsOneWidget);
    expect(
      find.text('Rooms are resting for a bit. Try again later.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('room-offer')), findsNothing);
    expect(api.calls, isEmpty);
    await _end(tester);
  });

  testWidgets('rooms kill switch off: joining says so calmly without calling '
      'the match', (tester) async {
    final api = FakeRoomsApi();
    await _pump(
      tester,
      const RoomJoinScreen(request: _request),
      api: api,
      flags: _flags(rooms: false),
    );
    expect(
      find.text('Rooms are resting for a bit. Your check-in is saved.'),
      findsOneWidget,
    );
    expect(api.matches, isEmpty);
    await _end(tester);
  });

  testWidgets('the server paused rooms before this phone heard (503 '
      'rooms_paused): the same calm words', (tester) async {
    final api = FakeRoomsApi()
      ..fail['match'] = const ApiException(code: 'rooms_paused', status: 503);
    await _pump(
      tester,
      const RoomJoinScreen(request: _request),
      api: api,
      flags: _flags(),
    );
    expect(api.matches, hasLength(1));
    expect(
      find.text('Rooms are resting for a bit. Your check-in is saved.'),
      findsOneWidget,
    );
    await _end(tester);
  });

  testWidgets('rooms home shows the paused note and no join offer while the '
      'switch is off', (tester) async {
    await _pump(
      tester,
      const RoomsHomeScreen(),
      api: FakeRoomsApi(),
      flags: _flags(rooms: false),
    );
    expect(find.byKey(const ValueKey('rooms-paused')), findsOneWidget);
    expect(find.byKey(const ValueKey('rooms-check-in')), findsNothing);
    await _end(tester);
  });

  testWidgets('rooms home offers a room check-in while rooms are on', (
    tester,
  ) async {
    await _pump(
      tester,
      const RoomsHomeScreen(),
      api: FakeRoomsApi(),
      flags: _flags(),
    );
    expect(find.byKey(const ValueKey('rooms-paused')), findsNothing);
    expect(find.byKey(const ValueKey('rooms-check-in')), findsOneWidget);
    await _end(tester);
  });

  testWidgets('Hindi + Hinglish pool closed (flag): the English-room choice '
      'right away, no refused call; "Join English room" matches with the '
      'fallback', (tester) async {
    final api = FakeRoomsApi();
    await _pump(
      tester,
      const RoomJoinScreen(request: _request),
      api: api,
      flags: _flags(),
      tag: 'hi-Latn',
    );
    expect(find.byKey(const ValueKey('rooms-pool-choice')), findsOneWidget);
    expect(api.matches, isEmpty);
    await tester.tap(find.byKey(const ValueKey('rooms-pool-english')));
    await settleSheet(tester);
    await settleRooms(tester);
    expect(api.matches.single.allowPoolFallback, isTrue);
    expect(find.byType(RoomScreen), findsOneWidget);
    await _end(tester);
  });

  testWidgets('Hindi + Hinglish pool open (flag): the match goes straight to '
      'the server; English is unaffected by the pool flag', (tester) async {
    final hi = FakeRoomsApi();
    await _pump(
      tester,
      const RoomJoinScreen(request: _request),
      api: hi,
      flags: _flags(hiPool: true),
      tag: 'hi',
    );
    expect(hi.matches.single.allowPoolFallback, isFalse);
    await _end(tester);

    final en = FakeRoomsApi();
    await _pump(
      tester,
      const RoomJoinScreen(request: _request),
      api: en,
      flags: _flags(),
    );
    expect(en.matches, hasLength(1));
    await _end(tester);
  });
}
