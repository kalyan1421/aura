import 'package:aura_domain/aura_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/db/kv_store.dart';
import '../../core/providers.dart';
import '../progress/progress_view.dart';

part 'decay_eligibility.g.dart';

/// Completed years on [today] for the person on this phone, for the
/// opt-in-decay age rule (RULES.md section 13, [decayEligible]). Uses the
/// stored DOB; an under-18 platform age signal (`minorUntil`, also kept on the
/// phone) caps it at 17 while it lasts. No DOB yet means 0 (never eligible).
int ageYearsFor({
  required LocalDay? birthDate,
  required LocalDay? minorUntil,
  required LocalDay today,
}) {
  if (birthDate == null) return 0;
  var age = today.year - birthDate.year;
  if (today.month < birthDate.month ||
      (today.month == birthDate.month && today.day < birthDate.day)) {
    age -= 1;
  }
  if (age < 0) age = 0;
  if (minorUntil != null && today.isBefore(minorUntil) && age > 17) return 17;
  return age;
}

/// [ageYearsFor] from the encrypted key-value store and today's Aura day.
/// Never leaves the phone.
@riverpod
Future<int> deviceAgeYears(Ref ref) async {
  final kv = ref.watch(kvStoreProvider);
  final today = ref.watch(progressViewProvider.select((v) => v.today));
  return ageYearsFor(
    birthDate: LocalDay.tryParse(await kv.get(KvKeys.birthDate)),
    minorUntil: LocalDay.tryParse(await kv.get(KvKeys.minorUntil)),
    today: today,
  );
}
