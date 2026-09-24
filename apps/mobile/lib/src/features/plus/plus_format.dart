import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/entitlements/entitlement.dart';

/// "30 Oct 2026" in the person's language and zone (Telugu script for `te`;
/// English digits and months for Tenglish / others).
String plusDate(BuildContext context, DateTime d) {
  final locale = Localizations.localeOf(context);
  final tag = locale.languageCode == 'te' && locale.scriptCode == null
      ? 'te'
      : 'en';
  try {
    return DateFormat('d MMM y', tag).format(d.toLocal());
  } on Object {
    return DateFormat('d MMM y', 'en').format(d.toLocal());
  }
}

String storeName(AppLocalizations l, PlusStore store) =>
    store == PlusStore.apple ? l.plus_storeApple : l.plus_storeGoogle;

/// The Android package (Play subscription deep link).
const String androidPackage = 'com.akvega.aura';

/// The store's own subscription page — no retention screen or survey in
/// between (PRD 12 "One tap to cancel"). Apple: the App Store's account
/// subscriptions page; Play: the subscription's own page.
Uri manageSubscriptionUri(PlusStore store, {String? productId}) =>
    store == PlusStore.apple
    ? Uri.parse('https://apps.apple.com/account/subscriptions')
    : Uri.https('play.google.com', '/store/account/subscriptions', {
        'sku': ?productId,
        'package': androidPackage,
      });

typedef PlusUrlOpener = Future<bool> Function(Uri uri);

Future<bool> openStorePage(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Object {
    return false;
  }
}

/// Gift display name.
String giftName(AppLocalizations l, String kind) => switch (kind) {
  'comfort_lantern' => l.plus_giftComfortLantern,
  'encouragement_bouquet' => l.plus_giftBouquet,
  _ => l.plus_giftWarmTea,
};

/// Opens this platform's subscription page (the trial-ending push).
Future<bool> openManageSubscriptions({String? productId}) => openStorePage(
  manageSubscriptionUri(
    defaultTargetPlatform == TargetPlatform.iOS
        ? PlusStore.apple
        : PlusStore.google,
    productId: productId,
  ),
);
