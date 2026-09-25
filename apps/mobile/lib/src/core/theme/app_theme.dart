import 'package:flutter/material.dart';

import 'aura_tokens.dart';

/// Bundled families (pubspec `fonts:`).
abstract final class AuraFonts {
  static const String telugu = 'NotoSansTelugu';
  static const String devanagari = 'NotoSansDevanagari';

  /// System font first, Indic scripts from the bundled Noto families (some
  /// OEM Android fonts render conjuncts badly).
  static const List<String> fallback = [telugu, devanagari];
}

/// Line height for a script: Telugu and Devanagari need ≥ 1.5 so stacked
/// consonants and vowel signs never clip (REQ-A11Y-14).
double lineHeightFor(Locale locale) => _isIndicScript(locale) ? 1.55 : 1.4;

bool _isIndicScript(Locale l) =>
    (l.languageCode == 'te' || l.languageCode == 'hi') &&
    l.scriptCode != 'Latn';

/// Size multiplier for a script whose glyphs look small beside Latin at
/// the same point size: Telugu (Noto Sans Telugu) reads about 10% smaller,
/// so its text is set 6% larger. Everything else is 1.
double fontScaleFor(Locale locale) =>
    locale.languageCode == 'te' && locale.scriptCode != 'Latn' ? 1.06 : 1.0;

String? fontFamilyFor(Locale locale) {
  if (locale.scriptCode == 'Latn') return null;
  return switch (locale.languageCode) {
    'te' => AuraFonts.telugu,
    'hi' => AuraFonts.devanagari,
    _ => null,
  };
}

/// A chip label's colour: dark on the lavender selected fill, light
/// otherwise, muted when disabled.
final WidgetStateColor chipLabelColor = WidgetStateColor.resolveWith(
  (s) => s.contains(WidgetState.selected)
      ? AuraColors.onAccent
      : s.contains(WidgetState.disabled)
      ? AuraColors.textMuted
      : AuraColors.text,
);

ThemeData buildAuraTheme(Locale locale) {
  final height = lineHeightFor(locale);
  final family = fontFamilyFor(locale);
  final scriptScale = fontScaleFor(locale);

  const scheme = ColorScheme.dark(
    primary: AuraColors.accent,
    onPrimary: AuraColors.onAccent,
    secondary: AuraColors.starlight,
    onSecondary: AuraColors.onAccent,
    surface: AuraColors.surface,
    onSurface: AuraColors.text,
    surfaceContainerHighest: AuraColors.surfaceHigh,
    surfaceContainerHigh: AuraColors.surfaceHigh,
    surfaceContainer: AuraColors.surface,
    surfaceContainerLow: AuraColors.skyHigh,
    onSurfaceVariant: AuraColors.textSoft,
    outline: AuraColors.outline,
    outlineVariant: AuraColors.hairline,
    error: AuraColors.lantern, // never red on personal data
    onError: AuraColors.onLantern,
  );

  // Sizes (englishLike geometry) merged with the white colours up front:
  // component themes (app bar title, buttons, chips) use these styles
  // directly, and `white` alone has no font sizes (the app bar title drew at
  // the 14 px fallback instead of titleLarge's 22).
  final typography = Typography.material2021(platform: TargetPlatform.iOS);
  final base = typography.englishLike.merge(typography.white);
  TextStyle? tune(
    TextStyle? s, {
    FontWeight? weight,
    double? spacing,
    bool reading = false,
  }) => s?.copyWith(
    // Reading text (titles, body) only: headlines are large already and
    // labels sit in fixed chrome (tabs, chips, buttons).
    fontSize: s.fontSize == null || !reading
        ? s.fontSize
        : s.fontSize! * scriptScale,
    fontFamily: family,
    fontFamilyFallback: AuraFonts.fallback,
    height: height,
    color: AuraColors.text,
    fontWeight: weight ?? s.fontWeight,
    letterSpacing: spacing ?? s.letterSpacing,
  );

  final text = base.copyWith(
    displaySmall: tune(
      base.displaySmall,
      weight: FontWeight.w500,
      spacing: -0.5,
    ),
    headlineMedium: tune(
      base.headlineMedium,
      weight: FontWeight.w500,
      spacing: -0.3,
    ),
    headlineSmall: tune(
      base.headlineSmall,
      weight: FontWeight.w500,
      spacing: -0.2,
    ),
    titleLarge: tune(base.titleLarge, weight: FontWeight.w600, reading: true),
    titleMedium: tune(base.titleMedium, weight: FontWeight.w600, reading: true),
    titleSmall: tune(base.titleSmall, weight: FontWeight.w600, reading: true),
    bodyLarge: tune(base.bodyLarge, reading: true),
    bodyMedium: tune(base.bodyMedium, reading: true),
    bodySmall: tune(
      base.bodySmall,
      reading: true,
    )?.copyWith(color: AuraColors.textSoft),
    labelLarge: tune(base.labelLarge, weight: FontWeight.w600, spacing: 0.2),
    labelMedium: tune(base.labelMedium, weight: FontWeight.w600),
    labelSmall: tune(base.labelSmall)?.copyWith(color: AuraColors.textSoft),
  );

  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AuraRadius.pill),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AuraColors.sky,
    canvasColor: AuraColors.sky,
    textTheme: text,
    fontFamily: family,
    fontFamilyFallback: AuraFonts.fallback,
    splashFactory: InkSparkle.splashFactory,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
      foregroundColor: AuraColors.text,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AuraColors.accent,
        foregroundColor: AuraColors.onAccent,
        disabledBackgroundColor: AuraColors.surfaceHigh,
        disabledForegroundColor: AuraColors.textMuted,
        minimumSize: const Size(64, 56),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        textStyle: text.labelLarge?.copyWith(fontSize: 17),
        shape: shape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AuraColors.text,
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        side: const BorderSide(color: AuraColors.outline),
        textStyle: text.labelLarge,
        shape: shape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AuraColors.lavender,
        minimumSize: const Size(48, 48),
        textStyle: text.labelLarge,
      ),
    ),
    // One selected state for every chip (design critique #1): a lavender
    // fill, dark label and a leading check, so "picked" never relies on a
    // 1.1:1 shade change. Idle chips keep the surface fill with a 3:1
    // control outline (WCAG 1.4.11). RawChip reports `selected` to screen
    // readers.
    chipTheme: ChipThemeData(
      backgroundColor: AuraColors.surface,
      selectedColor: AuraColors.accent,
      disabledColor: AuraColors.surface.withValues(alpha: 0.6),
      checkmarkColor: AuraColors.onAccent,
      side: WidgetStateBorderSide.resolveWith(
        (s) => BorderSide(
          color: s.contains(WidgetState.selected)
              ? AuraColors.accent
              : s.contains(WidgetState.disabled)
              ? AuraColors.outline
              : AuraColors.controlOutline,
        ),
      ),
      labelStyle: text.labelLarge?.copyWith(color: chipLabelColor),
      iconTheme: const IconThemeData(color: AuraColors.textSoft, size: 18),
      shape: shape,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      showCheckmark: true,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AuraColors.skyHigh,
      hintStyle: text.bodyMedium?.copyWith(color: AuraColors.textMuted),
      labelStyle: text.bodyMedium?.copyWith(color: AuraColors.textSoft),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AuraRadius.m),
        borderSide: const BorderSide(color: AuraColors.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AuraRadius.m),
        borderSide: const BorderSide(color: AuraColors.controlOutline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AuraRadius.m),
        borderSide: const BorderSide(color: AuraColors.lavender, width: 1.5),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AuraColors.skyHigh,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: AuraColors.outline,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AuraRadius.l)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AuraColors.surfaceHigh,
      contentTextStyle: text.bodyMedium,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AuraRadius.m),
      ),
    ),
    // Off switches keep a visible 3:1 track outline and a muted knob, so
    // "off" never reads as "missing" (design critique #5).
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AuraColors.onAccent
            : AuraColors.textMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AuraColors.accent
            : AuraColors.skyHigh,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AuraColors.accent
            : AuraColors.controlOutline,
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AuraColors.accent,
      thumbColor: AuraColors.starlight,
      inactiveTrackColor: AuraColors.surfaceHigh,
    ),
    dividerTheme: const DividerThemeData(color: AuraColors.hairline),
  );
}

/// A destructive action's outlined button (Delete my account): the warm
/// [AuraColors.danger] tone for text, icon and border (≥ 4.5:1 on the sky),
/// so it never looks like the lavender primary action.
ButtonStyle destructiveOutlinedButtonStyle(BuildContext context) =>
    OutlinedButton.styleFrom(
      foregroundColor: AuraColors.danger,
      disabledForegroundColor: AuraColors.textMuted,
      side: const BorderSide(color: AuraColors.danger, width: 1.5),
      minimumSize: const Size(64, 56),
    ).copyWith(
      side: WidgetStateProperty.resolveWith(
        (s) => BorderSide(
          color: s.contains(WidgetState.disabled)
              ? AuraColors.outline
              : AuraColors.danger,
          width: 1.5,
        ),
      ),
    );

/// A destructive action in a dialog: the danger tone and bold label.
ButtonStyle destructiveTextButtonStyle(BuildContext context) =>
    TextButton.styleFrom(
      foregroundColor: AuraColors.danger,
      textStyle: Theme.of(context).textTheme.labelLarge
          ?.copyWith(fontWeight: FontWeight.w700),
    );
