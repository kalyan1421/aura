// Generates lib/src/catalog.g.dart from contracts/moods.json.
//
//   cd packages/aura_domain && dart run tool/gen_catalog.dart
//
// The generated file is committed. test/catalog_test.dart fails if it drifts
// from the JSON, so a contract change without a regen is caught in CI.
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final packageRoot = File.fromUri(Platform.script).parent.parent;
  final source = File('${packageRoot.path}/../../contracts/moods.json');
  final out = File('${packageRoot.path}/lib/src/catalog.g.dart');

  final json = jsonDecode(source.readAsStringSync()) as Map<String, dynamic>;
  final quadrants = json['quadrants'] as Map<String, dynamic>;
  final moods = (json['moods'] as List<dynamic>).cast<Map<String, dynamic>>()
    ..sort((a, b) => (a['sort'] as int).compareTo(b['sort'] as int));
  final habits = (json['presetHabits'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final tags = (json['contextTags'] as List<dynamic>).cast<String>();

  final b = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
    ..writeln('// Source: contracts/moods.json')
    ..writeln(
      '// Regenerate: cd packages/aura_domain && '
      'dart run tool/gen_catalog.dart',
    )
    ..writeln()
    ..writeln("import 'mood.dart';")
    ..writeln()
    ..writeln('/// The four mood quadrants (energy x pleasantness).')
    ..writeln('enum Quadrant {');

  final qEntries = quadrants.entries.toList();
  for (var i = 0; i < qEntries.length; i++) {
    final q = qEntries[i].value as Map<String, dynamic>;
    final sep = i == qEntries.length - 1 ? ';' : ',';
    b.writeln('  ${_ident(qEntries[i].key)}(');
    b.writeln('    energy: Energy.${q['energy']},');
    b.writeln('    pleasant: ${q['pleasant']},');
    b.writeln('    theme: ${_str(q['theme'] as String)},');
    b.writeln('    hueDeg: ${(q['hueDeg'] as num).toDouble()},');
    b.writeln('  )$sep');
  }
  b
    ..writeln()
    ..writeln('  const Quadrant({')
    ..writeln('    required this.energy,')
    ..writeln('    required this.pleasant,')
    ..writeln('    required this.theme,')
    ..writeln('    required this.hueDeg,')
    ..writeln('  });')
    ..writeln()
    ..writeln('  /// Energy axis of the grid.')
    ..writeln('  final Energy energy;')
    ..writeln()
    ..writeln('  /// Pleasantness axis of the grid.')
    ..writeln('  final bool pleasant;')
    ..writeln()
    ..writeln('  /// Room theme id for this quadrant.')
    ..writeln('  final String theme;')
    ..writeln()
    ..writeln('  /// Hue anchor used by the hue rule (RULES.md section 6).')
    ..writeln('  final double hueDeg;')
    ..writeln('}')
    ..writeln()
    ..writeln('/// The fixed 16-mood catalogue, in grid order (`sort`).')
    ..writeln('const List<Mood> moodCatalog = <Mood>[');
  for (final m in moods) {
    final names = (m['names'] as Map<String, dynamic>).cast<String, String>();
    b
      ..writeln('  Mood(')
      ..writeln('    id: ${_str(m['id'] as String)},')
      ..writeln('    quadrant: Quadrant.${_ident(m['quadrant'] as String)},')
      ..writeln('    sort: ${m['sort']},')
      ..writeln('    names: <String, String>{');
    for (final e in names.entries) {
      b.writeln('      ${_str(e.key)}: ${_str(e.value)},');
    }
    b
      ..writeln('    },')
      ..writeln('  ),');
  }
  b
    ..writeln('];')
    ..writeln()
    ..writeln('/// Preset habit keys (`habits.preset_key`).')
    ..writeln('abstract final class PresetHabitKeys {');
  for (final h in habits) {
    final key = h['key'] as String;
    b.writeln('  static const String ${_camel(key)} = ${_str(key)};');
  }
  b
    ..writeln('}')
    ..writeln()
    ..writeln('/// The six preset habits, in display order.')
    ..writeln('const List<PresetHabit> presetHabits = <PresetHabit>[');
  for (final h in habits) {
    final names = (h['names'] as Map<String, dynamic>).cast<String, String>();
    b.writeln('  PresetHabit(');
    b.writeln('    key: ${_str(h['key'] as String)},');
    b.writeln('    names: <String, String>{');
    for (final e in names.entries) {
      b.writeln('      ${_str(e.key)}: ${_str(e.value)},');
    }
    b.writeln('    },');
    b.writeln('  ),');
  }
  b
    ..writeln('];')
    ..writeln()
    ..writeln('/// The 10 default context tags offered after picking a mood.')
    ..writeln('const List<String> contextTags = <String>[');
  for (final t in tags) {
    b.writeln('  ${_str(t)},');
  }
  b.writeln('];');

  out.writeAsStringSync(b.toString());
  final fmt = Process.runSync(Platform.resolvedExecutable, [
    'format',
    out.path,
  ]);
  if (fmt.exitCode != 0) {
    stderr.writeln(fmt.stderr);
  }
  stdout.writeln(
    'Wrote ${out.path} '
    '(${moods.length} moods, ${habits.length} habits, ${tags.length} tags)',
  );
}

String _str(String s) =>
    "'${s.replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'";

String _ident(String s) => _camel(s);

String _camel(String s) {
  final parts = s.split('_');
  return parts.first +
      parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
}
