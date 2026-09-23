import 'package:flutter/foundation.dart';

import 'analytics_schema.dart';

/// An event that passed the privacy filter: a schema name and only the
/// properties the schema allows for it, with values that match their specs.
@immutable
class CleanEvent {
  const CleanEvent(this.name, this.properties);

  final String name;
  final Map<String, Object> properties;
}

/// The privacy filter (PRD 13-analytics principles 1–3). Returns `null` for
/// an event the schema doesn't list. Otherwise keeps a property only when
/// it is listed for [name] and its value matches the spec: an enum value
/// from the closed set, a bool, a bounded int or a fixed-shape code. Any
/// other key — a note, a title, a DOB, an email, a pseudonym, a room or
/// user id, a token — is dropped, whatever its value.
///
/// Dropped keys are reported (names only, never values) through [onDropped]
/// so a debug build can say which call site is wrong.
CleanEvent? sanitizeEvent(
  String name,
  Map<String, Object?> properties, {
  void Function(String key)? onDropped,
}) {
  final spec = analyticsSchema[name];
  if (spec == null) {
    onDropped?.call('<event>');
    return null;
  }
  final clean = <String, Object>{};
  for (final entry in properties.entries) {
    final allowed = spec[entry.key];
    final value = entry.value;
    if (allowed != null && value != null && allowed.accepts(value)) {
      clean[entry.key] = value;
    } else {
      onDropped?.call(entry.key);
    }
  }
  return CleanEvent(name, Map.unmodifiable(clean));
}

/// Keeps only the global properties that match [analyticsGlobalProps].
Map<String, Object> sanitizeGlobals(Map<String, Object?> globals) => {
  for (final e in globals.entries)
    if (e.value != null && (analyticsGlobalProps[e.key]?.accepts(e.value) ?? false))
      e.key: e.value!,
};

/// The properties that leave the phone for [event]: its own (already
/// clean), the clean [globals], and [analyticsFixedProps]. An event
/// property never overrides a global or fixed one.
Map<String, Object> outgoingProperties(
  CleanEvent event,
  Map<String, Object?> globals,
) => {
  ...event.properties,
  ...sanitizeGlobals(globals),
  ...analyticsFixedProps,
};

/// The last line of defence inside the PostHog SDK's `beforeSend`: an event
/// that isn't in the schema (a `$screen`, an `$exception`, anything the SDK
/// or a future integration adds from Dart) is dropped, and every property
/// that isn't allowed for it, a global, or a fixed one is removed.
({String name, Map<String, Object>? properties})? finalCheck(
  String name,
  Map<String, Object>? properties,
) {
  final spec = analyticsSchema[name];
  if (spec == null) return null;
  final props = properties ?? const <String, Object>{};
  return (
    name: name,
    properties: {
      for (final e in props.entries)
        if ((spec[e.key]?.accepts(e.value) ?? false) ||
            (analyticsGlobalProps[e.key]?.accepts(e.value) ?? false) ||
            analyticsFixedProps[e.key] == e.value)
          e.key: e.value,
    },
  );
}
