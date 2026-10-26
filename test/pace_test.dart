import 'package:flutter_test/flutter_test.dart';
import 'package:gestordelivros/models/book.dart';
import 'package:gestordelivros/widgets/pace_indicator.dart';

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
      isPaused: isPaused,
    );

void main() {
  final now = DateTime(2026, 10, 26, 15, 30);

  test('livro lido', () {
    expect(paceFor(_book(isRead: true), now: now).kind, PaceKind.done);
  });

  test('não iniciado e pausado ficam em estado neutro, com texto', () {
    final idle = paceFor(_book(), now: now);
    expect(idle.kind, PaceKind.idle);
    expect(idle.label, 'Não iniciado');

    final paused = paceFor(
      _book(startDate: DateTime(2026, 10, 1), targetDate: DateTime(2026, 11, 30), isPaused: true),
      now: now,
    );
    expect(paused.kind, PaceKind.idle);
    expect(paused.label, 'Pausado');
  });

  test('meta vencida é atraso', () {
    final b = _book(startDate: DateTime(2026, 9, 1), targetDate: DateTime(2026, 10, 1), currentPage: 50);
    final pace = paceFor(b, now: now);
    expect(pace.kind, PaceKind.late);
    expect(pace.label, 'Atrasado');
  });

  test('ritmo exigido define a faixa', () {
    // 300 páginas em 11 dias (conta o dia da meta) => 28 pág/dia: no ritmo.
    final easy = _book(startDate: DateTime(2026, 10, 1), targetDate: DateTime(2026, 11, 5));
    expect(paceFor(easy, now: now).kind, PaceKind.onTrack);

    // 300 páginas em 6 dias => 50 pág/dia: acelerar.
    final fast = _book(startDate: DateTime(2026, 10, 1), targetDate: DateTime(2026, 10, 31));
    final p = paceFor(fast, now: now);
    expect(p.kind, PaceKind.speedUp);
    expect(p.number, '50');
  });
}
