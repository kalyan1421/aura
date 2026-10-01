import 'dart:convert';

import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/db/database.dart';
import '../../core/ids/ids.dart';
import '../../core/providers.dart';
import '../../core/sync/outbox_repository.dart';
import '../../core/time/clock.dart';
import '../progress/progress_view.dart';
import 'loom_shape.dart';

part 'constellation_repository.g.dart';

/// A constellation kept in the Reflection sky (U07, RULES.md section 14).
@immutable
class KeptConstellation {
  const KeptConstellation({
    required this.id,
    required this.shape,
    required this.meaning,
    required this.localDay,
    required this.deviceTs,
  });
  final String id;
  final LoomShape shape;
  final ConstellationMeaning? meaning;
  final LocalDay localDay;
  final DateTime deviceTs;

  @override
  bool operator ==(Object other) =>
      other is KeptConstellation &&
      other.id == id &&
      other.shape == shape &&
      other.meaning == meaning;

  @override
  int get hashCode => Object.hash(id, shape, meaning);
}

/// Keeping and letting go of Orbit Loom constellations. Local first: a kept
/// constellation is on this phone at once and waits in the outbox like every
/// other write (the app never writes personal tables directly). Cosmetic:
/// nothing here touches Starlight, streaks or keepsakes.
class ConstellationRepository {
  ConstellationRepository(
    this._db,
    this._outbox,
    this._time,
    this._ids, {
    this._notifySync,
  });

  final AppDatabase _db;
  final OutboxRepository _outbox;
  final TimeContext _time;
  final Ids _ids;
  final void Function()? _notifySync;

  /// Keeps [shape] (with an optional [meaning]) and returns its id, or `null`
  /// when it cannot be kept: the rule refuses it, or five were kept today.
  Future<String?> keep(LoomShape shape, {ConstellationMeaning? meaning}) async {
    final stars = shape.wireStars;
    final links = shape.wireLinks;
    if (constellationProblem(
          stars: stars,
          links: links,
          meaning: meaning?.key,
        ) !=
        null) {
      return null;
    }
    final now = _time.now();
    final day = _time.dayOf(now);
    final id = _ids.v7();
    final kept = await _db.transaction(() async {
      if (await _keptOn(day) >= maxLoomConstellationsPerDay) return false;
      await _db
          .into(_db.loomConstellations)
          .insert(
            LoomConstellationsCompanion.insert(
              id: id,
              stars: Value(jsonEncode(stars)),
              links: Value(jsonEncode(links)),
              meaning: Value(meaning?.key),
              localDay: day.toIso(),
              deviceTs: now,
              tz: Value(_time.timezone),
            ),
          );
      await _outbox.enqueue(
        entity: Entities.loomConstellation,
        op: Ops.upsert,
        entityId: id,
        deviceTs: now,
        localDay: day,
        tz: _time.timezone,
        payload: {
          'id': id,
          'stars': stars,
          'links': links,
          'meaning': meaning?.key,
        },
      );
      return true;
    });
    if (!kept) return null;
    _notifySync?.call();
    return id;
  }

  /// Lets [id] go: the shape is erased here at once, and on every device
  /// once the delete is sent.
  Future<void> letGo(String id) async {
    final row = await (_db.select(
      _db.loomConstellations,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null || row.deletedAt != null) return;
    final now = _time.now();
    await _db.transaction(() async {
      await (_db.update(
        _db.loomConstellations,
      )..where((t) => t.id.equals(id))).write(
        LoomConstellationsCompanion(
          stars: const Value(null),
          links: const Value(null),
          meaning: const Value(null),
          deletedAt: Value(now),
        ),
      );
      await _outbox.enqueue(
        entity: Entities.loomConstellation,
        op: Ops.delete,
        entityId: id,
        deviceTs: now,
        localDay: _time.dayOf(now),
        tz: _time.timezone,
        payload: {'id': id},
      );
    });
    _notifySync?.call();
  }

  /// The server refused a keep (`too_many_constellations` from another
  /// phone the same day, or a shape it will not hold): it holds nothing, so
  /// neither does this phone. Queues nothing.
  Future<void> dropRejected(String id) =>
      (_db.delete(_db.loomConstellations)..where((t) => t.id.equals(id))).go();

  /// Kept constellations, newest first.
  Stream<List<KeptConstellation>> watchKept() =>
      (_db.select(_db.loomConstellations)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.deviceTs)]))
          .watch()
          .map((rows) => [for (final r in rows) ?readKept(r)]);

  /// How many were kept on [day] (the per-day limit).
  Stream<int> watchKeptOn(LocalDay day) {
    final count = _db.loomConstellations.id.count();
    return (_db.selectOnly(_db.loomConstellations)
          ..addColumns([count])
          ..where(
            _db.loomConstellations.localDay.equals(day.toIso()) &
                _db.loomConstellations.deletedAt.isNull(),
          ))
        .map((r) => r.read(count) ?? 0)
        .watchSingle();
  }

  Future<int> _keptOn(LocalDay day) async {
    final count = _db.loomConstellations.id.count();
    final r =
        await (_db.selectOnly(_db.loomConstellations)
              ..addColumns([count])
              ..where(
                _db.loomConstellations.localDay.equals(day.toIso()) &
                    _db.loomConstellations.deletedAt.isNull(),
              ))
            .getSingle();
    return r.read(count) ?? 0;
  }

  /// A stored row as a kept constellation, or `null` when it is let go or
  /// unreadable (a shape this version cannot show is left out, never shown
  /// broken).
  static KeptConstellation? readKept(LoomConstellationRow r) {
    if (r.deletedAt != null || r.stars == null || r.links == null) return null;
    try {
      final stars = [
        for (final p in jsonDecode(r.stars!) as List<dynamic>)
          LoomStar(
            ((p as List<dynamic>)[0] as num).toDouble(),
            (p[1] as num).toDouble(),
          ),
      ];
      final links = [
        for (final l in jsonDecode(r.links!) as List<dynamic>)
          LoomLink(
            ((l as List<dynamic>)[0] as num).toInt(),
            (l[1] as num).toInt(),
          ),
      ];
      return KeptConstellation(
        id: r.id,
        shape: LoomShape(stars: stars, links: links),
        meaning: ConstellationMeaning.fromKey(r.meaning),
        localDay: LocalDay.parse(r.localDay),
        deviceTs: r.deviceTs,
      );
    } on Object {
      return null;
    }
  }
}

@Riverpod(keepAlive: true)
ConstellationRepository constellationRepository(Ref ref) =>
    ConstellationRepository(
      ref.watch(appDatabaseProvider),
      ref.watch(outboxRepositoryProvider),
      ref.watch(timeContextProvider),
      ref.watch(idsProvider),
      notifySync: () => ref.read(syncControllerProvider).notifyLocalWrite(),
    );

/// The constellations kept in the Reflection sky, newest first.
@riverpod
Stream<List<KeptConstellation>> keptConstellations(Ref ref) =>
    ref.watch(constellationRepositoryProvider).watchKept();

/// How many were kept today (Orbit Loom's per-day limit).
@riverpod
Stream<int> keptToday(Ref ref) {
  final today = ref.watch(progressViewProvider.select((v) => v.today));
  return ref.watch(constellationRepositoryProvider).watchKeptOn(today);
}
