import 'package:uuid/uuid.dart';

/// Client-generated ids. Records and mutations use UUIDv7 (time-ordered), so
/// offline writes are idempotent and sort by creation.
class Ids {
  const Ids();

  static const Uuid _uuid = Uuid();

  String v7() => _uuid.v7();
}
