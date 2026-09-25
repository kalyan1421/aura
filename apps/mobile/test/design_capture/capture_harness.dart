// Design capture harness (not part of the normal suite; see
// test/design_capture/capture_test.dart and dart_test.yaml).
//
// Renders screens at an iPhone 15 size (393×852 logical, DPR 3) with real
// fonts, grabs the root RepaintBoundary with toImage() and writes PNGs to
// docs/design/screens/. Every FlutterError reported while a state is built
// (overflows included) is recorded against the next shot instead of failing
// the test, and listed in build/design_capture/ISSUES.md.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:aura/src/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// iPhone 15 / 16: 393×852 points, 59 pt status bar, 34 pt home indicator.
const Size kPhone = Size(393, 852);
const double kRatio = 3;
const double kTopInset = 59;
const double kBottomInset = 34;

/// Output folder (repo root docs/), relative to apps/mobile.
final Directory outDir = Directory('../../docs/design/screens');

/// Per-shot metadata, so INDEX.md survives partial runs (`--name`).
final Directory metaDir = Directory('build/design_capture/meta');

/// The key of the RepaintBoundary around the whole app.
const Key captureRootKey = ValueKey('design-capture-root');

// ---- fonts -------------------------------------------------------------------

/// SF Pro (macOS's SFNS.ttf, the iPhone's system font) under the theme's iOS
/// typography names, falling back to the SDK's Roboto; the bundled Noto
/// Telugu / Devanagari; and Material Icons (otherwise every icon is a box).
///
/// The bundled Noto fonts have no Latin letters or symbols: on a phone, text
/// such as "ఈరోజు 25 Starlight" or "·" falls back to the system font, but
/// flutter_tester has no system fallback (only the families a style names).
/// So a [script] run (`te` or `hi`) puts the system font under the *other*
/// script's family name, which is the theme's fallback there; each script
/// runs in its own test file (fonts can't be unloaded).
Future<String> loadCaptureFonts({String? script}) async {
  Future<void> load(String family, Iterable<String> paths) async {
    final loader = FontLoader(family);
    for (final p in paths) {
      loader.addFont(
        Future.value(ByteData.sublistView(File(p).readAsBytesSync())),
      );
    }
    await loader.load();
  }

  final sdk = _materialFontsDir();
  const sf = ['/System/Library/Fonts/SFNS.ttf'];
  final roboto = [
    '$sdk/Roboto-Regular.ttf',
    '$sdk/Roboto-Medium.ttf',
    '$sdk/Roboto-Bold.ttf',
  ];
  final useSf = sf.every((p) => File(p).existsSync());
  final system = useSf ? sf : roboto;
  await load('CupertinoSystemText', system);
  await load('CupertinoSystemDisplay', system);
  // Anything that asks for Roboto by name (Material defaults off iOS).
  await load('Roboto', roboto);
  await load('MaterialIcons', ['$sdk/MaterialIcons-Regular.otf']);
  const telugu = [
    'assets/fonts/NotoSansTelugu-Regular.ttf',
    'assets/fonts/NotoSansTelugu-Medium.ttf',
    'assets/fonts/NotoSansTelugu-SemiBold.ttf',
  ];
  const devanagari = [
    'assets/fonts/NotoSansDevanagari-Regular.ttf',
    'assets/fonts/NotoSansDevanagari-Medium.ttf',
    'assets/fonts/NotoSansDevanagari-SemiBold.ttf',
  ];
  await load(AuraFonts.telugu, script == 'hi' ? system : telugu);
  await load(AuraFonts.devanagari, script == 'te' ? system : devanagari);
  return useSf ? 'SF Pro (SFNS.ttf)' : 'Roboto';
}

String _materialFontsDir() {
  final dirs = <String>[
    if (Platform.environment['FLUTTER_ROOT'] case final root?)
      '$root/bin/cache/artifacts/material_fonts',
  ];
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    dirs.add('${dir.path}/material_fonts');
    dirs.add('${dir.path}/bin/cache/artifacts/material_fonts');
    dir = dir.parent;
  }
  for (final d in dirs) {
    if (File('$d/MaterialIcons-Regular.otf').existsSync() &&
        File('$d/Roboto-Regular.ttf').existsSync()) {
      return d;
    }
  }
  throw StateError('material_fonts not found in the Flutter SDK cache');
}

// ---- the phone ---------------------------------------------------------------

/// An iPhone 15 view: size, DPR, safe areas and the OS text size.
void setPhone(WidgetTester tester, {double textScale = 1}) {
  tester.view.physicalSize = kPhone * kRatio;
  tester.view.devicePixelRatio = kRatio;
  const insets = FakeViewPadding(
    top: kTopInset * kRatio,
    bottom: kBottomInset * kRatio,
  );
  tester.view.padding = insets;
  tester.view.viewPadding = insets;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

// ---- shots -------------------------------------------------------------------

class ShotMeta {
  ShotMeta({
    required this.file,
    required this.screen,
    required this.state,
    required this.locale,
    required this.scale,
    required this.source,
    this.errors = const [],
  });

  final String file;
  final String screen;
  final String state;
  final String locale;
  final double scale;
  final String source;
  final List<String> errors;

  Map<String, Object?> toJson() => {
    'file': file,
    'screen': screen,
    'state': state,
    'locale': locale,
    'scale': scale,
    'source': source,
    'errors': errors,
  };

  static ShotMeta fromJson(Map<String, dynamic> j) => ShotMeta(
    file: j['file'] as String,
    screen: j['screen'] as String,
    state: j['state'] as String,
    locale: j['locale'] as String,
    scale: (j['scale'] as num).toDouble(),
    source: j['source'] as String,
    errors: [for (final e in j['errors'] as List<dynamic>) e as String],
  );
}

/// One capture test's context: the locale and scale it runs at and the
/// errors reported since the last shot.
class Cap {
  Cap(this.tester, {required this.locale, required this.scale});

  final WidgetTester tester;
  final String locale;
  final double scale;
  final List<String> pending = [];
  final List<ShotMeta> shots = [];

  /// Grabs the whole app (dialogs and sheets included) as
  /// `docs/design/screens/<file>.png`.
  Future<void> shoot(
    String file, {
    required String screen,
    required String state,
    required String source,
  }) async {
    final name = file.endsWith('.png') ? file : '$file.png';
    final errors = [...pending];
    pending.clear();
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(captureRootKey),
      );
      final image = await boundary.toImage(pixelRatio: kRatio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      outDir.createSync(recursive: true);
      File('${outDir.path}/$name')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
      final meta = ShotMeta(
        file: name,
        screen: screen,
        state: state,
        locale: locale,
        scale: scale,
        source: source,
        errors: errors,
      );
      shots.add(meta);
      metaDir.createSync(recursive: true);
      File('${metaDir.path}/${name.replaceAll('.png', '.json')}')
          .writeAsStringSync(jsonEncode(meta.toJson()));
    });
  }
}

/// The first lines of a FlutterError that say what and where.
String summarizeError(FlutterErrorDetails d) {
  final lines = d.toString().split('\n').map((l) => l.trim()).toList();
  final out = <String>[];
  final head = d.exceptionAsString().split('\n').first.trim();
  out.add(head);
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    if (l.startsWith('The relevant error-causing widget was') &&
        i + 1 < lines.length) {
      out.add('widget: ${lines[i + 1]}');
    }
    if (l.startsWith('The overflowing') && out.length < 4) {
      out.add(l);
    }
  }
  return out.join(' | ');
}

/// A capture test: [body] runs with errors recorded (not thrown), and the
/// tree is unmounted at the end so timers and streams close.
void captureTest(
  String description,
  Future<void> Function(WidgetTester tester, Cap cap) body, {
  String locale = 'en',
  double scale = 1,
}) {
  testWidgets(description, (tester) async {
    final original = FlutterError.onError;
    final cap = Cap(tester, locale: locale, scale: scale);
    FlutterError.onError = (details) {
      cap.pending.add(summarizeError(details));
    };
    try {
      setPhone(tester, textScale: scale);
      await body(tester, cap);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 30));
    } finally {
      FlutterError.onError = original;
      if (cap.pending.isNotEmpty) {
        // Errors after the last shot (while unmounting): print them.
        // ignore: avoid_print
        print('[capture] $description: after last shot: ${cap.pending}');
      }
      for (final s in cap.shots) {
        if (s.errors.isNotEmpty) {
          // ignore: avoid_print
          print('[capture] ${s.file}: ${s.errors.length} error(s)');
          for (final e in s.errors) {
            // ignore: avoid_print
            print('    $e');
          }
        }
      }
    }
  });
}

// ---- INDEX.md ----------------------------------------------------------------

/// Rebuilds docs/design/screens/INDEX.md from every shot's metadata whose
/// PNG exists, and the error log build/design_capture/ISSUES.md.
void writeIndex({required String fonts}) {
  if (!metaDir.existsSync()) return;
  final shots = <ShotMeta>[
    for (final f in metaDir.listSync().whereType<File>())
      if (f.path.endsWith('.json'))
        ShotMeta.fromJson(
          jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
        ),
  ]..removeWhere((s) => !File('${outDir.path}/${s.file}').existsSync());
  shots.sort((a, b) => a.file.compareTo(b.file));
  String scale(double s) => '${(s * 100).round()}%';
  final b = StringBuffer()
    ..writeln('# Aura screen captures')
    ..writeln()
    ..writeln(
      'Rendered by `apps/mobile/test/design_capture/capture_test.dart` '
      '(`cd apps/mobile && flutter test --tags capture --run-skipped test/design_capture`) '
      'at 393×852 pt, DPR 3 (1179×2556 px), iPhone 15 safe areas, real '
      'fonts ($fonts, Noto Sans Telugu / Devanagari, Material Icons), the '
      'app theme (`buildAuraTheme`) and in-memory fakes. Test clock: '
      'Thu 8 Oct 2026, 15:30 IST unless a state says otherwise.',
    )
    ..writeln()
    ..writeln('| File | Screen | State | Locale | Text scale | Source |')
    ..writeln('|---|---|---|---|---|---|');
  for (final s in shots) {
    b.writeln(
      '| [${s.file}](${s.file}) | ${s.screen} | ${s.state} | ${s.locale} | '
      '${scale(s.scale)} | `${s.source}` |',
    );
  }
  File('${outDir.path}/INDEX.md').writeAsStringSync(b.toString());

  final issues = shots.where((s) => s.errors.isNotEmpty).toList();
  final i = StringBuffer()
    ..writeln('# Rendering issues seen during capture')
    ..writeln()
    ..writeln(
      'Every FlutterError reported while a state was built (layout '
      'overflows included), listed against the shot it precedes. '
      'Overflow stripes are visible in the PNGs.',
    )
    ..writeln();
  if (issues.isEmpty) {
    i.writeln('None.');
  }
  for (final s in issues) {
    i.writeln('## ${s.file} (${s.locale}, ${scale(s.scale)})');
    for (final e in s.errors.toSet()) {
      i.writeln('- $e');
    }
    i.writeln();
  }
  File('${metaDir.parent.path}/ISSUES.md').writeAsStringSync(i.toString());
}
