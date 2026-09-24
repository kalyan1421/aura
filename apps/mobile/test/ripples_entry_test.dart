import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/features/ripples/ripple_entry.dart';
import 'package:aura/src/features/ripples/ripple_models.dart';
import 'package:aura/src/features/ripples/ripples_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'ripples_fakes.dart';

/// Where Breath Ripples is entered: Home (quick-match) and a room ("Breathe
/// together" + the 20 s invite banner).
void main() {
  late AppDatabase db;
  setUp(() => db = memoryDb());
  tearDown(() => db.close());

  Future<FakeChannels> pump(
    WidgetTester tester,
    Widget child, {
    required bool ready,
    FakeRipplesApi? api,
  }) async {
    final channels = FakeChannels();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testOverrides(db: db),
          ripplesReadyProvider.overrideWithValue(ready),
          ripplesApiProvider.overrideWithValue(api ?? FakeRipplesApi()),
          rippleChannelOpenerProvider.overrideWithValue(channels.open),
        ],
        child: localized(Scaffold(body: ListView(children: [child]))),
      ),
    );
    await tester.pump();
    await tester.pump();
    return channels;
  }

  testWidgets('Home card shows only while Breath Ripples is on', (
    tester,
  ) async {
    await pump(tester, const RipplesHomeCard(), ready: true);
    expect(find.text('Breathe together'), findsOneWidget);
    expect(
      find.text('Three quiet minutes with a few others. No words, no score.'),
      findsOneWidget,
    );
    await pump(tester, const RipplesHomeCard(), ready: false);
    expect(find.byKey(const ValueKey('ripples-home-card')), findsNothing);
  });

  testWidgets(
    'room: "Breathe together" and the invite banner, which listens on '
    'the ripples:<room> topic and refetches on its hint',
    (tester) async {
      final api = FakeRipplesApi();
      final ch = await pump(
        tester,
        const RoomRippleEntry(roomId: 'room-1'),
        ready: true,
        api: api,
      );
      expect(find.byKey(const ValueKey('ripple-room-breathe')), findsOneWidget);
      expect(find.byKey(const ValueKey('ripple-invite-banner')), findsNothing);
      expect(ch.last.topic, 'ripples:room-1');

      api.invite = RippleInvite(
        inviteId: 'i1',
        fromPseudonym: 'Quiet Comet',
        humans: 2,
        capacity: 4,
        startsAtMs: DateTime.now().millisecondsSinceEpoch + 20000,
      );
      ch.last.deliver('ripple_invite', {'inviteId': 'i1'});
      await tester.pump();
      await tester.pump();
      expect(
        find.text('Quiet Comet wants to breathe together · 2/4'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('ripple-invite-join')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('a room memory offers no invite', (tester) async {
    await pump(
      tester,
      const RoomRippleEntry(roomId: 'room-1', readOnly: true),
      ready: true,
    );
    expect(find.byKey(const ValueKey('ripple-room-breathe')), findsNothing);
  });
}
