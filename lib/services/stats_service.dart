import 'package:flutter/material.dart' show DateUtils;
import '../models/book.dart';

/// Estatísticas calculadas a partir dos livros e das sessões de leitura.
class LibraryStats {
  LibraryStats({
    required this.totalBooks,
    required this.readBooks,
    required this.readingBooks,
    required this.pausedBooks,
    required this.notStartedBooks,
    required this.totalPagesRead,
    required this.totalSpent,
    required this.averageRating,
    required this.genreCounts,
    required this.pagesPerDay,
    required this.currentStreak,
    required this.longestStreak,
    required this.daysReadLast30,
    required this.readToday,
  });

  final int totalBooks, readBooks, readingBooks, pausedBooks, notStartedBooks;
  final int totalPagesRead;
  final double totalSpent;
  final double averageRating;

  /// Gêneros ordenados do mais para o menos frequente.
  final List<MapEntry<String, int>> genreCounts;

  /// Páginas lidas por dia nos últimos [days] dias (do mais antigo ao de hoje).
  final List<MapEntry<DateTime, int>> pagesPerDay;

  final int currentStreak, longestStreak, daysReadLast30;
  final bool readToday;

  /// Páginas lidas em cada sessão = avanço em relação à sessão anterior do mesmo livro.
  static List<MapEntry<DateTime, int>> pagesBySession(List<ReadingSession> sessions) {
    final byBook = <int, List<ReadingSession>>{};
    for (final s in sessions) {
      byBook.putIfAbsent(s.bookId, () => []).add(s);
    }
    final out = <MapEntry<DateTime, int>>[];
    for (final list in byBook.values) {
      list.sort((a, b) => a.date.compareTo(b.date));
      var prev = 0;
      for (final s in list) {
        final delta = s.pageStopped - prev;
        out.add(MapEntry(s.date, delta > 0 ? delta : 0));
        prev = s.pageStopped;
      }
    }
    return out;
  }

  static LibraryStats compute(
    List<Book> books,
    List<ReadingSession> sessions, {
    DateTime? now,
    int days = 14,
  }) {
    final today = DateUtils.dateOnly(now ?? DateTime.now());

    // --- livros ---
    final read = books.where((b) => b.isRead).toList();
    final rated = read.where((b) => b.rating > 0).toList();
    final genres = <String, int>{};
    for (final b in books) {
      final g = b.genre.trim().isEmpty ? 'Sem gênero' : b.genre.trim();
      genres[g] = (genres[g] ?? 0) + 1;
    }
    final genreList = genres.entries.toList()
      ..sort((a, b) => b.value != a.value ? b.value.compareTo(a.value) : a.key.compareTo(b.key));

    // --- sessões ---
    final perDay = <DateTime, int>{};
    for (final e in pagesBySession(sessions)) {
      final d = DateUtils.dateOnly(e.key);
      perDay[d] = (perDay[d] ?? 0) + e.value;
    }
    final activeDays = {for (final s in sessions) DateUtils.dateOnly(s.date)};

    final series = [
      for (var i = days - 1; i >= 0; i--)
        MapEntry(today.subtract(Duration(days: i)), perDay[today.subtract(Duration(days: i))] ?? 0),
    ];

    // Sequência atual: dias consecutivos terminando hoje (ou ontem, se ainda não leu hoje)
    var cursor = activeDays.contains(today) ? today : today.subtract(const Duration(days: 1));
    var current = 0;
    while (activeDays.contains(cursor)) {
      current++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    // Maior sequência histórica
    final sorted = activeDays.toList()..sort();
    var longest = 0, run = 0;
    DateTime? last;
    for (final d in sorted) {
      run = (last != null && d.difference(last).inDays == 1) ? run + 1 : 1;
      if (run > longest) longest = run;
      last = d;
    }

    final windowStart = today.subtract(const Duration(days: 29));
    final last30 = activeDays.where((d) => !d.isBefore(windowStart) && !d.isAfter(today)).length;

    return LibraryStats(
      totalBooks: books.length,
      readBooks: read.length,
      readingBooks: books.where((b) => !b.isRead && !b.isPaused && b.startDate != null).length,
      pausedBooks: books.where((b) => !b.isRead && b.isPaused).length,
      notStartedBooks: books.where((b) => !b.isRead && b.startDate == null).length,
      totalPagesRead: books.fold<int>(0, (sum, b) => sum + (b.isRead ? b.pageCount : b.currentPage)),
      totalSpent: books.fold<double>(0, (sum, b) => sum + b.price),
      averageRating: rated.isEmpty ? 0 : rated.fold<double>(0, (s, b) => s + b.rating) / rated.length,
      genreCounts: genreList,
      pagesPerDay: series,
      currentStreak: current,
      longestStreak: longest,
      daysReadLast30: last30,
      readToday: activeDays.contains(today),
    );
  }
}
