import '../../../l10n/app_localizations.dart';

/// A tap-to-call helpline. Bundled in the app so the sheet works offline, with
/// no login, network, paywall or spinner (F9).
class Helpline {
  const Helpline({required this.name, required this.number, required this.dial});

  final String name;
  final String number;

  /// Digits for `tel:`.
  final String dial;
}

/// Helplines by device region (never IP or GPS). India and the US are
/// listed; everywhere else shows "call your local emergency number" rather
/// than an unverified list. A wrong number is a P0 bug: re-verify quarterly.
///
/// TODO(remote-config): refresh this list from the server on sync (PRD
/// Localization "Helplines by country").
List<Helpline> helplinesFor(
  String? countryCode,
  AppLocalizations l, {
  required bool isMinor,
}) {
  switch (countryCode) {
    case 'IN':
      return [
        Helpline(name: l.help_teleManas, number: '14416', dial: '14416'),
        Helpline(
          name: l.help_teleManasTollFree,
          number: '1-800-891-4416',
          dial: '18008914416',
        ),
        if (isMinor)
          Helpline(name: l.help_childline, number: '1098', dial: '1098'),
        Helpline(name: l.help_emergency112, number: '112', dial: '112'),
      ];
    case 'US':
      return [Helpline(name: l.help_us988, number: '988', dial: '988')];
    default:
      return const [];
  }
}
