import 'package:flutter/material.dart';
import '../models/book.dart';
import '../theme/app_theme.dart';
import '../theme/mbs_palette.dart';

enum PaceKind { onTrack, speedUp, late, idle, done }

/// Estado de ritmo de leitura de um livro, derivado das regras do modelo.
class BookPace {
  const BookPace(this.kind, this.label, {this.number});
  final PaceKind kind;

  /// Número em destaque (páginas por dia), quando existir.
  final String? number;

  /// Texto: "pág/dia" quando há número; senão a palavra do estado.
  final String label;
}

BookPace paceFor(Book b, {DateTime? now}) {
  if (b.isRead) return const BookPace(PaceKind.done, 'Lido');
  if (b.startDate == null) return const BookPace(PaceKind.idle, 'Não iniciado');
  if (b.isPaused) return const BookPace(PaceKind.idle, 'Pausado');
  if (b.targetDate == null) return const BookPace(PaceKind.idle, 'Sem meta');
  if (b.isOverdue(now: now)) return const BookPace(PaceKind.late, 'Atrasado');
  final pace = b.requiredPace(now: now);
  if (pace > 100) return BookPace(PaceKind.late, 'pág/dia', number: '$pace');
  if (pace > 30) return BookPace(PaceKind.speedUp, 'pág/dia', number: '$pace');
  return BookPace(PaceKind.onTrack, 'pág/dia', number: '$pace');
}

/// Indicador de ritmo: ponto com halo + numeral em Fraunces + unidade.
/// A cor nunca comunica sozinha: sempre há número ou palavra.
class PaceIndicator extends StatelessWidget {
  const PaceIndicator({super.key, required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    final p = MbsPalette.of(context);
    final pace = paceFor(book);

    late final Color dot;
    late final Color strong;
    switch (pace.kind) {
      case PaceKind.onTrack:
      case PaceKind.done:
        dot = p.paceDot;
        strong = p.paceNum;
      case PaceKind.speedUp:
        dot = p.amber;
        strong = p.amber;
      case PaceKind.late:
        dot = p.rose;
        strong = p.rose;
      case PaceKind.idle:
        dot = p.muted;
        strong = p.muted;
    }

    final Widget text;
    if (pace.number != null) {
      text = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(pace.number!, style: AppTheme.display(strong, 18, height: 1)),
          const SizedBox(width: 4),
          Text(pace.label, style: AppTheme.body(p.muted, 12)),
        ],
      );
    } else {
      final bold = pace.kind == PaceKind.late || pace.kind == PaceKind.done;
      text = Text(
        pace.label,
        style: AppTheme.body(strong, 12, weight: bold ? FontWeight.w700 : FontWeight.w400),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dot,
            boxShadow: [BoxShadow(color: dot.withValues(alpha: 0.22), spreadRadius: 3)],
          ),
        ),
        const SizedBox(width: 10),
        text,
      ],
    );
  }
}
