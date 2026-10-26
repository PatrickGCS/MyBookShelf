import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/mbs_palette.dart';

/// Fundo do app: gradiente azul noturno (ou papel e névoa, no claro) com
/// duas luzes difusas, uma azul e uma laranja. O vidro só funciona sobre ele.
class MbsBackground extends StatelessWidget {
  const MbsBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = MbsPalette.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camada estática isolada: não é repintada junto com o conteúdo
        // (rolagem, transições de tela).
        RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: p.bg,
            ),
          ),
        ),
        Positioned(
          top: -110,
          right: -130,
          child: _Glow(color: p.blobBlue.withValues(alpha: p.blobBlueOpacity), size: 400),
        ),
        Positioned(
          bottom: -140,
          left: -100,
          child: _Glow(color: p.blobOrange.withValues(alpha: p.blobOrangeOpacity), size: 420),
        ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

/// Superfície de vidro: preenchimento translúcido, desfoque do fundo e borda.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.onTap,
    this.soft = false,
    this.solid = false,
    this.blur = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  /// Versão mais leve (cards de apoio).
  final bool soft;

  /// Quase opaco, para diálogos e menus (usa desfoque real).
  final bool solid;

  /// Desfoque real do que está atrás. Custa caro (uma passada extra por
  /// quadro por card); sobre o fundo liso do app o visual é igual sem ele,
  /// então só diálogos (`solid`) o usam por padrão.
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final p = MbsPalette.of(context);
    final r = BorderRadius.circular(radius);
    final fill = solid ? p.dialogFill : (soft ? p.glassFillSoft : p.glassFill);

    final Widget inner = onTap == null
        ? Padding(padding: padding, child: child)
        : Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: r,
              child: Padding(padding: padding, child: child),
            ),
          );

    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: r,
        border: Border.all(color: p.glassBorder),
      ),
      child: inner,
    );

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: r,
          boxShadow: [BoxShadow(color: p.shadow, blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: (solid || blur)
            ? ClipRRect(
                borderRadius: r,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: p.glassSigma, sigmaY: p.glassSigma),
                  child: surface,
                ),
              )
            : surface,
      ),
    );
  }
}

/// Círculo de vidro apenas visual (use dentro de um PopupMenuButton, por exemplo).
class GlassCircle extends StatelessWidget {
  const GlassCircle({super.key, required this.icon, this.size = 44, this.color, this.iconSize});
  final IconData icon;
  final double size;
  final Color? color;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final p = MbsPalette.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: p.glassFill,
        border: Border.all(color: p.glassBorder),
      ),
      child: Icon(icon, size: iconSize ?? size * 0.45, color: color ?? p.text),
    );
  }
}

/// Botão redondo de vidro (voltar, tema, citação...). Área de toque mínima de 44 px.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 44,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: size < 44 ? 44 : size,
      height: size < 44 ? 44 : size,
      child: Center(
        child: InkResponse(
          onTap: onPressed,
          radius: size / 2 + 4,
          child: GlassCircle(icon: icon, size: size, color: color),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

enum MbsTone { solid, orange, amber, blue }

/// Botão principal do card: quadrado arredondado com barra de lombada.
class SquircleButton extends StatelessWidget {
  const SquircleButton({
    super.key,
    required this.icon,
    required this.tone,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final MbsTone tone;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final p = MbsPalette.of(context);
    late final Color border;
    late final Color iconColor;
    late final Color bar;
    BoxDecoration deco;
    const radius = BorderRadius.all(Radius.circular(15));

    switch (tone) {
      case MbsTone.solid:
        border = Colors.white.withValues(alpha: p.isDark ? 0.35 : 0.6);
        iconColor = p.onAction;
        bar = p.onAction.withValues(alpha: 0.28);
        deco = BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: border),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: p.action,
          ),
          boxShadow: [BoxShadow(color: p.action[1].withValues(alpha: 0.4), blurRadius: 18, offset: const Offset(0, 8))],
        );
      case MbsTone.orange:
        border = p.accent.withValues(alpha: 0.5);
        iconColor = p.accentIcon;
        bar = p.accent.withValues(alpha: 0.55);
        deco = BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: border),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [p.action[0].withValues(alpha: 0.26), p.action[1].withValues(alpha: 0.12)],
          ),
        );
      case MbsTone.amber:
        final base = p.isDark ? p.amber : const Color(0xFFFFD27A);
        border = p.amber.withValues(alpha: 0.5);
        iconColor = p.amber;
        bar = p.amber.withValues(alpha: 0.55);
        deco = BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: border),
          color: base.withValues(alpha: p.isDark ? 0.14 : 0.35),
        );
      case MbsTone.blue:
        border = p.blue.withValues(alpha: 0.5);
        iconColor = p.blue;
        bar = p.blue.withValues(alpha: 0.55);
        deco = BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: border),
          color: p.blue.withValues(alpha: 0.14),
        );
    }

    final body = SizedBox(
      width: 46,
      height: 46,
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: deco,
          child: InkWell(
            borderRadius: radius,
            onTap: onPressed,
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(14)),
              child: Stack(
                children: [
                  Positioned(left: 0, top: 0, bottom: 0, width: 4, child: ColoredBox(color: bar)),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 3),
                      child: Icon(icon, size: 22, color: iconColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (tooltip == null) return body;
    return Tooltip(message: tooltip!, child: body);
  }
}

/// Botão de ação grande (pílula laranja em gradiente).
class MbsGradientButton extends StatelessWidget {
  const MbsGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 54,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = MbsPalette.of(context);
    final radius = BorderRadius.circular(height / 2);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: Colors.white.withValues(alpha: p.isDark ? 0.35 : 0.6)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: p.action,
            ),
            boxShadow: [BoxShadow(color: p.action[1].withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 10))],
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: onPressed,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: p.onAction),
                  const SizedBox(width: 10),
                ],
                Text(label, style: AppTheme.body(p.onAction, 15, weight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão flutuante de adicionar (60 px, laranja).
class MbsFab extends StatelessWidget {
  const MbsFab({super.key, required this.onPressed, this.tooltip = 'Adicionar livro'});
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final p = MbsPalette.of(context);
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 60,
        height: 60,
        child: Material(
          type: MaterialType.transparency,
          child: Ink(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: p.isDark ? 0.35 : 0.6)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: p.action,
              ),
              boxShadow: [BoxShadow(color: p.action[1].withValues(alpha: 0.45), blurRadius: 26, offset: const Offset(0, 12))],
            ),
            child: InkResponse(
              onTap: onPressed,
              containedInkWell: true,
              customBorder: const CircleBorder(),
              child: Icon(Icons.add_rounded, size: 30, color: p.onAction),
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra de progresso azul em gradiente.
class MbsProgressBar extends StatelessWidget {
  const MbsProgressBar({super.key, required this.value, this.height = 6});
  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = MbsPalette.of(context);
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return Semantics(
      label: 'Progresso da leitura',
      value: '${(v * 100).round()}%',
      child: ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: p.track)),
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: v,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: p.progress),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// Diálogo de vidro com a mesma API do AlertDialog (title, content, actions).
class MbsDialog extends StatelessWidget {
  const MbsDialog({super.key, this.title, this.content, this.actions = const []});
  final Widget? title;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final p = MbsPalette.of(context);
    final spaced = <Widget>[];
    for (var i = 0; i < actions.length; i++) {
      if (i > 0) spaced.add(const SizedBox(width: 8));
      spaced.add(actions[i]);
    }
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: GlassCard(
          solid: true,
          radius: 24,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null)
                DefaultTextStyle(style: AppTheme.display(p.text, 22, height: 1.3), child: title!),
              if (title != null && content != null) const SizedBox(height: 12),
              if (content != null)
                Flexible(
                  child: DefaultTextStyle(
                    style: AppTheme.body(p.muted, 13.5, height: 1.55),
                    child: content!,
                  ),
                ),
              if (spaced.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: spaced),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
