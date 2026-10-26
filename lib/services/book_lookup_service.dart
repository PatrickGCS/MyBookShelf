import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../utils/text_utils.dart';

/// Resultado de busca de livro em uma fonte pública.
class BookCandidate {
  BookCandidate({
    required this.title,
    this.authors = const [],
    this.publisher,
    this.pageCount,
    this.genre,
    this.year,
    this.previewUrl,
    List<String>? coverUrls,
    Set<String>? sources,
  })  : coverUrls = coverUrls ?? [],
        sources = sources ?? {};

  final String title;
  final List<String> authors;
  String? publisher;
  int? pageCount;
  String? genre;
  int? year;

  /// Miniatura para a lista de resultados.
  String? previewUrl;

  /// URLs de capa em ordem de preferência (a primeira que funcionar é usada).
  final List<String> coverUrls;
  final Set<String> sources;

  bool get hasCover => coverUrls.isNotEmpty;
  String get authorText => authors.join(', ');

  /// Chave para detectar o mesmo livro vindo de fontes diferentes.
  String get key => '${normalizeText(title)}|${authors.isEmpty ? '' : normalizeText(authors.first)}';

  /// Completa campos vazios com os de [other] (mesmo livro, outra fonte).
  void mergeFrom(BookCandidate other) {
    publisher ??= other.publisher;
    pageCount ??= other.pageCount;
    genre ??= other.genre;
    year ??= other.year;
    previewUrl ??= other.previewUrl;
    for (final u in other.coverUrls) {
      if (!coverUrls.contains(u)) coverUrls.add(u);
    }
    sources.addAll(other.sources);
  }
}

class DownloadedCover {
  DownloadedCover(this.bytes, this.extension);
  final Uint8List bytes;
  final String extension;
}

/// Busca livros e capas em Open Library e Google Books (APIs públicas, sem chave).
class BookLookupService {
  BookLookupService({http.Client? client, this.timeout = const Duration(seconds: 10)})
      : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  static const _headers = {'User-Agent': 'MyBookShelf/1.0 (aplicativo pessoal de biblioteca)'};

  /// Busca pelo [title]; se [author] for informado, refina a busca.
  /// Se o refinamento não achar nada, repete só com o título.
  Future<List<BookCandidate>> search(String title, {String? author}) async {
    final t = title.trim();
    final a = author?.trim() ?? '';
    if (t.isEmpty) return [];

    var results = await _searchBoth(t, a);
    if (results.isEmpty && a.isNotEmpty) {
      results = await _searchBoth(t, '');
    }
    return _rank(results, t, a);
  }

  Future<List<BookCandidate>> _searchBoth(String title, String author) async {
    // As duas fontes em paralelo; falha de uma não derruba a outra
    final lists = await Future.wait([
      _openLibrary(title, author).catchError((_) => <BookCandidate>[]),
      _googleBooks(title, author).catchError((_) => <BookCandidate>[]),
    ]);
    final merged = <String, BookCandidate>{};
    for (final c in [...lists[0], ...lists[1]]) {
      final existing = merged[c.key];
      if (existing == null) {
        merged[c.key] = c;
      } else {
        existing.mergeFrom(c);
      }
    }
    return merged.values.toList();
  }

  Future<List<BookCandidate>> _openLibrary(String title, String author) async {
    final uri = Uri.https('openlibrary.org', '/search.json', {
      'title': title,
      if (author.isNotEmpty) 'author': author,
      'limit': '15',
      'fields': 'title,author_name,first_publish_year,number_of_pages_median,publisher,subject,cover_i',
    });
    final res = await _client.get(uri, headers: _headers).timeout(timeout);
    if (res.statusCode != 200) return [];
    final docs = (jsonDecode(utf8.decode(res.bodyBytes))['docs'] as List?) ?? [];
    final out = <BookCandidate>[];
    for (final d in docs.whereType<Map>()) {
      final name = d['title'];
      if (name is! String || name.isEmpty) continue;
      final coverId = d['cover_i'];
      final publishers = (d['publisher'] as List?)?.whereType<String>().toList();
      final subjects = (d['subject'] as List?)?.whereType<String>().toList();
      out.add(BookCandidate(
        title: name,
        authors: (d['author_name'] as List?)?.whereType<String>().toList() ?? [],
        publisher: (publishers != null && publishers.isNotEmpty) ? publishers.first : null,
        pageCount: d['number_of_pages_median'] is int ? d['number_of_pages_median'] as int : null,
        genre: (subjects != null && subjects.isNotEmpty) ? subjects.first : null,
        year: d['first_publish_year'] is int ? d['first_publish_year'] as int : null,
        previewUrl: coverId is int ? 'https://covers.openlibrary.org/b/id/$coverId-M.jpg?default=false' : null,
        // default=false => 404 quando não há capa (em vez de uma imagem em branco)
        coverUrls: coverId is int ? ['https://covers.openlibrary.org/b/id/$coverId-L.jpg?default=false'] : [],
        sources: {'Open Library'},
      ));
    }
    return out;
  }

  Future<List<BookCandidate>> _googleBooks(String title, String author) async {
    final q = 'intitle:$title${author.isNotEmpty ? ' inauthor:$author' : ''}';
    final uri = Uri.https('www.googleapis.com', '/books/v1/volumes', {
      'q': q,
      'maxResults': '15',
      'printType': 'books',
    });
    final res = await _client.get(uri, headers: _headers).timeout(timeout);
    if (res.statusCode != 200) return [];
    final items = (jsonDecode(utf8.decode(res.bodyBytes))['items'] as List?) ?? [];
    final out = <BookCandidate>[];
    for (final it in items.whereType<Map>()) {
      final v = it['volumeInfo'];
      if (v is! Map || v['title'] is! String) continue;
      final links = v['imageLinks'];
      String? thumb;
      if (links is Map) {
        thumb = _cleanGoogleUrl((links['thumbnail'] ?? links['smallThumbnail']) as String?);
      }
      final cats = (v['categories'] as List?)?.whereType<String>().toList();
      final date = v['publishedDate'] as String?;
      out.add(BookCandidate(
        title: v['title'] as String,
        authors: (v['authors'] as List?)?.whereType<String>().toList() ?? [],
        publisher: v['publisher'] as String?,
        pageCount: v['pageCount'] is int && (v['pageCount'] as int) > 0 ? v['pageCount'] as int : null,
        genre: (cats != null && cats.isNotEmpty) ? cats.first : null,
        year: date != null && date.length >= 4 ? int.tryParse(date.substring(0, 4)) : null,
        previewUrl: thumb,
        coverUrls: thumb != null ? [thumb] : [],
        sources: {'Google Books'},
      ));
    }
    return out;
  }

  /// Google devolve http e um efeito de "página dobrada" (edge=curl) nas capas.
  static String? _cleanGoogleUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    return url.replaceFirst('http://', 'https://').replaceAll('&edge=curl', '');
  }

  /// Ordena por relevância: título exato > começa com > contém; autor bate; tem capa.
  List<BookCandidate> _rank(List<BookCandidate> list, String title, String author) {
    final t = normalizeText(title);
    final a = normalizeText(author);
    int score(BookCandidate c) {
      final ct = normalizeText(c.title);
      var s = 0;
      if (ct == t) {
        s += 100;
      } else if (ct.startsWith(t)) {
        s += 60;
      } else if (ct.contains(t)) {
        s += 30;
      }
      if (a.isNotEmpty && c.authors.any((x) => normalizeText(x).contains(a))) s += 50;
      if (c.hasCover) s += 20;
      if (c.sources.length > 1) s += 10; // confirmado por duas fontes
      return s;
    }

    final sorted = [...list]..sort((x, y) => score(y).compareTo(score(x)));
    return sorted.take(10).toList();
  }

  /// Baixa a capa tentando cada URL até uma válida (imagem de tamanho plausível).
  Future<DownloadedCover?> downloadCover(BookCandidate c) async {
    for (final url in c.coverUrls) {
      try {
        final res = await _client.get(Uri.parse(url), headers: _headers).timeout(timeout);
        if (res.statusCode != 200) continue;
        final type = res.headers['content-type'] ?? '';
        if (!type.startsWith('image/')) continue;
        if (res.bodyBytes.length < 2000) continue; // placeholders/ícones vazios
        final ext = type.contains('png') ? '.png' : (type.contains('webp') ? '.webp' : '.jpg');
        return DownloadedCover(res.bodyBytes, ext);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  void dispose() => _client.close();
}
