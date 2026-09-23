import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/net/api_models.dart';
import 'package:aura/src/core/net/aura_api.dart';
import 'package:aura/src/features/auth/age_signals.dart';
import 'package:aura/src/features/profile/profile_service.dart';
import 'package:aura/src/features/progress/progress_repository.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Server-side under-18 from platform age signals (F8 REQ-ACC-04 /
/// REQ-ACC-10; contracts/api/v1.md "Onboarding / profile"): an "under 18"
/// signal is noted and goes once, as `ageSignal: "under18"`, with the next
/// `POST /v1/profile`, so the server's invisible protections apply even with
/// an adult DOB. Nothing is shown; the band is cleared once the server took
/// it, so later re-sends never restart the server's window.

/// Records every profile body; answers with [answer] (or throws [fail]).
class _Api extends AuraApi {
  _Api() : super(baseUrl: 'http://test', accessToken: () async => 'jwt');

  final List<Map<String, dynamic>> bodies = [];
  ProfileResult answer = const ProfileSaved(null);
  ApiException? fail;

  /// Runs while the request is "in flight".
  Future<void> Function()? during;

  @override
  Future<ProfileResult> postProfile(ProfileRequest body) async {
    bodies.add(body.toJson());
    await during?.call();
    final f = fail;
    if (f != null) throw f;
    return answer;
  }
}

void main() {
  late AppDatabase db;
  late KvStore kv;
  late ProfileService profile;
  late _Api api;

  setUp(() async {
    db = memoryDb();
    kv = KvStore(db);
    profile = ProfileService(
      kv: kv,
      timezone: () => 'Asia/Kolkata',
      progress: ProgressRepository(db, kv),
      country: () => 'IN',
    );
    api = _Api();
    await profile.queue(birthDate: const LocalDay(1996, 4, 17)); // an adult
  });
  tearDown(() => db.close());

  test('the request carries ageSignal only when set (older builds and adults '
      'send exactly what they sent before)', () {
    const plain = ProfileRequest(
      birthDate: '1996-04-17',
      uiLocale: 'en',
      timezone: 'Asia/Kolkata',
    );
    expect(plain.toJson().containsKey('ageSignal'), isFalse);
    expect(
      plain.copyWith(ageSignal: 'under18').toJson()['ageSignal'],
      'under18',
    );
    expect(AgeBand.fromWire('under18'), AgeBand.under18);
    expect(AgeBand.fromWire('adult'), isNull);
    expect(AgeBand.fromWire(null), isNull);
  });

  test('an under-18 band goes once with the next profile POST, then never '
      'again', () async {
    expect(await profile.flush(api), ProfileFlush.saved);
    expect(api.bodies.single.containsKey('ageSignal'), isFalse);

    await profile.noteAgeSignal(AgeBand.under18);
    expect(
      await profile.hasPending(),
      isTrue,
    ); // re-sent even if already on the server
    expect(await profile.flush(api), ProfileFlush.saved);
    expect(api.bodies.last['ageSignal'], 'under18');
    expect(api.bodies.last['birthDate'], '1996-04-17'); // the DOB is unchanged
    expect(await kv.get(ProfileService.ageSignalKey), isNull);

    // A later re-send (the phone's zone changed) carries no band.
    await profile.markDirty();
    await profile.flush(api);
    expect(api.bodies.last.containsKey('ageSignal'), isFalse);
  });

  test('a refused POST keeps the band for the retry; birth_date_locked counts '
      'as delivered (the server recorded it)', () async {
    // A fresh service per step: no refusal backoff carried over.
    ProfileService fresh() => ProfileService(
      kv: kv,
      timezone: () => 'Asia/Kolkata',
      progress: ProgressRepository(db, kv),
      country: () => 'IN',
    );
    await profile.noteAgeSignal(AgeBand.under18);
    api.fail = const ApiException(code: 'invalid_request', status: 400);
    expect(await profile.flush(api), ProfileFlush.failed);
    expect(await kv.get(ProfileService.ageSignalKey), 'under18');

    api.fail = const ApiException(code: 'http_503', status: 503);
    expect(await fresh().flush(api), ProfileFlush.retryLater);
    expect(await kv.get(ProfileService.ageSignalKey), 'under18');

    api.fail = const ApiException(code: 'birth_date_locked', status: 409);
    expect(await fresh().flush(api), ProfileFlush.failed);
    expect(api.bodies.map((b) => b['ageSignal']), everyElement('under18'));
    expect(await kv.get(ProfileService.ageSignalKey), isNull);
  });

  test('under 13 from the server clears the band with the DOB', () async {
    await profile.noteAgeSignal(AgeBand.under18);
    api.answer = const ProfileUnder13();
    expect(await profile.flush(api), ProfileFlush.under13);
    expect(await kv.get(ProfileService.ageSignalKey), isNull);
    expect(await kv.get(KvKeys.birthDate), isNull);
  });

  test(
    'a band noted while a POST is in flight goes with the next one',
    () async {
      api.during = () => profile.noteAgeSignal(AgeBand.under18);
      expect(await profile.flush(api), ProfileFlush.saved);
      expect(api.bodies.single.containsKey('ageSignal'), isFalse);
      expect(await profile.hasPending(), isTrue);
      api.during = null;
      await profile.flush(api);
      expect(api.bodies.last['ageSignal'], 'under18');
      expect(await profile.hasPending(), isFalse);
    },
  );

  group('AgeSignalPolicy hands the band to the profile', () {
    Future<(AgeSignalOutcome, int)> run(AgeSignal signal) async {
      var minors = 0;
      final policy = AgeSignalPolicy(
        kv: kv,
        blockUnder13: () async {},
        today: () => const LocalDay(2026, 10, 8),
        onMinor: () async {
          minors++;
          await profile.noteAgeSignal(AgeBand.under18);
        },
      );
      return (await policy.apply(signal), minors);
    }

    test('under 18 → noted for the server too (and the local flag)', () async {
      final (outcome, minors) = await run(
        const AgeSignal(lower: 16, upper: 17),
      );
      expect(outcome, AgeSignalOutcome.minor);
      expect(minors, 1);
      expect(await kv.get(ProfileService.ageSignalKey), 'under18');
      expect(await kv.get(KvKeys.minorUntil), isNotNull);
    });

    test('under 13, adult or no signal → nothing for the server', () async {
      for (final s in [
        const AgeSignal(upper: 12),
        const AgeSignal(lower: 18),
        AgeSignal.none,
      ]) {
        final (_, minors) = await run(s);
        expect(minors, 0);
      }
      expect(await kv.get(ProfileService.ageSignalKey), isNull);
    });
  });
}
