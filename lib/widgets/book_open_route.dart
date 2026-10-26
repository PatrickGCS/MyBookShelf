import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/mbs_palette.dart';

/// Rota que abre o leitor com a animação do livro (1,5 s ao abrir e ao fechar).
///
/// Etapas ao abrir: (1) o livro vai ao centro; (2) a capa gira como uma
/// folha; (3) o livro cresce e o leitor aparece. Ao voltar, a ordem se inverte.
/// Com animações reduzidas no sistema, vira um fade curto de 150 ms.
class BookOpenRoute<T> extends PageRoute<T> {
  BookOpenRoute({
    required this.builder,
    required this.cover,
    this.reduceMotion = false,
    super.settings,
  });

  final WidgetBuilder builder;

  /// Capa do livro (124 × 186) que será animada.
  final Widget cover;
  final bool reduceMotion;

  @override
  Duration get transitionDuration =>
      reduceMotion ? const Duration(milliseconds: 150) : const Duration(milliseconds: 1500);

  @override
  Duration get reverseTransitionDuration => transitionDuration;

  @override
  bool get opaque => true;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (reduceMotion) {
      return FadeTransition(opacity: animation, child: child);
    }
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, readerChild) {
        final t = animation.value;
        final readerOpacity = Curves.easeOut.transform(((t - 0.6) / 0.4).clamp(0.0, 1.0));
        return Stack(
          fit: StackFit.expand,
          children: [
            Opacity(opacity: readerOpacity, child: RepaintBoundary(child: readerChild)),
            if (t < 0.999) IgnorePointer(child: _BookOverlay(t: t, cover: cover)),
          ],
        );
      },
    );
  }
}

class _BookOverlay extends StatelessWidget {
  const _BookOverlay({required this.t, required this.cover});
  final double t;
  final Widget cover;

  @override
  Widget build(BuildContext context) {
    final move = Curves.easeInOutCubic.transform((t / 0.27).clamp(0.0, 1.0));
    final open = Curves.easeInOut.transform(((t - 0.27) / 0.40).clamp(0.0, 1.0));
    final grow = Curves.easeInOutCubic.transform(((t - 0.67) / 0.33).clamp(0.0, 1.0));
    final scale = 1.0 + 0.4 * move + 1.2 * grow;
    final fade = grow > 0.6 ? 1.0 - (grow - 0.6) / 0.4 : 1.0;
    final scrim = 0.35 * math.min(move * 2, 1.0) * (1 - grow);

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Colors.black.withValues(alpha: scrim)),
        Opacity(
          opacity: fade.clamp(0.0, 1.0),
          child: Align(
            alignment: Alignment(0, -0.45 * (1 - move)),
            child: Transform.scale(
              scale: scale,
              child: Transform.translate(
                offset: Offset(62 * open, 0),
                child: _OpeningBook(angle: -172 * math.pi / 180 * open, cover: cover),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OpeningBook extends StatelessWidget {
  const _OpeningBook({required this.angle, required this.cover});
  final double angle;
  final Widget cover;

  @override
  Widget build(BuildContext context) {
    final p = MbsPalette.of(context);
    const w = 124.0;
    const h = 186.0;
    final paper = p.isDark ? const Color(0xFFE9E2D4) : const Color(0xFFF7F3EC);
    final pastHalf = angle.abs() > math.pi / 2;

    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Miolo (páginas).
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: paper,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(14), left: Radius.circular(3)),
                boxShadow: const [BoxShadow(color: Color(0x66030814), blurRadius: 24, offset: Offset(0, 12))],
              ),
            ),
          ),
          // Capa girando em torno da lombada (borda esquerda).
          Positioned.fill(
            child: Transform(
              alignment: Alignment.centerLeft,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(angle),
              child: pastHalf
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        color: paper.withValues(alpha: 1),
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(14), right: Radius.circular(3)),
                      ),
                    )
                  : SizedBox(width: w, height: h, child: cover),
            ),
          ),
        ],
      ),
    );
  }
}
