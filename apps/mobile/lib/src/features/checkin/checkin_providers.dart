import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/providers.dart';

part 'checkin_providers.g.dart';

/// The person's recent custom tags, offered again as chips in the picker and
/// the edit view (F1 custom tags). Read once per screen; deleted check-ins
/// never contribute.
@riverpod
Future<List<String>> recentCustomTags(Ref ref) =>
    ref.watch(checkInRepositoryProvider).recentCustomTags();
