import 'dart:convert';

import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Rect;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/db/database.dart';
import '../../core/net/aura_api.dart';
import '../../core/providers.dart';
import '../capsules/capsule_providers.dart';
import '../capsules/capsule_repository.dart';

/// F8 REQ-ACC-12 "Data export … JSON + readable HTML" (PRD 06c F8), plus the
/// check-in CSV Insights promises for free (`[LEGAL]`, PRD 06a F10).
///
/// **Made on the phone** (an interpretation recorded in docs/status/pending.md):
/// private text is only ever decrypted here (DS-1), so the check-ins and
/// notes, habits and capsules come from this phone's encrypted database; what
/// only the server holds (profile incl. DOB, purchases, Plus, Stardust,
/// keepsakes, consents, own reflections…) comes from `GET /v1/account/export`.
/// The files go to the OS share sheet, and nowhere else: no upload, no link.
///
/// Contents rules: own records only (never another person), no moderation
/// detail, sealed capsules stay sealed (title and unlock only), voice notes
/// and photos stay in the app (listed, not attached). Deleted check-ins and
/// capsules are left out.
@immutable
class ExportBundle {
  const ExportBundle({
    required this.exportedAt,
    required this.localeTag,
    required this.checkIns,
    required this.habits,
    required this.habitLogs,
    required this.capsules,
    this.server,
  });

  final DateTime exportedAt;
  final String localeTag;
  final List<Map<String, Object?>> checkIns;
  final List<Map<String, Object?>> habits;
  final List<Map<String, Object?>> habitLogs;
  final List<Map<String, Object?>> capsules;

  /// `GET /v1/account/export`, or `null` for a phone-only copy.
  final Map<String, dynamic>? server;

  Map<String, Object?> toJson() => {
    'format': 'aura.export.v1',
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'language': localeTag,
    'checkIns': checkIns,
    'habits': habits,
    'habitLogs': habitLogs,
    'capsules': capsules,
    'account': ?server,
  };
}

/// Localized headings for the readable copy (from AppLocalizations).
@immutable
class ExportLabels {
  const ExportLabels({
    required this.title,
    required this.exported,
    required this.checkIns,
    required this.habits,
    required this.capsules,
    required this.account,
    required this.reflections,
    required this.sanctuary,
    required this.sealed,
    required this.voiceNote,
    required this.nothing,
    required this.commitmentSince,
    required this.pausedUntil,
  });

  final String title;

  /// Already formatted with the date.
  final String exported;
  final String checkIns;
  final String habits;
  final String capsules;
  final String account;
  final String reflections;
  final String sanctuary;
  final String sealed;
  final String voiceNote;
  final String nothing;

  /// "Commitment since {day}" / "paused until {day}" for a habit's own opt-in
  /// (W02); each takes an ISO day.
  final String Function(String day) commitmentSince;
  final String Function(String day) pausedUntil;
}

// ---- collecting ---------------------------------------------------------------

String _day(DateTime d) => d.toUtc().toIso8601String();

/// Reads this phone's own records. [capsules] opens only capsules that were
/// opened (sealed ones stay sealed).
Future<ExportBundle> collectExport({
  required AppDatabase db,
  required CapsuleRepository capsules,
  required String localeTag,
  required DateTime now,
  Map<String, dynamic>? server,
}) async {
  final checkIns =
      await (db.select(db.checkIns)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.deviceTs)]))
          .get();
  final habits = await (db.select(
    db.habits,
  )..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();
  final logs =
      await (db.select(db.habitLogs)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.localDay)]))
          .get();
  final capsuleRows =
      (await capsules.allRows()).where((r) => r.deletedAt == null).toList()
        ..sort((a, b) => a.sealedAt.compareTo(b.sealedAt));

  final habitNames = <String, String>{
    for (final h in habits)
      h.id:
          h.name ??
          (presetHabits
                  .where((p) => p.key == h.presetKey)
                  .firstOrNull
                  ?.nameFor(localeTag) ??
              h.presetKey ??
              ''),
  };

  final outCapsules = <Map<String, Object?>>[];
  for (final r in capsuleRows) {
    final opened = r.openedAt != null;
    // Opened: its content. Sealed: the title only (visible while sealed,
    // PRD F4), read without opening anything else.
    final payload = await capsules.payloadOf(r);
    outCapsules.add({
      'sealedAt': _day(r.sealedAt),
      'unlock': r.unlockType,
      if (r.unlockLocalDate != null) 'unlockDate': r.unlockLocalDate,
      if (r.triggerMoodId != null) 'triggerMood': r.triggerMoodId,
      if (r.triggerQuadrant != null) 'triggerQuadrant': r.triggerQuadrant,
      'opened': opened,
      if (opened) 'openedAt': _day(r.openedAt!),
      'title': ?payload?.title,
      if (opened && payload != null) ...{
        'text': payload.text,
        'writtenInAHardMoment': payload.hardMoment,
        'voiceNotes': payload.media.where((m) => m.slot == 'voice').length,
        'photos': payload.media.where((m) => m.slot != 'voice').length,
      },
    });
  }

  return ExportBundle(
    exportedAt: now,
    localeTag: localeTag,
    checkIns: [
      for (final c in checkIns)
        {
          'day': c.localDay,
          'at': _day(c.deviceTs),
          'mood': c.moodId,
          'moodName': moodById(c.moodId)?.nameFor(localeTag) ?? c.moodId,
          'quadrant': c.quadrant,
          'tags': List<String>.of(c.tags),
          'note': c.note,
          'voiceNote': c.voiceFile != null || c.voicePath != null,
          'from': c.source,
        },
    ],
    habits: [
      for (final h in habits)
        {
          'name': habitNames[h.id],
          'kind': h.kind,
          'shown': h.active,
          'added': _day(h.createdAt),
          // W02: the person's own opt-in (RULES.md section 13); null = none.
          'committedFrom': h.committedFrom,
          'pausedThrough': h.pausedThrough,
        },
    ],
    habitLogs: [
      for (final g in logs) {'habit': habitNames[g.habitId], 'day': g.localDay},
    ],
    capsules: outCapsules,
    server: server,
  );
}

// ---- formats ------------------------------------------------------------------

/// The machine-readable copy.
String exportJson(ExportBundle b) =>
    const JsonEncoder.withIndent('  ').convert(b.toJson());

/// Check-ins as CSV (RFC 4180; a spreadsheet opens it).
String exportCsv(ExportBundle b) {
  String cell(Object? v) {
    final s = v is List ? v.join('; ') : (v ?? '').toString();
    return '"${s.replaceAll('"', '""')}"';
  }

  final rows = <String>[
    [
      'day',
      'time_utc',
      'mood',
      'mood_name',
      'quadrant',
      'tags',
      'note',
      'voice_note',
      'from',
    ].map(cell).join(','),
    for (final c in b.checkIns)
      [
        c['day'],
        c['at'],
        c['mood'],
        c['moodName'],
        c['quadrant'],
        c['tags'],
        c['note'],
        c['voiceNote'] == true ? 'yes' : 'no',
        c['from'],
      ].map(cell).join(','),
  ];
  return '${rows.join('\r\n')}\r\n';
}

String _esc(Object? v) => const HtmlEscape().convert((v ?? '').toString());

/// The readable copy: one self-contained page, no scripts, no remote assets.
String exportHtml(ExportBundle b, ExportLabels l) {
  final out = StringBuffer()
    ..writeln('<!doctype html>')
    ..writeln('<html lang="${_esc(b.localeTag)}"><head><meta charset="utf-8">')
    ..writeln(
      '<meta name="viewport" content="width=device-width, initial-scale=1">',
    )
    ..writeln('<title>${_esc(l.title)}</title>')
    ..writeln(
      '<style>body{font:16px/1.6 system-ui,sans-serif;max-width:46rem;'
      'margin:2rem auto;padding:0 1rem;color:#1d1b2f}h1{font-weight:400}'
      'h2{margin-top:2rem;border-bottom:1px solid #ddd}'
      '.muted{color:#5d5a73}li{margin:.4rem 0}</style>',
    )
    ..writeln('</head><body>')
    ..writeln('<h1>${_esc(l.title)}</h1>')
    ..writeln('<p class="muted">${_esc(l.exported)}</p>');

  void section(String heading, List<String> items) {
    out.writeln('<h2>${_esc(heading)}</h2>');
    if (items.isEmpty) {
      out.writeln('<p class="muted">${_esc(l.nothing)}</p>');
      return;
    }
    out.writeln('<ul>');
    for (final i in items) {
      out.writeln('<li>$i</li>');
    }
    out.writeln('</ul>');
  }

  section(l.checkIns, [
    for (final c in b.checkIns)
      [
        '<strong>${_esc(c['day'])}</strong> · ${_esc(c['moodName'])}',
        if ((c['tags'] as List).isNotEmpty)
          '<span class="muted">${_esc((c['tags'] as List).join(', '))}</span>',
        if (c['note'] != null) '<br>${_esc(c['note'])}',
        if (c['voiceNote'] == true)
          '<br><span class="muted">(${_esc(l.voiceNote)})</span>',
      ].join(' '),
  ]);

  final byHabit = <String, int>{};
  for (final g in b.habitLogs) {
    final n = '${g['habit']}';
    byHabit[n] = (byHabit[n] ?? 0) + 1;
  }
  section(l.habits, [
    for (final h in b.habits)
      [
        '${_esc(h['name'])} <span class="muted">· ${byHabit['${h['name']}'] ?? 0}</span>',
        if (h['committedFrom'] != null)
          '<span class="muted">· ${_esc(l.commitmentSince('${h['committedFrom']}'))}'
              '${h['pausedThrough'] != null ? ' · ${_esc(l.pausedUntil('${h['pausedThrough']}'))}' : ''}</span>',
      ].join(' '),
  ]);

  section(l.capsules, [
    for (final c in b.capsules)
      [
        '<strong>${_esc(c['title'] ?? '')}</strong>',
        '<span class="muted">${_esc(c['sealedAt'].toString().substring(0, 10))}</span>',
        if (c['opened'] != true)
          '<span class="muted">· ${_esc(l.sealed)}${c['unlockDate'] != null ? ' · ${_esc(c['unlockDate'])}' : ''}</span>',
        if (c['text'] != null) '<br>${_esc(c['text'])}',
      ].join(' '),
  ]);

  final s = b.server;
  if (s != null) {
    final account = <String>[];
    final p = s['profile'];
    if (p is Map) {
      account
        ..add(_esc(p['birthDate']))
        ..add(
          '${_esc(p['uiLocale'])} · ${_esc(p['timezone'])} · ${_esc(p['country'] ?? '')}',
        );
    }
    final plus = s['plus'];
    if (plus is Map && plus['state'] != null) {
      account.add(
        'Aura Plus · ${_esc(plus['state'])} · ${_esc(plus['until'] ?? '')}',
      );
    }
    for (final x in (s['purchases'] as List? ?? const [])) {
      if (x is Map) {
        account.add(
          '${_esc(x['productId'])} · ${_esc(x['store'])} · ${_esc(x['state'])} · ${_esc(x['purchasedAt'] ?? '')}',
        );
      }
    }
    final stardust = s['stardust'];
    if (stardust is Map) account.add('Stardust · ${_esc(stardust['balance'])}');
    for (final k in (s['keepsakes'] as List? ?? const [])) {
      if (k is Map) account.add('${_esc(k['key'])} · ${_esc(k['earnedOn'])}');
    }
    section(l.account, account);
    section(l.reflections, [
      for (final r in (s['reflections'] as List? ?? const []))
        if (r is Map && r['text'] != null)
          '${_esc(r['text'])} <span class="muted">· ${_esc(r['createdAt'].toString().substring(0, 10))}</span>',
    ]);
    final minutes = <String, int>{};
    for (final x in (s['sanctuarySessions'] as List? ?? const [])) {
      if (x is Map) {
        final a = '${x['activity']}';
        minutes[a] =
            (minutes[a] ?? 0) + ((x['durationS'] as num?)?.toInt() ?? 0);
      }
    }
    section(l.sanctuary, [
      for (final e in minutes.entries)
        '${_esc(e.key)} · ${(e.value / 60).round()} min',
    ]);
  }
  out.writeln('</body></html>');
  return out.toString();
}

// ---- sharing ------------------------------------------------------------------

/// One file of a copy: its name, type and bytes.
@immutable
class ExportFile {
  const ExportFile(this.name, this.mimeType, this.bytes);

  final String name;
  final String mimeType;
  final Uint8List bytes;
}

/// Hands the files to the OS share sheet (and nothing else).
abstract interface class ExportShare {
  Future<void> share(
    List<ExportFile> files, {
    required String text,
    Rect? origin,
  });
}

class SharePlusExportShare implements ExportShare {
  const SharePlusExportShare();

  @override
  Future<void> share(
    List<ExportFile> files, {
    required String text,
    Rect? origin,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          for (final f in files)
            XFile.fromData(f.bytes, mimeType: f.mimeType, name: f.name),
        ],
        fileNameOverrides: [for (final f in files) f.name],
        subject: text,
        text: text,
        sharePositionOrigin: origin,
      ),
    );
  }
}

final exportShareProvider = Provider<ExportShare>(
  (ref) => const SharePlusExportShare(),
);

/// The three files of one copy, named by the day it was made.
List<ExportFile> exportFiles(ExportBundle b, ExportLabels labels) {
  final day = b.exportedAt.toIso8601String().substring(0, 10);
  Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));
  return [
    ExportFile(
      'aura-data-$day.html',
      'text/html',
      bytes(exportHtml(b, labels)),
    ),
    ExportFile('aura-data-$day.json', 'application/json', bytes(exportJson(b))),
    ExportFile('aura-checkins-$day.csv', 'text/csv', bytes(exportCsv(b))),
  ];
}

/// Collects (phone + server) → the files. Throws [ApiException] when the
/// signed-in account's server part can't be fetched: a copy without the
/// account details would look complete but isn't (PRD 14 "The export didn't
/// finish").
final dataExportProvider =
    Provider<
      Future<List<ExportFile>> Function(ExportLabels labels, String localeTag)
    >((ref) {
      return (labels, localeTag) async {
        final api = ref.read(auraApiProvider);
        final signedIn = ref.read(authRepositoryProvider).currentUser != null;
        final server = signedIn && api != null
            ? await api.accountExport()
            : null;
        final bundle = await collectExport(
          db: ref.read(appDatabaseProvider),
          capsules: ref.read(capsuleRepositoryProvider),
          localeTag: localeTag,
          now: ref.read(timeContextProvider).now(),
          server: server,
        );
        return exportFiles(bundle, labels);
      };
    });
