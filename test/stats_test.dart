import 'package:flutter_test/flutter_test.dart';
import 'package:gestordelivros/models/book.dart';
import 'package:gestordelivros/services/stats_service.dart';

Book _b(int id, {bool read = false, int cur = 0, String genre = 'Romance', double rating = 0, double price = 10}) => Book(
      id: id, title: 'T$id', author: 'A', publisher: 'P', genre: genre, pageCount: 100,
      currentPage: cur, price: price, isRead: read, dateAcquired: DateTime(2026, 1, 1), rating: rating,
      startDate: DateTime(2026, 1, 2),
    );

ReadingSession _s(int book, DateTime d, int page) => ReadingSession(bookId: book, date: d, pageStopped: page);

void main() {
  final now = DateTime(2026, 10, 26, 20);

  test('páginas por sessão = avanço sobre a sessão anterior do mesmo livro', () {
    final r = LibraryStats.pagesBySession([
      _s(1, DateTime(2026, 10, 24), 30),
      _s(1, DateTime(2026, 10, 25), 50),
      _s(2, DateTime(2026, 10, 25), 10),
    ]);
    expect(r.map((e) => e.value).toList()..sort(), [10, 20, 30]);
  });

  test('sequência atual termina hoje ou ontem', () {
    final withToday = LibraryStats.compute([], [
      _s(1, DateTime(2026, 10, 24, 9), 10),
      _s(1, DateTime(2026, 10, 25, 9), 20),
      _s(1, DateTime(2026, 10, 26, 9), 30),
    ], now: now);
    expect(withToday.currentStreak, 3);
    expect(withToday.readToday, true);

    final endsYesterday = LibraryStats.compute([], [
      _s(1, DateTime(2026, 10, 24), 10),
      _s(1, DateTime(2026, 10, 25), 20),
    ], now: now);
    expect(endsYesterday.currentStreak, 2);
    expect(endsYesterday.readToday, false);

    final broken = LibraryStats.compute([], [_s(1, DateTime(2026, 10, 20), 10)], now: now);
    expect(broken.currentStreak, 0);
  });

  test('maior sequência histórica e dias nos últimos 30', () {
    final r = LibraryStats.compute([], [
      for (final d in [1, 2, 3, 4, 10, 11, 25, 26]) _s(1, DateTime(2026, 10, d), d),
    ], now: now);
    expect(r.longestStreak, 4);
    expect(r.currentStreak, 2);
    expect(r.daysReadLast30, 8);
  });

  test('totais, gêneros e nota média', () {
    final r = LibraryStats.compute([
      _b(1, read: true, rating: 4, genre: 'Fantasia'),
      _b(2, cur: 40, genre: 'Fantasia', price: 5),
      _b(3, read: true, rating: 5),
    ], [], now: now);
    expect(r.totalBooks, 3);
    expect(r.readBooks, 2);
    expect(r.totalPagesRead, 240); // 100 + 40 + 100
    expect(r.averageRating, 4.5);
    expect(r.totalSpent, 25);
    expect(r.genreCounts.first.key, 'Fantasia');
    expect(r.pagesPerDay.length, 14);
  });
}
