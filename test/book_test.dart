import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestordelivros/models/book.dart';

Book _book({
  int pageCount = 300,
  int currentPage = 0,
  DateTime? startDate,
  DateTime? targetDate,
  bool isRead = false,
  bool isPaused = false,
}) =>
    Book(
      id: 1, title: 'T', author: 'A', publisher: 'P', genre: 'G',
      pageCount: pageCount, currentPage: currentPage, price: 10, isRead: isRead,
      dateAcquired: DateTime(2026, 1, 1), startDate: startDate, targetDate: targetDate,
      isPaused: isPaused, rating: 4, review: 'ótimo',
    );

void main() {
  final now = DateTime(2026, 10, 26, 15, 30);

  group('copyWith', () {
    test('preserva nota, resenha e pausa', () {
      final b = _book(isPaused: true).copyWith(currentPage: 50);
      expect(b.currentPage, 50);
      expect(b.rating, 4);
      expect(b.review, 'ótimo');
      expect(b.isPaused, true);
    });
    test('clear* anula campos opcionais', () {
      final b = _book(targetDate: now).copyWith(clearTargetDate: true);
      expect(b.targetDate, isNull);
    });
  });

  group('urgência', () {
    test('meta hoje não é atrasada, mesmo com horário passado', () {
      final b = _book(startDate: now, targetDate: DateTime(2026, 10, 26, 8));
      expect(b.isOverdue(now: now), false);
      expect(b.getUrgencyText(now: now), '300 pág/dia');
    });
    test('meta ontem é atrasada (cor e texto coerentes)', () {
      final b = _book(startDate: now, targetDate: DateTime(2026, 10, 25));
      expect(b.getUrgencyText(now: now), 'Atrasado!');
      expect(b.getUrgencyColor(now: now), Colors.red);
    });
    test('ritmo confortável é verde, médio é laranja, alto é vermelho', () {
      final t = DateTime(2026, 11, 4); // 9 dias + dia da meta = 10
      expect(_book(startDate: now, targetDate: t).getUrgencyColor(now: now), Colors.green); // 30/dia
      expect(_book(pageCount: 400, startDate: now, targetDate: t).getUrgencyColor(now: now), Colors.orange);
      expect(_book(pageCount: 1500, startDate: now, targetDate: t).getUrgencyColor(now: now), Colors.red);
    });
    test('concluído e pausado têm prioridade', () {
      expect(_book(isRead: true).getUrgencyText(now: now), 'Concluído');
      expect(_book(isPaused: true).getUrgencyColor(now: now), Colors.grey);
    });
  });
}
