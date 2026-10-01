// PRD 18 "RTL: Not needed at launch, but not blocked: EdgeInsetsDirectional,
// AlignmentDirectional and direction-aware icons everywhere (lint-enforced),
// so Urdu can ship later without layout rework." CI is parked, so the lint
// runs with `flutter test`.
//
// The test parses every file under lib/src and fails on a layout value that
// is fixed to the left or the right:
//  - `EdgeInsets.only(left: / right:)` (use `EdgeInsetsDirectional.only(start:
//    / end:)`), and `EdgeInsets.fromLTRB` whose left and right differ (use
//    `EdgeInsetsDirectional.fromSTEB`; equal sides are direction-neutral);
//  - `Alignment.centerLeft` and the other corner/side constants (use
//    `AlignmentDirectional`), `TextAlign.left / right` (use `start / end`);
//  - `BorderRadius.only(topLeft: …)` (use `BorderRadiusDirectional`);
//  - `Positioned(left: / right:)` unless both sides are given the same value
//    (use `PositionedDirectional`).
// A reviewed exception (drawing coordinates that follow a painter, a debug
// screen) goes in [_allowlist] with its reason.
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';

/// `file :: expression source` → why it may stay.
const _allowlist = <String, String>{
  'lib/src/features/ripples/ripple_screen.dart':
      'Seat lights sit on the x '
      'the OceanPainter draws them at (a picture, not reading order).',
  'lib/src/features/avatar/avatar_debug_screen.dart':
      'The "Avatar lab" developer screen (debug builds only).',
  'lib/src/features/universe/roam_controls.dart':
      'The free-roam walking pad: an arrow\'s direction is physical (the left '
      'arrow walks left on screen), so its four arrows keep fixed sides in '
      'right-to-left layouts too. The pad and arrows as a group still follow '
      'reading order.',
  'lib/src/features/orbit_loom/orbit_loom_screen.dart':
      'Orbit Loom\'s star buttons sit on the x the LoomSkyPainter draws each '
      'star at (a picture in the unit sky, not reading order). The controls '
      'around the sky still follow reading order.',
};

const _fixedAlignments = {
  'topLeft', 'topRight', 'centerLeft', 'centerRight', //
  'bottomLeft', 'bottomRight',
};

class _Finding {
  _Finding(this.file, this.line, this.source, this.fix);
  final String file;
  final int line;
  final String source;
  final String fix;
  @override
  String toString() => '$file:$line  $source  → $fix';
}

class _Visitor extends RecursiveAstVisitor<void> {
  _Visitor(this.file, this.unit);
  final String file;
  final CompilationUnit unit;
  final findings = <_Finding>[];

  void _flag(AstNode n, String fix) => findings.add(
    _Finding(
      file,
      unit.lineInfo.getLocation(n.offset).lineNumber,
      n.toSource(),
      fix,
    ),
  );

  Map<String, String> _named(ArgumentList args) => {
    for (final a in args.arguments.whereType<NamedArgument>())
      a.name.lexeme: a.argumentExpression.toSource(),
  };

  List<String> _positional(ArgumentList args) => [
    for (final a in args.arguments)
      if (a is! NamedArgument) a.argumentExpression.toSource(),
  ];

  void _check(String type, String? ctor, ArgumentList args, AstNode node) {
    final named = _named(args);
    if (type == 'EdgeInsets' && ctor == 'only') {
      if (named.containsKey('left') || named.containsKey('right')) {
        _flag(node, 'EdgeInsetsDirectional.only(start:, end:)');
      }
    } else if (type == 'EdgeInsets' && ctor == 'fromLTRB') {
      final p = _positional(args);
      if (p.length == 4 && p[0] != p[2]) {
        _flag(node, 'EdgeInsetsDirectional.fromSTEB');
      }
    } else if (type == 'BorderRadius' && ctor == 'only') {
      if (named.keys.any(
        (k) => const {
          'topLeft',
          'topRight',
          'bottomLeft',
          'bottomRight',
        }.contains(k),
      )) {
        _flag(node, 'BorderRadiusDirectional.only');
      }
    } else if (type == 'Positioned' && ctor == null) {
      final l = named['left'];
      final r = named['right'];
      if ((l != null || r != null) && l != r) {
        _flag(node, 'PositionedDirectional(start:, end:)');
      }
    }
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    // Unresolved, `const EdgeInsets.only(…)` reads as type `only` with the
    // "import prefix" `EdgeInsets`.
    final c = node.constructorName;
    final prefix = c.type.importPrefix?.name.lexeme;
    _check(
      prefix ?? c.type.name.lexeme,
      prefix != null ? c.type.name.lexeme : c.name?.name,
      node.argumentList,
      node,
    );
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Without `new`/`const`, `EdgeInsets.only(…)` parses as a call on a
    // target; `Positioned(…)` as a bare call.
    final target = node.target;
    if (target is SimpleIdentifier) {
      _check(target.name, node.methodName.name, node.argumentList, node);
    } else if (target == null) {
      _check(node.methodName.name, null, node.argumentList, node);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    final p = node.prefix.name;
    final id = node.identifier.name;
    if (p == 'Alignment' && _fixedAlignments.contains(id)) {
      _flag(node, 'AlignmentDirectional.${_directional(id)}');
    } else if (p == 'TextAlign' && (id == 'left' || id == 'right')) {
      _flag(node, 'TextAlign.${id == 'left' ? 'start' : 'end'}');
    }
    super.visitPrefixedIdentifier(node);
  }

  static String _directional(String id) =>
      id.replaceAll('Left', 'Start').replaceAll('Right', 'End');
}

List<_Finding> _scan(String path, String source) {
  final unit = parseString(content: source, throwIfDiagnostics: false).unit;
  final v = _Visitor(path, unit);
  unit.accept(v);
  return v.findings;
}

void main() {
  test('the checker flags fixed sides and passes directional or symmetric '
      'ones', () {
    const src = r'''
Widget f() => Column(children: [
  Padding(padding: const EdgeInsets.only(right: 6)),
  Padding(padding: EdgeInsets.only(top: 6)),
  Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32)),
  Padding(padding: const EdgeInsets.fromLTRB(12, 8, 20, 32)),
  Padding(padding: const EdgeInsetsDirectional.only(end: 6)),
  Align(alignment: Alignment.centerLeft),
  Align(alignment: Alignment.center),
  Text('x', textAlign: TextAlign.right),
  Positioned(left: 0, right: 0, child: x),
  Positioned(left: 4, child: x),
  Container(decoration: BoxDecoration(borderRadius: BorderRadius.only(topLeft: r))),
]);
''';
    final hits = _scan('fixture.dart', src).map((f) => f.fix).toList();
    expect(hits, [
      'EdgeInsetsDirectional.only(start:, end:)',
      'EdgeInsetsDirectional.fromSTEB',
      'AlignmentDirectional.centerStart',
      'TextAlign.end',
      'PositionedDirectional(start:, end:)',
      'BorderRadiusDirectional.only',
    ]);
  });

  test('lib/src is RTL-ready (directional layout everywhere)', () {
    final findings = <_Finding>[];
    for (final e in Directory('lib/src').listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      if (e.path.endsWith('.g.dart') || e.path.endsWith('.freezed.dart')) {
        continue;
      }
      if (_allowlist.containsKey(e.path)) continue;
      findings.addAll(_scan(e.path, e.readAsStringSync()));
    }
    expect(findings, isEmpty, reason: findings.join('\n'));
  });

  test('every allowlisted file still exists', () {
    for (final f in _allowlist.keys) {
      expect(File(f).existsSync(), isTrue, reason: '$f is gone: drop it');
    }
  });
}
