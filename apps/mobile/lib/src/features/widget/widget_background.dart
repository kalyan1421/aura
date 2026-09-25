import 'dart:async';
import 'dart:convert';

import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/db/connection.dart';
import '../../core/db/database.dart';
import '../../core/db/kv_store.dart';
import '../../core/env/env.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/providers.dart';
import '../../core/security/secure_session_storage.dart';
import '../../core/security/secure_store.dart';
import '../../core/time/clock.dart';
import '../../core/time/device_timezone.dart';
import '../onboarding/age_gate.dart';
import '../onboarding/gate_controller.dart';
import 'widget_bridge.dart';
import 'widget_ingest.dart';
import 'widget_prefs.dart';

/// Widget check-ins reach the server without opening the app (F11 "Data
/// path": "The app imports it into Drift on next launch **or background
/// refresh**, then syncs"; PRD 16-offline: the outbox also drains "via
/// WorkManager / BGTaskScheduler").
///
/// The OS starts a headless Flutter engine at [widgetBackgroundMain]:
///
/// * **Android:** `WidgetSyncWorker` (WorkManager), enqueued by the widget
///   after each save; needs a network and a battery that isn't low.
/// * **iOS:** `BGAppRefreshTask` `com.akvega.aura.widget-sync`, requested
///   whenever the app goes to the background while a widget is installed
///   (a widget extension can't schedule one); iOS decides when it runs.
///
/// Both check natively that the widget holds unsent check-ins before
/// starting Flutter, and hand the work to the app's own engine when it is
/// alive (then nothing runs twice). The run itself ([WidgetBackgroundSync])
/// imports through the same [WidgetIngestor] as an app open (idempotent by
/// client id, REQ-WID-02) and pushes the outbox through the same sync service.
/// It never runs signed out, before onboarding or while the under-13 lock
/// holds, never creates a database or key, and shows no UI.
///
/// The mood-trigger capsule step still waits for the next app open (PRD 12
/// "after a widget check-in it waits for the next app open"): imported ids
/// are kept in [WidgetKvKeys.followUps] and `WidgetBridge` queues them then.
const String widgetBackgroundChannelName = 'com.akvega.aura/widget_background';

/// How long a background run may spend pushing (iOS gives an app-refresh
/// task about 30 s in all).
const Duration widgetBackgroundSyncBudget = Duration(seconds: 20);

/// What a background run did (reported to the native side, never logged
/// with any content).
enum WidgetBackgroundOutcome {
  /// Signed out, not onboarded, under-13 lock, no config or no database.
  skipped,

  /// Nothing new from the widget; the outbox was pushed if it had items.
  nothingImported,

  /// At least one widget check-in was imported (and pushed when online).
  imported,

  failed,
}

/// One background run over an already-built provider graph (the headless
/// entrypoint builds it like `main()`; tests build it with fakes).
class WidgetBackgroundSync {
  WidgetBackgroundSync(this._container);

  final ProviderContainer _container;

  Future<WidgetBackgroundOutcome> run({
    Duration syncBudget = widgetBackgroundSyncBudget,
  }) async {
    final gate = _container.read(gateControllerProvider);
    if (!gate.onboarded || gate.isBlocked) {
      return WidgetBackgroundOutcome.skipped;
    }
    final auth = _container.read(authRepositoryProvider);
    if (!auth.isAvailable || auth.currentUser == null) {
      return WidgetBackgroundOutcome.skipped;
    }
    final kv = _container.read(kvStoreProvider);
    // No owner token: the app never published the widget as ready for this
    // account, so no widget record can belong to it. Never mint one here.
    final owner = await kv.get(WidgetKvKeys.owner);
    if (owner == null || owner.isEmpty) return WidgetBackgroundOutcome.skipped;

    final imported = await _container
        .read(widgetIngestorProvider)
        .ingest(owner: owner, background: true);
    if (imported.isNotEmpty) {
      await rememberWidgetFollowUps(kv, [for (final c in imported) c.id]);
    }
    if (await _container.read(outboxRepositoryProvider).count() > 0) {
      await _container.read(syncControllerProvider).drain(timeout: syncBudget);
    }
    return imported.isEmpty
        ? WidgetBackgroundOutcome.nothingImported
        : WidgetBackgroundOutcome.imported;
  }
}

/// At most this many ids wait for the capsule step (a year of widget use
/// between app opens would be absurd; the oldest go first).
const int _maxFollowUps = 50;

/// Adds [ids] to the check-ins waiting for the capsule step at the next app
/// open.
Future<void> rememberWidgetFollowUps(KvStore kv, List<String> ids) async {
  final list = [...await _followUpIds(kv)];
  for (final id in ids) {
    if (!list.contains(id)) list.add(id);
  }
  final kept = list.length > _maxFollowUps
      ? list.sublist(list.length - _maxFollowUps)
      : list;
  await kv.set(WidgetKvKeys.followUps, jsonEncode(kept));
}

/// Takes the check-ins imported in the background (oldest first) with their
/// moods, and forgets them. A deleted or unknown check-in is dropped.
Future<List<ImportedWidgetCheckIn>> takeWidgetFollowUps(
  KvStore kv,
  AppDatabase db,
) async {
  final ids = await _followUpIds(kv);
  if (ids.isEmpty) return const [];
  await kv.set(WidgetKvKeys.followUps, null);
  final rows = await (db.select(
    db.checkIns,
  )..where((t) => t.id.isIn(ids) & t.deletedAt.isNull())).get();
  final byId = {for (final r in rows) r.id: r};
  return [
    for (final id in ids)
      if (byId[id] case final row?)
        if (moodById(row.moodId) case final mood?)
          ImportedWidgetCheckIn(id: id, mood: mood),
  ];
}

Future<List<String>> _followUpIds(KvStore kv) async {
  final raw = await kv.get(WidgetKvKeys.followUps);
  if (raw == null) return const [];
  try {
    final list = jsonDecode(raw);
    return list is List
        ? [
            for (final v in list)
              if (v is String) v,
          ]
        : const [];
  } on FormatException {
    return const [];
  }
}

/// The headless entrypoint (`main.dart` `widgetBackgroundMain`). Builds the
/// same provider graph as `main()` from what is already on the phone, runs
/// [WidgetBackgroundSync] and tells the native side it is done. Never throws.
Future<void> runWidgetBackgroundEntry() async {
  WidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(widgetBackgroundChannelName);
  var outcome = WidgetBackgroundOutcome.failed;
  AppDatabase? db;
  ProviderContainer? container;
  try {
    ensureTimeZonesLoaded();
    // Reads only: the app itself moves key material (MASVS F-3).
    final secure = DeviceBoundKeyStore.platform(migrate: false);
    db = Env.hasSupabase && Env.hasApi
        ? await openExistingAppDatabase(secure)
        : null;
    if (db == null) {
      outcome = WidgetBackgroundOutcome.skipped;
    } else {
      final kv = KvStore(db);
      final gate = await loadGateState(
        kv,
        AgeGate(secure, const Clock(), platformDeviceLockMirror()),
      );
      await Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: Env.supabaseKey,
        authOptions: secureAuthOptions(supabaseUrl: Env.supabaseUrl, kv: kv),
      );
      final timezone = await resolveDeviceTimezone();
      final locale =
          await kv.get(KvKeys.locale) ??
          defaultLocaleTag(WidgetsBinding.instance.platformDispatcher.locales);
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          secureStoreProvider.overrideWithValue(secure),
          initialTimezoneProvider.overrideWithValue(timezone),
          initialGateProvider.overrideWithValue(gate),
          initialLocaleTagProvider.overrideWithValue(locale),
        ],
      );
      outcome = await WidgetBackgroundSync(container).run();
    }
  } catch (e) {
    // Type only: nothing personal reaches a log.
    debugPrint('widget-bg: ${e.runtimeType}');
    outcome = WidgetBackgroundOutcome.failed;
  } finally {
    container?.dispose();
    try {
      await db?.close();
    } catch (_) {}
  }
  try {
    await channel.invokeMethod<void>('done', outcome.name);
  } catch (_) {
    // The native side times out on its own.
  }
}
