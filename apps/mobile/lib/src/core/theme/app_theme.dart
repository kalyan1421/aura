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
    (l.languageCode == 'te' || l.languageCode == 'hi') && l.scriptCode != 'Latn';

String? fontFamilyFor(Locale locale) {
  if (locale.scriptCode == 'Latn') return null;
  return switch (locale.languageCode) {
    'te' => AuraFonts.telugu,
    'hi' => AuraFonts.devanagari,
    _ => null,
  };
}

ThemeData buildAuraTheme(Locale locale) {
  final height = lineHeightFor(locale);
  final family = fontFamilyFor(locale);

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

  final base = Typography.material2021(platform: TargetPlatform.iOS).white;
  TextStyle? tune(TextStyle? s, {FontWeight? weight, double? spacing}) =>
      s?.copyWith(
        fontFamily: family,
        fontFamilyFallback: AuraFonts.fallback,
        height: height,
        color: AuraColors.text,
        fontWeight: weight ?? s.fontWeight,
        letterSpacing: spacing ?? s.letterSpacing,
      );

  final text = base.copyWith(
    displaySmall: tune(base.displaySmall, weight: FontWeight.w500, spacing: -0.5),
    headlineMedium: tune(base.headlineMedium, weight: FontWeight.w500, spacing: -0.3),
    headlineSmall: tune(base.headlineSmall, weight: FontWeight.w500, spacing: -0.2),
    titleLarge: tune(base.titleLarge, weight: FontWeight.w600),
    titleMedium: tune(base.titleMedium, weight: FontWeight.w600),
    titleSmall: tune(base.titleSmall, weight: FontWeight.w600),
    bodyLarge: tune(base.bodyLarge),
    bodyMedium: tune(base.bodyMedium),
    bodySmall: tune(base.bodySmall)?.copyWith(color: AuraColors.textSoft),
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
    chipTheme: ChipThemeData(
      backgroundColor: AuraColors.surface,
      selectedColor: AuraColors.surfaceHigh,
      side: const BorderSide(color: AuraColors.outline),
      labelStyle: text.labelLarge?.copyWith(color: AuraColors.text),
      shape: shape,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      showCheckmark: false,
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
        borderSide: const BorderSide(color: AuraColors.outline),
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
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AuraColors.onAccent
            : AuraColors.textSoft,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AuraColors.accent
            : AuraColors.surfaceHigh,
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
