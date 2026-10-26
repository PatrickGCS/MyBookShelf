import 'package:flutter/material.dart';
import 'mbs_palette.dart';

/// Controle global do tema (claro/escuro/sistema).
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

/// Tema do brandbook "Marinho e Laranja".
///
/// Títulos e números: Fraunces. Texto de leitura e interface: Roboto Serif.
class AppTheme {
  static ThemeData get light => _build(MbsPalette.light);
  static ThemeData get dark => _build(MbsPalette.dark);

  /// Estilo da fonte de destaque (Fraunces).
  static TextStyle display(Color color, double size, {double height = 1.25}) =>
      TextStyle(
        fontFamily: 'Fraunces',
        fontSize: size,
        fontWeight: FontWeight.w400,
        fontVariations: const [FontVariation('wght', 400)],
        color: color,
        height: height,
      );

  /// Estilo do texto de interface (Roboto Serif).
  static TextStyle body(Color color, double size,
          {FontWeight weight = FontWeight.w400, double? height, FontStyle? style}) =>
      TextStyle(
        fontFamily: 'RobotoSerif',
        fontSize: size,
        fontWeight: weight,
        fontVariations: [FontVariation('wght', weight.value.toDouble())],
        color: color,
        height: height,
        fontStyle: style,
      );

  static ThemeData _build(MbsPalette p) {
    final brightness = p.isDark ? Brightness.dark : Brightness.light;
    final base = ThemeData(brightness: brightness, useMaterial3: true);

    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.action[1],
      onPrimary: p.onAction,
      secondary: p.blue,
      onSecondary: p.isDark ? const Color(0xFF0A1424) : Colors.white,
      error: p.rose,
      onError: p.onRose,
      surface: p.bg[1],
      onSurface: p.text,
      onSurfaceVariant: p.muted,
      outline: p.glassBorder,
    );

    final roboto = base.textTheme
        .apply(fontFamily: 'RobotoSerif', bodyColor: p.text, displayColor: p.text);
    final textTheme = roboto.copyWith(
      headlineLarge: display(p.text, 32),
      headlineMedium: display(p.text, 28),
      headlineSmall: display(p.text, 24),
      titleLarge: display(p.text, 20),
    );

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c, width: w),
        );

    final stadium = const StadiumBorder();

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      extensions: <ThemeExtension<dynamic>>[p],
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg[0],
      textTheme: textTheme,
      iconTheme: IconThemeData(color: p.text),
      dividerTheme: DividerThemeData(color: p.glassBorder),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.glassFill,
        border: border(p.glassBorder),
        enabledBorder: border(p.glassBorder),
        focusedBorder: border(p.blue, 1.5),
        labelStyle: body(p.muted, 14),
        hintStyle: body(p.muted, 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.action[1],
          foregroundColor: p.onAction,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: stadium,
          textStyle: body(p.onAction, 14, weight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.text,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: stadium,
          textStyle: body(p.text, 14, weight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.text,
          minimumSize: const Size(0, 44),
          side: BorderSide(color: p.glassBorder),
          shape: stadium,
          textStyle: body(p.text, 14, weight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.isDark ? const Color(0xFF1B3358) : const Color(0xFF14213A),
        contentTextStyle: body(Colors.white, 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.isDark ? const Color(0xFF16294A) : const Color(0xFFF6F8FC),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: p.glassBorder),
        ),
        textStyle: body(p.text, 14),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.blue),
    );
  }
}
