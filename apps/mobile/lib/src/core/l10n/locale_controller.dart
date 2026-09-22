import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../db/kv_store.dart';
import '../env/env.dart';
import '../providers.dart';

part 'locale_controller.g.dart';

/// Aura locale tags ↔ Flutter [Locale]s (`te-Latn` ↔ `te` + script `Latn`).
Locale localeFromTag(String tag) {
  final parts = tag.split('-');
  return parts.length == 2
      ? Locale.fromSubtags(languageCode: parts[0], scriptCode: parts[1])
      : Locale(parts[0]);
}

String tagFromLocale(Locale l) =>
    l.scriptCode == null ? l.languageCode : '${l.languageCode}-${l.scriptCode}';

/// Languages offered in pickers. Hindi and Hinglish are beta (flag).
List<String> get pickerLocales => [
  AuraLocales.en,
  AuraLocales.te,
  AuraLocales.teLatn,
  if (Env.betaLocales) ...[AuraLocales.hi, AuraLocales.hiLatn],
];

/// Language names in their own script (data, not UI copy).
const Map<String, String> localeEndonyms = {
  AuraLocales.en: 'English',
  AuraLocales.te: 'తెలుగు',
  AuraLocales.teLatn: 'Tenglish',
  AuraLocales.hi: 'हिन्दी',
  AuraLocales.hiLatn: 'Hinglish',
};

/// First-launch default: a supported device language, else English. Phones
/// never report romanized locales, so Tenglish is always an explicit pick.
String defaultLocaleTag(List<Locale> deviceLocales) {
  for (final l in deviceLocales) {
    if (l.languageCode == 'te') return AuraLocales.te;
    if (l.languageCode == 'hi' && Env.betaLocales) return AuraLocales.hi;
    if (l.languageCode == 'en') return AuraLocales.en;
  }
  return AuraLocales.en;
}

@Riverpod(keepAlive: true)
String initialLocaleTag(Ref ref) => AuraLocales.en;

@Riverpod(keepAlive: true)
class LocaleController extends _$LocaleController {
  @override
  String build() => ref.read(initialLocaleTagProvider);

  /// Switches the UI at once, no restart (PRD States: Language).
  Future<void> select(String tag) async {
    if (tag == state) return;
    state = tag;
    await ref.read(kvStoreProvider).set(KvKeys.locale, tag);
    await ref.read(profileServiceProvider).markDirty();
  }
}

/// Material/Cupertino/Widgets localizations for romanized locales fall back to
/// English (PRD Localization `[ASSUMPTION]`): Flutter would otherwise pick the
/// Telugu-script or Devanagari system strings for `te-Latn` / `hi-Latn`.
class RomanizedFallbackDelegate<T> extends LocalizationsDelegate<T> {
  const RomanizedFallbackDelegate(this._inner);

  final LocalizationsDelegate<T> _inner;

  static Locale _map(Locale l) =>
      l.scriptCode == 'Latn' ? const Locale('en') : l;

  @override
  bool isSupported(Locale locale) => _inner.isSupported(_map(locale));

  @override
  Future<T> load(Locale locale) => _inner.load(_map(locale));

  @override
  bool shouldReload(covariant LocalizationsDelegate<T> old) => false;

  @override
  Type get type => T;
}

const List<LocalizationsDelegate<Object>> systemLocalizationDelegates = [
  RomanizedFallbackDelegate<MaterialLocalizations>(
    GlobalMaterialLocalizations.delegate,
  ),
  RomanizedFallbackDelegate<CupertinoLocalizations>(
    GlobalCupertinoLocalizations.delegate,
  ),
  RomanizedFallbackDelegate<WidgetsLocalizations>(
    GlobalWidgetsLocalizations.delegate,
  ),
];
