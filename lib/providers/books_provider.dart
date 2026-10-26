import 'package:flutter/foundation.dart';
import '../data/database_helper.dart';
import '../models/book.dart';
import '../utils/text_utils.dart';

enum StatusFilter { all, reading, notStarted, read, paused }

enum BookSort { title, author, progress, acquired, deadline, rating }

extension StatusFilterLabel on StatusFilter {
  String get label => switch (this) {
        StatusFilter.all => 'Todos',
        StatusFilter.reading => 'Lendo',
        StatusFilter.notStarted => 'Não iniciados',
        StatusFilter.read => 'Lidos',
        StatusFilter.paused => 'Pausados',
      };
}

extension BookSortLabel on BookSort {
  String get label => switch (this) {
        BookSort.title => 'Título',
        BookSort.author => 'Autor',
        BookSort.progress => 'Progresso',
        BookSort.acquired => 'Data de aquisição',
        BookSort.deadline => 'Prazo da meta',
        BookSort.rating => 'Avaliação',
      };

  /// Direção natural: texto A→Z; prazo mais próximo primeiro; demais, maior primeiro.
  bool get defaultAscending =>
      this == BookSort.title || this == BookSort.author || this == BookSort.deadline;
}

bool matchesStatus(Book b, StatusFilter f) => switch (f) {
      StatusFilter.all => true,
      StatusFilter.read => b.isRead,
      StatusFilter.paused => !b.isRead && b.isPaused,
      StatusFilter.reading => !b.isRead && !b.isPaused && b.startDate != null,
      StatusFilter.notStarted => !b.isRead && b.startDate == null,
    };

/// Estado da biblioteca: lista, busca, filtros, ordenação e carregamento.
class BooksProvider extends ChangeNotifier {
  List<Book> _all = [];
  String _query = '';
  bool _loading = true;
  StatusFilter _status = StatusFilter.all;
  String? _genre;
  BookSort _sort = BookSort.title;
  bool _ascending = true;

  List<Book> get allBooks => _all;
  bool get isLoading => _loading;
  String get query => _query;
  StatusFilter get status => _status;
  String? get genre => _genre;
  BookSort get sort => _sort;
  bool get ascending => _ascending;

  bool get hasActiveFilters => _status != StatusFilter.all || _genre != null || _query.trim().isNotEmpty;

  /// Gêneros existentes (ordenados), para o filtro.
  List<String> get genres {
    final set = _all.map((b) => b.genre.trim()).where((g) => g.isNotEmpty).toSet().toList();
    set.sort((a, b) => normalizeText(a).compareTo(normalizeText(b)));
    return set;
  }

  int countFor(StatusFilter f) => _all.where((b) => matchesStatus(b, f)).length;

  List<Book> get filteredBooks {
    final q = normalizeText(_query.trim());
    final list = _all.where((b) {
      if (!matchesStatus(b, _status)) return false;
      if (_genre != null && b.genre.trim() != _genre) return false;
      if (q.isEmpty) return true;
      return normalizeText(b.title).contains(q) ||
          normalizeText(b.author).contains(q) ||
          normalizeText(b.genre).contains(q);
    }).toList();
    list.sort(_compare);
    return list;
  }

  int _compare(Book a, Book b) {
    int r;
    switch (_sort) {
      case BookSort.title:
        r = normalizeText(a.title).compareTo(normalizeText(b.title));
      case BookSort.author:
        r = normalizeText(a.author).compareTo(normalizeText(b.author));
      case BookSort.progress:
        r = a.progress.compareTo(b.progress);
      case BookSort.acquired:
        r = a.dateAcquired.compareTo(b.dateAcquired);
      case BookSort.rating:
        r = a.rating.compareTo(b.rating);
      case BookSort.deadline:
        // Livros sem meta ficam sempre no fim, independentemente da direção
        if (a.targetDate == null && b.targetDate == null) return 0;
        if (a.targetDate == null) return 1;
        if (b.targetDate == null) return -1;
        r = a.targetDate!.compareTo(b.targetDate!);
    }
    return _ascending ? r : -r;
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _all = await DatabaseHelper.instance.readAllBooks();
    // Se o gênero filtrado deixou de existir, limpa o filtro
    if (_genre != null && !genres.contains(_genre)) _genre = null;
    _loading = false;
    notifyListeners();
  }

  void setQuery(String value) {
    if (value == _query) return;
    _query = value;
    notifyListeners();
  }

  void setStatus(StatusFilter value) {
    _status = value;
    notifyListeners();
  }

  void setGenre(String? value) {
    _genre = value;
    notifyListeners();
  }

  void setSort(BookSort value) {
    if (value == _sort) {
      _ascending = !_ascending;
    } else {
      _sort = value;
      _ascending = value.defaultAscending;
    }
    notifyListeners();
  }

  void clearFilters() {
    _status = StatusFilter.all;
    _genre = null;
    _query = '';
    notifyListeners();
  }
}
