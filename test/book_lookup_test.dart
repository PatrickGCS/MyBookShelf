import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestordelivros/services/book_lookup_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _olBody = {
  'docs': [
    {
      'title': 'Dom Casmurro',
      'author_name': ['Machado de Assis'],
      'first_publish_year': 1899,
      'number_of_pages_median': 256,
      'publisher': ['Editora X'],
      'subject': ['Romance brasileiro'],
      'cover_i': 123,
    },
    {'title': 'Outro Livro Qualquer', 'author_name': ['Fulano']},
  ]
};

const _gbBody = {
  'items': [
    {
      'volumeInfo': {
        'title': 'Dom Casmurro',
        'authors': ['Machado de Assis'],
        'publisher': 'Outra Editora',
        'pageCount': 300,
        'categories': ['Fiction'],
        'publishedDate': '2010-05-01',
        'imageLinks': {'thumbnail': 'http://books.google.com/x?id=1&zoom=1&edge=curl'},
      }
    },
    {
      'volumeInfo': {'title': 'Dom Casmurro Ilustrado', 'authors': ['Alguém']}
    },
  ]
};

http.Response _json(Object body) =>
    http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  test('une as duas fontes, remove duplicatas e preenche campos faltantes', () async {
    final seen = <Uri>[];
    final svc = BookLookupService(client: MockClient((req) async {
      seen.add(req.url);
      return req.url.host == 'openlibrary.org' ? _json(_olBody) : _json(_gbBody);
    }));
    final r = await svc.search('Dom Casmurro');
    final dom = r.firstWhere((c) => c.title == 'Dom Casmurro');
    expect(r.where((c) => c.title == 'Dom Casmurro').length, 1); // duplicata unida
    expect(dom.sources, {'Open Library', 'Google Books'});
    expect(dom.pageCount, 256); // mantém o da primeira fonte
    expect(dom.year, 1899);
    // capas: Open Library primeiro, Google limpo (https, sem edge=curl) como reserva
    expect(dom.coverUrls.first, contains('covers.openlibrary.org/b/id/123-L.jpg'));
    expect(dom.coverUrls.last, 'https://books.google.com/x?id=1&zoom=1');
    expect(r.first.title, 'Dom Casmurro'); // mais relevante primeiro
  });

  test('autor informado entra na consulta das duas fontes', () async {
    final urls = <Uri>[];
    final svc = BookLookupService(client: MockClient((req) async {
      urls.add(req.url);
      return _json(req.url.host == 'openlibrary.org' ? _olBody : _gbBody);
    }));
    await svc.search('Dom Casmurro', author: 'Machado');
    final ol = urls.firstWhere((u) => u.host == 'openlibrary.org');
    final gb = urls.firstWhere((u) => u.host == 'www.googleapis.com');
    expect(ol.queryParameters['author'], 'Machado');
    expect(gb.queryParameters['q'], 'intitle:Dom Casmurro inauthor:Machado');
  });

  test('sem resultados com autor, repete só com o título', () async {
    var calls = 0;
    final svc = BookLookupService(client: MockClient((req) async {
      calls++;
      final hasAuthor = req.url.queryParameters.containsKey('author') ||
          (req.url.queryParameters['q'] ?? '').contains('inauthor');
      if (hasAuthor) return _json({'docs': [], 'items': []});
      return _json(req.url.host == 'openlibrary.org' ? _olBody : _gbBody);
    }));
    final r = await svc.search('Dom Casmurro', author: 'Autor Errado');
    expect(r, isNotEmpty);
    expect(calls, 4); // 2 fontes com autor + 2 fontes sem autor
  });

  test('falha de uma fonte não derruba a outra', () async {
    final svc = BookLookupService(client: MockClient((req) async {
      if (req.url.host == 'openlibrary.org') throw Exception('sem rede');
      return _json(_gbBody);
    }));
    final r = await svc.search('Dom Casmurro');
    expect(r.first.sources, {'Google Books'});
  });

  test('título vazio não faz requisições', () async {
    var calls = 0;
    final svc = BookLookupService(client: MockClient((req) async {
      calls++;
      return _json({});
    }));
    expect(await svc.search('   '), isEmpty);
    expect(calls, 0);
  });

  test('ranking prefere título exato e autor correspondente', () async {
    final svc = BookLookupService(client: MockClient((req) async {
      if (req.url.host == 'openlibrary.org') {
        return _json({
          'docs': [
            {'title': 'Guia de Dom Casmurro', 'author_name': ['Crítico']},
            {'title': 'Dom Casmurro', 'author_name': ['Machado de Assis']},
          ]
        });
      }
      return _json({'items': []});
    }));
    final r = await svc.search('dom casmurro', author: 'machado');
    expect(r.first.title, 'Dom Casmurro');
  });

  group('downloadCover', () {
    final big = Uint8List(5000);

    test('usa a primeira URL válida e detecta a extensão', () async {
      final svc = BookLookupService(client: MockClient((req) async {
        if (req.url.host == 'covers.openlibrary.org') return http.Response('', 404);
        return http.Response.bytes(big, 200, headers: {'content-type': 'image/png'});
      }));
      final c = BookCandidate(title: 'X', coverUrls: [
        'https://covers.openlibrary.org/b/id/1-L.jpg?default=false',
        'https://books.google.com/x',
      ]);
      final d = await svc.downloadCover(c);
      expect(d, isNotNull);
      expect(d!.extension, '.png');
      expect(d.bytes.length, 5000);
    });

    test('rejeita placeholders minúsculos e conteúdo que não é imagem', () async {
      final svc = BookLookupService(client: MockClient((req) async {
        if (req.url.path == '/tiny') return http.Response.bytes(Uint8List(43), 200, headers: {'content-type': 'image/gif'});
        return http.Response.bytes(big, 200, headers: {'content-type': 'text/html'});
      }));
      expect(await svc.downloadCover(BookCandidate(title: 'X', coverUrls: ['https://a.com/tiny', 'https://a.com/page'])), isNull);
    });
  });
}
