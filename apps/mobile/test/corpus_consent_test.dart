import 'package:aura/src/core/net/aura_api.dart' show ApiException;
import 'package:aura/src/features/settings/corpus_consent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// REQ-SAFE-16: the Settings opt-out for the de-identified moderation corpus
/// shows the server's answer and changes it there; offline nothing changes.

class _FakeApi implements CorpusConsentApi {
  _FakeApi(this.value);

  bool value;
  bool offline = false;
  final List<bool> sets = [];

  @override
  Future<bool> get() async {
    if (offline) throw const ApiException(code: 'x', isNetwork: true);
    return value;
  }

  @override
  Future<bool> set(bool enabled) async {
    if (offline) throw const ApiException(code: 'x', isNetwork: true);
    sets.add(enabled);
    return value = enabled;
  }
}

Future<void> _pump(WidgetTester tester, CorpusConsentApi? api) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...testOverrides(db: memoryDb()),
        corpusConsentApiProvider.overrideWithValue(api),
      ],
      child: localized(const Scaffold(body: CorpusConsentTile())),
    ),
  );
  await tester.pump();
  await tester.pump();
}

bool _value(WidgetTester tester) => tester
    .widget<SwitchListTile>(find.byKey(const ValueKey('set-corpus')))
    .value;

void main() {
  testWidgets('shows the server value (on by default) and turns it off', (
    tester,
  ) async {
    final api = _FakeApi(true);
    await _pump(tester, api);
    expect(
      find.text('Use my reflections to improve safety filters'),
      findsOneWidget,
    );
    expect(_value(tester), isTrue);
    await tester.tap(find.byKey(const ValueKey('set-corpus')));
    await tester.pump();
    await tester.pump();
    expect(api.sets, [false]);
    expect(_value(tester), isFalse);
  });

  testWidgets('offline: disabled, says nothing changed', (tester) async {
    final api = _FakeApi(true)..offline = true;
    await _pump(tester, api);
    final tile = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('set-corpus')),
    );
    expect(tile.onChanged, isNull);
    expect(find.byKey(const ValueKey('set-corpus-failed')), findsOneWidget);
  });

  testWidgets('no API or signed out: nothing shows', (tester) async {
    await _pump(tester, null);
    expect(find.byKey(const ValueKey('set-corpus')), findsNothing);
  });
}
