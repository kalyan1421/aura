import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:aura/l10n/app_localizations.dart';

import 'app_localizations_pseudo.dart';

/// Pseudo-localization (PRD 18): accents on ASCII letters, ~40% longer, and
/// brackets that show truncation. Brand terms stay as they are (PRD 18
/// "Brand terms stay in Latin script").
const Map<String, String> _accents = {
  'a': 'å', 'e': 'é', 'i': 'ï', 'o': 'ö', 'u': 'ü', 'c': 'ç', 'n': 'ñ', //
  's': 'š', 'y': 'ý', 'z': 'ž', 'A': 'Å', 'E': 'É', 'I': 'Ï', 'O': 'Ö',
  'U': 'Ü', 'C': 'Ç', 'N': 'Ñ', 'S': 'Š', 'Y': 'Ý', 'Z': 'Ž',
};

const List<String> _brands = [
  'Aura Plus', 'Aura', 'Lantern Hour', 'Breath Ripples', 'Starlight', //
  'Stardust', 'Tele-MANAS', 'Childline',
];

String pseudo(String s) {
  if (s.isEmpty) return s;
  final out = StringBuffer();
  var i = 0;
  outer:
  while (i < s.length) {
    for (final b in _brands) {
      if (s.startsWith(b, i)) {
        out.write(b);
        i += b.length;
        continue outer;
      }
    }
    final ch = s[i];
    out.write(_accents[ch] ?? ch);
    i++;
  }
  final letters = s.runes.where((r) => r > 64).length;
  final pad = (letters * 0.4).ceil();
  return '[$out${pad > 0 ? ' ${'·' * pad}' : ''}]';
}

class PseudoLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const PseudoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(AppLocalizationsPseudo());

  @override
  bool shouldReload(PseudoLocalizationsDelegate old) => false;
}
