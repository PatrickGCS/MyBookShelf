import 'package:flutter/foundation.dart';
import '../data/database_helper.dart';
import '../models/book.dart';

/// Estado da biblioteca: lista, busca e carregamento.
class BooksProvider extends ChangeNotifier {
  List<Book> _all = [];
  String _query = '';
  bool _loading = true;

  List<Book> get allBooks => _all;
  bool get isLoading => _loading;
  String get query => _query;

  List<Book> get filteredBooks {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all
        .where((b) => b.title.toLowerCase().contains(q) || b.author.toLowerCase().contains(q))
        .toList();
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _all = await DatabaseHelper.instance.readAllBooks();
    _loading = false;
    notifyListeners();
  }

  void setQuery(String value) {
    if (value == _query) return;
    _query = value;
    notifyListeners();
  }
}
