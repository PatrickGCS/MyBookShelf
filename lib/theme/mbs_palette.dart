import 'package:flutter/material.dart';

/// Tokens de cor do brandbook (direção D: azul noturno + laranja de ação).
///
/// Azul estrutura a interface; laranja é reservado para ação e destaque.
/// Acesse com `MbsPalette.of(context)`.
@immutable
class MbsPalette extends ThemeExtension<MbsPalette> {
  const MbsPalette({
    required this.isDark,
    required this.bg,
    required this.text,
    required this.muted,
    required this.blue,
    required this.progress,
    required this.action,
    required this.onAction,
    required this.accent,
    required this.accentIcon,
    required this.highlight,
    required this.amber,
    required this.rose,
    required this.onRose,
    required this.paceDot,
    required this.paceNum,
    required this.glassFill,
    required this.glassFillSoft,
    required this.glassBorder,
    required this.glassSigma,
    required this.dialogFill,
    required this.track,
    required this.shadow,
    required this.blobBlue,
    required this.blobBlueOpacity,
    required this.blobOrange,
    required this.blobOrangeOpacity,
  });

  final bool isDark;

  /// Gradiente de fundo (3 paradas, diagonal).
  final List<Color> bg;
  final Color text;
  final Color muted;

  /// Azul de títulos e ícones de marca.
  final Color blue;

  /// Gradiente da barra de progresso (início → fim).
  final List<Color> progress;

  /// Gradiente do botão de ação (início → fim).
  final List<Color> action;
  final Color onAction;

  /// Laranja para bordas e barra de lombada dos botões translúcidos.
  final Color accent;
  final Color accentIcon;

  /// Laranja de texto de destaque (títulos de citação).
  final Color highlight;
  final Color amber;
  final Color rose;
  final Color onRose;
  final Color paceDot;
  final Color paceNum;

  final Color glassFill;
  final Color glassFillSoft;
  final Color glassBorder;
  final double glassSigma;

  /// Fundo quase opaco para diálogos, menus e bottom sheets.
  final Color dialogFill;
  final Color track;
  final Color shadow;
  final Color blobBlue;
  final double blobBlueOpacity;
  final Color blobOrange;
  final double blobOrangeOpacity;

  static const dark = MbsPalette(
    isDark: true,
    bg: [Color(0xFF0A1424), Color(0xFF0F1E38), Color(0xFF142A4A)],
    text: Color(0xFFEAF0FA),
    muted: Color(0xFFA9B8D0),
    blue: Color(0xFF9CC8FF),
    progress: [Color(0xFFA8D1FF), Color(0xFF4F93F0)],
    action: [Color(0xFFFFB074), Color(0xFFF2762A)],
    onAction: Color(0xFF2A1100),
    accent: Color(0xFFFF9A52),
    accentIcon: Color(0xFFFFB880),
    highlight: Color(0xFFFFA766),
    amber: Color(0xFFFFD27A),
    rose: Color(0xFFFFA3B5),
    onRose: Color(0xFF3A0A14),
    paceDot: Color(0xFF8FC4FF),
    paceNum: Color(0xFFA8D6FF),
    glassFill: Color(0x12FFFFFF),
    glassFillSoft: Color(0x0FFFFFFF),
    glassBorder: Color(0x24FFFFFF),
    glassSigma: 22,
    dialogFill: Color(0xEB0F1E38),
    track: Color(0x24FFFFFF),
    shadow: Color(0x73030814),
    blobBlue: Color(0xFF2F6BC4),
    blobBlueOpacity: 0.45,
    blobOrange: Color(0xFFFF8A3D),
    blobOrangeOpacity: 0.22,
  );

  static const light = MbsPalette(
    isDark: false,
    bg: [Color(0xFFF6F1EA), Color(0xFFEBEEF3), Color(0xFFDCE6F3)],
    text: Color(0xFF14213A),
    muted: Color(0xFF4A5873),
    blue: Color(0xFF1E4F8F),
    progress: [Color(0xFF3F7FD6), Color(0xFF1E4F8F)],
    action: [Color(0xFFFFA25C), Color(0xFFF27A2B)],
    onAction: Color(0xFF2A1100),
    accent: Color(0xFFF27A2B),
    accentIcon: Color(0xFFB4500F),
    highlight: Color(0xFFB4500F),
    amber: Color(0xFF7A4F00),
    rose: Color(0xFF9B2338),
    onRose: Color(0xFFFFFFFF),
    paceDot: Color(0xFF2F6CC0),
    paceNum: Color(0xFF1B4A87),
    glassFill: Color(0x8CFFFFFF),
    glassFillSoft: Color(0x73FFFFFF),
    glassBorder: Color(0xD9FFFFFF),
    glassSigma: 18,
    dialogFill: Color(0xE0FFFFFF),
    track: Color(0x1F14213A),
    shadow: Color(0x2428446A),
    blobBlue: Color(0xFF5B8FD6),
    blobBlueOpacity: 0.5,
    blobOrange: Color(0xFFFF9A5A),
    blobOrangeOpacity: 0.3,
  );

  static MbsPalette of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<MbsPalette>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  MbsPalette copyWith() => this;

  @override
  MbsPalette lerp(ThemeExtension<MbsPalette>? other, double t) {
    if (other is! MbsPalette) return this;
    return t < 0.5 ? this : other;
  }
}
