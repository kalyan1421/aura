// PRD 18 "String externalization": "No hard-coded user-facing strings; CI
// lint fails on literals in widget code." CI is parked, so the rule runs
// with `flutter test`.
//
// The test parses every file under lib/src and fails on a string literal
// with words in it that reaches the screen or a screen reader:
//  - the first positional argument of `Text`, `SelectableText`, `RichText`'s
//    `TextSpan(text:)` and `Tooltip(message:)`;
//  - a named argument whose name is a user-facing slot: `labelText`,
//    `hintText`, `helperText`, `errorText`, `counterText`, `prefixText`,
//    `suffixText`, `tooltip`, `semanticsLabel`, `semanticLabel`, `label`,
//    `hint`, `message`, `text` (`TextSpan`), `title` / `subtitle` when a
//    literal string.
// Copy belongs in tool/l10n/*.py (5 locales) and is read through
// AppLocalizations. Data that is not copy (endonyms, brand names, route and
// asset names) is either not in these slots or listed in [_allowlist].
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widgets whose first positional argument is shown text.
const _textWidgets = {'Text', 'SelectableText', 'Tooltip'};

/// Named arguments that are shown or spoken.
const _slots = {
  'labelText', 'hintText', 'helperText', 'errorText', 'counterText', //
  'prefixText', 'suffixText', 'tooltip', 'semanticsLabel', 'semanticLabel',
  'label', 'hint', 'message', 'text', 'title', 'subtitle', 'content',
};

/// A letter followed by letters or marks (Telugu and Devanagari vowel signs
/// are marks) in any script: a word someone reads.
final _words = RegExp(r'\p{L}[\p{L}\p{M}]+', unicode: true);

/// Files (relative to apps/mobile) that may hold literals, with the reason.
const _allowlist = <String, String>{
  'lib/src/features/avatar/avatar_debug_screen.dart':
      'The "Avatar lab" developer screen: only with AURA_DEBUG_TOOLS, never '
      'in a release build (design critique "Avatar lab hidden").',
};

class _Finding {
  _Finding(this.file, this.line, this.source);
  final String file;
  final int line;
  final String source;
  @override
  String toString() => '$file:$line  $source';
}

bool _isCopy(Expression e) {
  if (e is SimpleStringLiteral) return _words.hasMatch(e.value);
  if (e is AdjacentStrings) return e.strings.any(_isCopy);
  if (e is StringInterpolation) {
    return e.elements.whereType<InterpolationString>().any(
      (s) => _words.hasMatch(s.value),
    );
  }
  return false;
}

class _Visitor extends RecursiveAstVisitor<void> {
  _Visitor(this.file, this.unit);
  final String file;
  final CompilationUnit unit;
  final findings = <_Finding>[];

  void _flag(AstNode node) => findings.add(
    _Finding(
      file,
      unit.lineInfo.getLocation(node.offset).lineNumber,
      node.toSource(),
    ),
  );

  void _checkArgs(String callee, ArgumentList args) {
    final positional = args.arguments
        .where((a) => a is! NamedArgument)
        .map((a) => a.argumentExpression);
    if (_textWidgets.contains(callee) &&
        positional.isNotEmpty &&
        _isCopy(positional.first)) {
      _flag(positional.first);
    }
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _checkArgs(node.constructorName.type.name.lexeme, node.argumentList);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null) {
      _checkArgs(node.methodName.name, node.argumentList);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitNamedArgument(NamedArgument node) {
    // Only arguments of a call (a widget or a constructor): map literals and
    // records never get here.
    if (_slots.contains(node.name.lexeme) && _isCopy(node.argumentExpression)) {
      _flag(node);
    }
    super.visitNamedArgument(node);
  }
}

List<_Finding> _scan(String path, String source) {
  final unit = parseString(content: source, throwIfDiagnostics: false).unit;
  final v = _Visitor(path, unit);
  unit.accept(v);
  return v.findings;
}

void main() {
  test('the checker flags literals in shown slots and passes l10n', () {
    const src = r'''
Widget build(BuildContext context, AppLocalizations l, String name) => Column(
  children: [
    Text('Hello there'),
    const Text("Save"),
    Text(l.common_done),
    Text('$name'),
    Text('·'),
    TextField(decoration: InputDecoration(labelText: 'Your email')),
    Semantics(label: 'Opens the room', child: Icon(Icons.add)),
    Tooltip(message: l.help_button, child: SizedBox()),
    IconButton(tooltip: 'Close', onPressed: null, icon: Icon(Icons.close)),
    Text('తెలుగు'),
    ListTile(title: Text(l.settings_title), subtitle: Text('Step $name of 3')),
  ],
);
final m = {'label': 'not a widget'};
''';
    final hits = _scan('fixture.dart', src).map((f) => f.source).toList();
    expect(hits, [
      "'Hello there'",
      '"Save"',
      "labelText: 'Your email'",
      "label: 'Opens the room'",
      "tooltip: 'Close'",
      "'తెలుగు'",
      "'Step \$name of 3'",
    ]);
  });

  test('no hard-coded user-facing strings in lib/src', () {
    final findings = <_Finding>[];
    var files = 0;
    for (final e in Directory('lib/src').listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      if (e.path.endsWith('.g.dart') || e.path.endsWith('.freezed.dart')) {
        continue;
      }
      files++;
      if (_allowlist.containsKey(e.path)) continue;
      findings.addAll(_scan(e.path, e.readAsStringSync()));
    }
    expect(files, greaterThan(200), reason: 'scanned lib/src');
    expect(
      findings,
      isEmpty,
      reason:
          'Move these into tool/l10n/*.py (all 5 locales) and read them '
          'through AppLocalizations:\n${findings.join('\n')}',
    );
  });

  test('every allowlisted file still exists', () {
    for (final f in _allowlist.keys) {
      expect(File(f).existsSync(), isTrue, reason: '$f is gone: drop it');
    }
  });
}
