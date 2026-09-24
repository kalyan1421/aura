import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';

part 'helplines_data.dart';

/// A tap-to-call helpline as the sheet shows it: its name in the app
/// language, the number as written and the digits for `tel:`.
class Helpline {
  const Helpline({
    required this.name,
    required this.number,
    required this.dial,
    this.id = '',
  });

  final String name;
  final String number;

  /// Digits for `tel:`.
  final String dial;

  /// The directory id (`in.tele_manas`), stable across versions.
  final String id;
}

/// One line of the helpline directory (contracts/safety/helplines.schema.json).
@immutable
class HelplineEntry {
  const HelplineEntry({
    required this.id,
    required this.number,
    required this.dial,
    required this.minorsOnly,
    required this.names,
  });

  final String id;
  final String number;
  final String dial;

  /// Listed only until the 18th birthday (and behind the under-13 lock).
  final bool minorsOnly;

  /// Name per app locale (`en`, `te`, `te-Latn`, `hi`, `hi-Latn`); `en` is
  /// always there.
  final Map<String, String> names;

  /// The name in [localeTag] (`te_Latn` or `te-Latn`), else English.
  String nameFor(String localeTag) =>
      names[localeTag.replaceAll('_', '-')] ?? names['en'] ?? '';
}

/// Where the active directory came from.
enum HelplineSource { bundled, remote }

/// The crisis helpline directory by device region (never IP or GPS; PRD 06c
/// F9, 18 "Helplines by country"). The bundled copy
/// (contracts/safety/helplines.v1.json → helplines_data.dart) is what every
/// build ships, so the sheet works offline, signed out, with no spinner. A
/// signed `helplines` bundle replaces it only after it verifies
/// (core/remote_config/remote_helplines.dart): a bad or unsigned one never
/// does. A region that isn't listed gets the "call your local emergency
/// number" card — never an unverified number, never an empty list.
@immutable
class HelplineDirectory {
  const HelplineDirectory({
    required this.version,
    required this.countries,
    this.source = HelplineSource.remote,
  });

  /// The directory every build bundles.
  static const HelplineDirectory bundled = HelplineDirectory(
    version: bundledHelplinesVersion,
    countries: bundledHelplineCountries,
    source: HelplineSource.bundled,
  );

  static final ValueNotifier<HelplineDirectory> _active = ValueNotifier(
    bundled,
  );

  /// What the crisis sheet, the Safety Center and the under-13 screen list:
  /// the last verified remote version, else the bundled one.
  static HelplineDirectory get active => _active.value;

  /// Changes whenever a verified version becomes active.
  static ValueListenable<HelplineDirectory> get listenable => _active;

  /// Makes a verified remote version the active one (in memory; the verified
  /// envelope is kept by the remote config store for the next start).
  static void activate(HelplineDirectory directory) =>
      _active.value = directory;

  /// Back to the bundled directory (tests).
  @visibleForTesting
  static void resetToBundled() => _active.value = bundled;

  final int version;
  final Map<String, List<HelplineEntry>> countries;
  final HelplineSource source;

  /// The lines for [countryCode] in order; `minorsOnly` lines only when
  /// [isMinor]. Empty for a region that isn't listed.
  List<HelplineEntry> resolve(String? countryCode, {required bool isMinor}) => [
    for (final e
        in countries[countryCode?.toUpperCase()] ?? const <HelplineEntry>[])
      if (isMinor || !e.minorsOnly) e,
  ];
}

/// The active [HelplineDirectory]; rebuilds its readers when a verified
/// remote version becomes active.
final helplineDirectoryProvider =
    NotifierProvider<HelplineDirectoryNotifier, HelplineDirectory>(
      HelplineDirectoryNotifier.new,
    );

class HelplineDirectoryNotifier extends Notifier<HelplineDirectory> {
  @override
  HelplineDirectory build() {
    final active = HelplineDirectory.listenable;
    void update() => state = active.value;
    active.addListener(update);
    ref.onDispose(() => active.removeListener(update));
    return active.value;
  }
}

/// Helplines by device region, named in the app language (English where a
/// line has no name in it yet). India and the US are listed; everywhere else
/// shows "call your local emergency number" rather than an unverified list.
/// A wrong number is a P0 bug: re-verify quarterly.
List<Helpline> helplinesFor(
  String? countryCode,
  AppLocalizations l, {
  required bool isMinor,
  HelplineDirectory? directory,
}) => [
  for (final e in (directory ?? HelplineDirectory.active).resolve(
    countryCode,
    isMinor: isMinor,
  ))
    Helpline(
      id: e.id,
      name: e.nameFor(l.localeName),
      number: e.number,
      dial: e.dial,
    ),
];
