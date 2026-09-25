import 'dart:convert';

import 'package:aura/src/core/net/aura_api.dart' show ApiException;
import 'package:aura/src/features/auth/auth_repository.dart';
import 'package:aura/src/features/support/grievance_api.dart';
import 'package:aura/src/features/support/grievance_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_social_fakes.dart';
import 'helpers.dart';

/// The Grievance Officer's in-app form (PRD F9 "ticketed form,
/// auto-acknowledged"; REQ-SAFE-11): a ticket id at once, the resolve-by
/// date, the appeal route; failures keep every word; nothing is sent without
/// an address and a real description.

class _FakeApi implements GrievanceApi {
  Object? fail;
  final List<Map<String, Object?>> sent = [];

  @override
  Future<GrievanceReceipt> submit({
    required GrievanceCategory category,
    required String email,
    required String description,
    String? name,
    String? where,
    String? locale,
  }) async {
    sent.add({
      'category': category,
      'email': email,
      'description': description,
      'name': name,
      'where': where,
      'locale': locale,
    });
    final f = fail;
    if (f != null) throw f;
    return GrievanceReceipt(
      ticket: 'GRV-7K2M9Q4D',
      resolveBy: DateTime(2026, 10, 15, 10),
    );
  }
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body);

  final int status;
  final Object body;
  RequestOptions? last;
  Object? lastBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    lastBody = options.data;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _pump(
  WidgetTester tester, {
  GrievanceApi? api,
  AuthUser? user,
  GrievanceCategory category = GrievanceCategory.general,
}) async {
  _phone(tester);
  final auth = FakeSocialAuth()..user = user;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...testOverrides(db: memoryDb(), auth: auth),
        grievanceApiProvider.overrideWithValue(api),
      ],
      child: localized(GrievanceFormScreen(initialCategory: category)),
    ),
  );
  await tester.pump();
}

/// Scrolls the (lazy) form until [key] is built and on screen.
Future<void> _reveal(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(
    find.byKey(ValueKey(key)),
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

Future<void> _enter(WidgetTester tester, String key, String text) async {
  final f = find.byKey(ValueKey(key));
  await _reveal(tester, key);
  await tester.enterText(f, text);
  await tester.pump();
}

Future<void> _send(WidgetTester tester) async {
  final f = find.byKey(const ValueKey('grievance-send'));
  await _reveal(tester, 'grievance-send');
  await tester.tap(f);
  await tester.pump();
  await tester.pump();
}

Future<bool> _sendEnabledAsync(WidgetTester tester) async {
  await _reveal(tester, 'grievance-send');
  return _sendEnabled(tester);
}

bool _sendEnabled(WidgetTester tester) =>
    tester
        .widget<FilledButton>(find.byKey(const ValueKey('grievance-send')))
        .onPressed !=
    null;

void main() {
  testWidgets('send: ticket id, resolve-by date, the appeal route', (
    tester,
  ) async {
    final api = _FakeApi();
    await _pump(
      tester,
      api: api,
      user: const AuthUser(id: 'u1', email: 'riya@example.com'),
    );
    // Pre-filled with the account's address.
    await _reveal(tester, 'grievance-email');
    expect(find.text('riya@example.com'), findsOneWidget);
    // Nothing to send until there is a real description.
    expect(await _sendEnabledAsync(tester), isFalse);
    await _enter(tester, 'grievance-description', 'too short');
    expect(await _sendEnabledAsync(tester), isFalse);
    await _enter(
      tester,
      'grievance-description',
      'Someone kept sending the same gesture after I muted them.',
    );
    await _enter(tester, 'grievance-where', 'A Storm room, last night');
    expect(await _sendEnabledAsync(tester), isTrue);
    await _send(tester);

    expect(api.sent, hasLength(1));
    expect(api.sent.single['category'], GrievanceCategory.general);
    expect(api.sent.single['email'], 'riya@example.com');
    expect(api.sent.single['where'], 'A Storm room, last night');
    expect(api.sent.single['locale'], 'en');
    expect(find.byKey(const ValueKey('grievance-receipt')), findsOneWidget);
    expect(find.text('Your ticket: GRV-7K2M9Q4D'), findsOneWidget);
    expect(find.textContaining('15 Oct 2026'), findsOneWidget);
    expect(find.textContaining('riya@example.com'), findsOneWidget);
    expect(find.textContaining('gac.gov.in'), findsOneWidget);
  });

  testWidgets('an appeal starts on "Ask for a review of a decision"', (
    tester,
  ) async {
    final api = _FakeApi();
    await _pump(tester, api: api, category: GrievanceCategory.moderationAppeal);
    final radio = tester.widget<RadioGroup<GrievanceCategory>>(
      find.byType(RadioGroup<GrievanceCategory>),
    );
    expect(radio.groupValue, GrievanceCategory.moderationAppeal);
    // Signed out: no address yet, so nothing is sent.
    await _enter(
      tester,
      'grievance-description',
      'Please look at the decision about my account again.',
    );
    expect(await _sendEnabledAsync(tester), isFalse);
    await _enter(tester, 'grievance-email', 'me@example.com');
    expect(await _sendEnabledAsync(tester), isTrue);
    await _send(tester);
    expect(api.sent.single['category'], GrievanceCategory.moderationAppeal);
  });

  testWidgets('failures keep every word and say so calmly', (tester) async {
    final api = _FakeApi()
      ..fail = const ApiException(code: 'connectionError', isNetwork: true);
    await _pump(
      tester,
      api: api,
      user: const AuthUser(id: 'u1', email: 'riya@example.com'),
    );
    const words = 'A reflection in my room shared a phone number.';
    await _enter(tester, 'grievance-description', words);
    await _send(tester);
    expect(
      find.text('This needs a connection. Your words are still here.'),
      findsOneWidget,
    );
    expect(find.text(words), findsOneWidget);
    expect(find.byKey(const ValueKey('grievance-receipt')), findsNothing);

    api.fail = const ApiException(code: 'rate_limited', status: 429);
    await _send(tester);
    expect(find.textContaining('last hour'), findsOneWidget);
    expect(find.text(words), findsOneWidget);

    api.fail = null;
    await _send(tester);
    expect(find.byKey(const ValueKey('grievance-receipt')), findsOneWidget);
  });

  testWidgets('a build without an API says so and sends nothing', (
    tester,
  ) async {
    await _pump(
      tester,
      user: const AuthUser(id: 'u1', email: 'a@b.co'),
    );
    await _enter(
      tester,
      'grievance-description',
      'Something I would like the officer to know.',
    );
    expect(find.byKey(const ValueKey('grievance-no-api')), findsOneWidget);
    expect(await _sendEnabledAsync(tester), isFalse);
  });

  test('HttpGrievanceApi posts the public form, channel in_app', () async {
    final adapter = _Adapter(201, {
      'ticket': 'GRV-ABCDEFGH',
      'category': 'moderation_appeal',
      'receivedAt': '2026-10-08T10:00:00.000Z',
      'acknowledgedAt': '2026-10-08T10:00:00.000Z',
      'resolveBy': '2026-10-15T10:00:00.000Z',
      'officer': {'name': 'AK', 'email': null, 'address': null},
      'appeal': 'GAC',
    });
    final api = HttpGrievanceApi(
      baseUrl: 'http://test',
      dio: Dio(
        BaseOptions(
          baseUrl: 'http://test',
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
        ),
      )..httpClientAdapter = adapter,
    );
    final r = await api.submit(
      category: GrievanceCategory.moderationAppeal,
      email: 'me@example.com',
      description: 'Please review the decision.',
      name: '',
      where: '',
      locale: 'te-Latn',
    );
    expect(r.ticket, 'GRV-ABCDEFGH');
    expect(r.resolveBy.toUtc(), DateTime.utc(2026, 10, 15, 10));
    expect(adapter.last!.path, '/v1/grievances');
    expect(adapter.last!.method, 'POST');
    // Public route: no Authorization header; empty optionals are left out.
    expect(adapter.last!.headers['Authorization'], isNull);
    expect(adapter.lastBody, {
      'category': 'moderation_appeal',
      'email': 'me@example.com',
      'description': 'Please review the decision.',
      'locale': 'te-Latn',
      'channel': 'in_app',
    });
  });

  test('HttpGrievanceApi maps a refusal to its code', () async {
    final api = HttpGrievanceApi(
      baseUrl: 'http://test',
      dio: Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = _Adapter(429, {'code': 'rate_limited'}),
    );
    await expectLater(
      api.submit(
        category: GrievanceCategory.general,
        email: 'me@example.com',
        description: 'Something happened here.',
      ),
      throwsA(
        isA<ApiException>()
            .having((e) => e.status, 'status', 429)
            .having((e) => e.code, 'code', 'rate_limited'),
      ),
    );
  });
}
