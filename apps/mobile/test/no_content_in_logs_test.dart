// MASVS F-2 (docs/security/masvs-l1.md, STORAGE-2): no personal content in
// logs. `debugPrint` and `print` are NOT stripped from release builds (they
// reach logcat and the iOS unified log), so the rule "never log mood notes,
// reflection text, capsule content, voice, DOB, email or tokens" (CLAUDE.md,
// PRD 16 "logged (no content)") is enforced here rather than by review.
//
// The test parses every file under lib/ and inspects the arguments of
// `print`, `debugPrint`, `dart:developer` `log` and logger-style calls
// (`logger.info(…)`, `_log.w(…)`, …). An argument fails when:
//  1. an interpolated or passed expression names something sensitive (a
//     camelCase/snake_case part of an identifier is in [_sensitiveParts]),
//     unless it ends in a content-free member such as `.runtimeType`,
//     `.length` or `.code`; or
//  2. it stringifies an exception or error (`$e`, `${err.message}`,
//     `e.toString()`): platform and Postgres messages can quote user input.
// A reviewed exception goes in [_allowlist] with its justification.
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';

/// Identifier parts that name personal content or secrets.
const _sensitiveParts = {
  'note', 'notes', //
  'reflection', 'reflections',
  'capsule', 'capsules',
  'voice', 'audio', 'recording', 'transcript',
  'dob', 'birth', 'birthday', 'birthdate',
  'email', 'emails', 'mail',
  'token', 'tokens', 'jwt', 'session', 'password', 'secret', 'otp',
  'text', 'body', 'content', 'message', 'caption', 'plaintext', 'draft',
  'path', 'paths', 'file',
};

/// Final members that never carry content, whatever they're read from.
final _safeTail = RegExp(
  r'\.(runtimeType|length|isEmpty|isNotEmpty|code|statusCode|status|kind|'
  r'name|count|size|type|index|hashCode)$',
);

/// Stringified exceptions: `$e`, `${err}`, `${e.message}`, `e.toString()`,
/// `${e.message.substring(0, 80)}`.
final _exceptionText = RegExp(
  r'^(e|err|error|ex|exception|failure|f|st|stack|stackTrace)'
  r'(\??\.(message|details|toString\(\)|stackTrace)(\..*)?)?$',
);

/// `file (relative to apps/mobile) :: expression` → why it is safe.
const _allowlist = <String, String>{};

const _logFunctions = {'print', 'debugPrint', 'log', 'debugPrintSynchronously'};
const _loggerMethods = {
  'log', 'd', 'i', 'w', 'e', 'v', 't', 'f', //
  'debug', 'info', 'warn', 'warning', 'error', 'fine', 'finer', 'finest',
  'config', 'severe', 'shout', 'trace', 'verbose', 'fatal', 'wtf',
};
final _loggerTarget = RegExp(r'^(_?log(ger)?|_?[a-z]*Logger|developer)$');

List<String> _identifierParts(String expression) {
  final parts = <String>[];
  for (final m in RegExp(r'[A-Za-z_$][A-Za-z0-9_$]*').allMatches(expression)) {
    final id = m.group(0)!.replaceAll(r'$', '');
    for (final word in id.split('_')) {
      parts.addAll(
        RegExp(r'[A-Z]?[a-z0-9]+|[A-Z]+(?![a-z])')
            .allMatches(word)
            .map((p) => p.group(0)!.toLowerCase()),
      );
    }
  }
  return parts;
}

/// Why [expression] may not be logged, or null when it's fine.
String? _problem(String expression) {
  final e = expression.trim();
  if (_exceptionText.hasMatch(e)) {
    return 'stringifies an exception (its message can quote user input); '
        'log `.runtimeType` or a code instead';
  }
  if (_safeTail.hasMatch(e)) return null;
  final hit = _identifierParts(e).where(_sensitiveParts.contains).toList();
  if (hit.isNotEmpty) return 'names sensitive data (${hit.toSet().join(', ')})';
  return null;
}

class _Finding {
  _Finding(this.file, this.line, this.expression, this.problem);
  final String file;
  final int line;
  final String expression;
  final String problem;
  String get key => '$file :: $expression';
  @override
  String toString() => '$file:$line  `$expression`: $problem';
}

class _LogCallVisitor extends RecursiveAstVisitor<void> {
  _LogCallVisitor(this.file, this.unit);
  final String file;
  final CompilationUnit unit;
  final findings = <_Finding>[];
  int calls = 0;

  bool _isLogCall(MethodInvocation node) {
    final name = node.methodName.name;
    final target = node.target;
    if (target == null) return _logFunctions.contains(name);
    return _loggerMethods.contains(name) &&
        _loggerTarget.hasMatch(target.toSource());
  }

  void _checkExpression(Expression e) {
    final src = e.toSource();
    final problem = _problem(src);
    if (problem != null) {
      final line = unit.lineInfo.getLocation(e.offset).lineNumber;
      findings.add(_Finding(file, line, src, problem));
    }
  }

  void _checkArgument(Expression arg) {
    if (arg is SimpleStringLiteral) return;
    if (arg is AdjacentStrings) {
      arg.strings.forEach(_checkArgument);
      return;
    }
    if (arg is StringInterpolation) {
      for (final el in arg.elements) {
        if (el is InterpolationExpression) _checkArgument(el.expression);
      }
      return;
    }
    if (arg is ParenthesizedExpression) {
      _checkArgument(arg.expression);
      return;
    }
    if (arg is ConditionalExpression) {
      // Only the branches are printed.
      _checkArgument(arg.thenExpression);
      _checkArgument(arg.elseExpression);
      return;
    }
    if (arg is BinaryExpression &&
        const {'+', '??', '||'}.contains(arg.operator.lexeme)) {
      _checkArgument(arg.leftOperand);
      _checkArgument(arg.rightOperand);
      return;
    }
    _checkExpression(arg);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // `log(` without dart:developer is dart:math's logarithm.
    final isMathLog =
        node.methodName.name == 'log' &&
        node.target == null &&
        !unit.directives.whereType<ImportDirective>().any(
          (d) => d.uri.stringValue == 'dart:developer' && d.prefix == null,
        );
    if (_isLogCall(node) && !isMathLog) {
      calls++;
      // developer.log(name: 'tag', error: e, …): named values print too.
      for (final a in node.argumentList.arguments) {
        _checkArgument(a.argumentExpression);
      }
    }
    super.visitMethodInvocation(node);
  }
}

({List<_Finding> findings, int calls}) _scan(String path, String source) {
  final unit = parseString(content: source, throwIfDiagnostics: false).unit;
  final v = _LogCallVisitor(path, unit);
  unit.accept(v);
  return (findings: v.findings, calls: v.calls);
}

void main() {
  group('no content in logs (F-2)', () {
    test('the checker flags content and passes content-free logs', () {
      const src = r'''
import 'dart:developer';
import 'dart:math' as math;
void f(dynamic e, bool ok, String note, String userEmail, List<String> voicePaths,
    String accessToken, dynamic reflection, DateTime dateOfBirth) {
  debugPrint('sync: ${e.runtimeType}');
  debugPrint('media: ${voicePaths.length} file(s)');
  debugPrint('checkin: saved "$note"');
  print('auth: ' + userEmail);
  debugPrint('push: token=$accessToken');
  log('reflections: ${reflection.body}', name: 'aura');
  debugPrint('onboarding: ${dateOfBirth.year}');
  debugPrint('api: failed $e');
  debugPrint('api: ${e.message}');
  _logger.warn('refresh ${e.toString()}');
  debugPrint('x ${e?.message ?? 'none'} ${ok ? note : 'n/a'}');
  debugPrint('y ${e.message.substring(0, 80)}');
  math.log(2);
}
''';
      final found = _scan('fixture.dart', src).findings;
      expect(found.map((f) => f.expression), [
        'note',
        'userEmail',
        'accessToken',
        'reflection.body',
        'dateOfBirth.year',
        'e',
        'e.message',
        'e.toString()',
        'e?.message',
        'note',
        'e.message.substring(0, 80)',
      ]);
    });

    test('lib/** never logs personal content, secrets or exception text', () {
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.endsWith('.g.dart'))
          .where((f) => !f.path.endsWith('.freezed.dart'))
          .where((f) => !f.path.contains('/l10n/'))
          .toList();
      expect(files, isNotEmpty);

      final findings = <_Finding>[];
      var calls = 0;
      for (final f in files) {
        final r = _scan(f.path, f.readAsStringSync());
        findings.addAll(r.findings);
        calls += r.calls;
      }
      // Guard against the scanner silently matching nothing.
      expect(calls, greaterThan(100), reason: 'log calls found under lib/');

      final used = <String>{};
      final violations = <_Finding>[];
      for (final f in findings) {
        if (_allowlist.containsKey(f.key)) {
          used.add(f.key);
        } else {
          violations.add(f);
        }
      }
      expect(
        violations,
        isEmpty,
        reason:
            'Log only kinds, codes and counts (MASVS F-2). A reviewed, '
            'content-free exception goes in _allowlist with its reason:\n'
            '${violations.join('\n')}',
      );
      expect(
        _allowlist.keys.toSet().difference(used),
        isEmpty,
        reason: 'stale _allowlist entries: remove them',
      );
    });
  });
}
