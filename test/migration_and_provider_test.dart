import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestordelivros/data/database_helper.dart';
import 'package:gestordelivros/models/book.dart';
import 'package:gestordelivros/providers/books_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('mbs_mig_');
  });
  tearDown(() async {
    await DatabaseHelper.instance.close();
    await tmp.delete(recursive: true);
  });

  test('migração v2 -> v3 preserva livros e adiciona epubCfi', () async {
    final path = p.join(tmp.path, 'v2.db');
    final old = await openDatabase(path, version: 2, onCreate: (db, v) async {
      await db.execute('''CREATE TABLE books (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL,
        author TEXT NOT NULL, publisher TEXT NOT NULL, genre TEXT NOT NULL, pageCount INTEGER NOT NULL,
        currentPage INTEGER DEFAULT 0, price REAL NOT NULL, isRead BOOLEAN NOT NULL, dateAcquired TEXT NOT NULL,
        startDate TEXT, targetDate TEXT, imagePath TEXT, rating REAL DEFAULT 0.0, review TEXT,
        isPaused BOOLEAN DEFAULT 0, lastPauseDate TEXT, ebookPath TEXT)''');
      await db.execute('CREATE TABLE reading_sessions (id INTEGER PRIMARY KEY AUTOINCREMENT, bookId INTEGER NOT NULL, date TEXT NOT NULL, pageStopped INTEGER NOT NULL)');
      await db.execute('CREATE TABLE quotes (id INTEGER PRIMARY KEY AUTOINCREMENT, bookId INTEGER NOT NULL, text TEXT NOT NULL, page INTEGER NOT NULL)');
    });
    await old.insert('books', {
      'title': 'Antigo', 'author': 'A', 'publisher': 'P', 'genre': 'G', 'pageCount': 10,
      'price': 1.0, 'isRead': 0, 'dateAcquired': DateTime(2026, 1, 1).toIso8601String(),
    });
    await old.close();

    await DatabaseHelper.instance.useDatabaseAt(path);
    final books = await DatabaseHelper.instance.readAllBooks();
    expect(books.single.title, 'Antigo');
    expect(books.single.epubCfi, isNull);

    final updated = books.single.copyWith(epubCfi: 'epubcfi(/6/4)');
    await DatabaseHelper.instance.update(updated);
    expect((await DatabaseHelper.instance.readAllBooks()).single.epubCfi, 'epubcfi(/6/4)');
  });

  test('BooksProvider filtra por título/autor sem diferenciar maiúsculas', () async {
    await DatabaseHelper.instance.useDatabaseAt(p.join(tmp.path, 'prov.db'));
    Book b(String t, String a) => Book(
        title: t, author: a, publisher: 'P', genre: 'G', pageCount: 10, price: 1,
        isRead: false, dateAcquired: DateTime(2026, 1, 1));
    await DatabaseHelper.instance.create(b('Dom Casmurro', 'Machado de Assis'));
    await DatabaseHelper.instance.create(b('O Hobbit', 'Tolkien'));

    final provider = BooksProvider();
    await provider.load();
    expect(provider.allBooks.length, 2);

    provider.setQuery('tolkien');
    expect(provider.filteredBooks.single.title, 'O Hobbit');
    provider.setQuery('');
    expect(provider.filteredBooks.length, 2);
  });

  group('filtros e ordenação', providerFilterTests);
}

// ---- filtros, ordenação e busca sem acento ----
void providerFilterTests() {
  Book b(String t, String a, {String g = 'Romance', bool read = false, DateTime? start, bool paused = false, double rating = 0, int cur = 0, DateTime? target}) =>
      Book(
        title: t, author: a, publisher: 'P', genre: g, pageCount: 100, currentPage: cur, price: 1,
        isRead: read, dateAcquired: DateTime(2026, 1, 1), startDate: start, isPaused: paused,
        rating: rating, targetDate: target,
      );

  late Directory tmp;
  late BooksProvider provider;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('mbs_flt_');
    await DatabaseHelper.instance.useDatabaseAt(p.join(tmp.path, 'f.db'));
    final db = DatabaseHelper.instance;
    await db.create(b('Sertão Veredas', 'Guimarães Rosa', g: 'Clássico', read: true, rating: 5));
    await db.create(b('Ação Rápida', 'Zé', g: 'Aventura', start: DateTime(2026, 2, 1), cur: 40, target: DateTime(2026, 12, 1)));
    await db.create(b('Zebra', 'Ana', paused: true, start: DateTime(2026, 2, 1), target: DateTime(2026, 11, 1)));
    await db.create(b('Novo', 'Bia'));
    provider = BooksProvider();
    await provider.load();
  });
  tearDown(() async {
    await DatabaseHelper.instance.close();
    await tmp.delete(recursive: true);
  });

  test('busca ignora acentos e maiúsculas', () {
    provider.setQuery('SERTAO');
    expect(provider.filteredBooks.single.title, 'Sertão Veredas');
    provider.setQuery('acao');
    expect(provider.filteredBooks.single.title, 'Ação Rápida');
    provider.setQuery('guimaraes');
    expect(provider.filteredBooks.length, 1);
  });

  test('filtros de status e contagem', () {
    expect(provider.countFor(StatusFilter.read), 1);
    expect(provider.countFor(StatusFilter.reading), 1);
    expect(provider.countFor(StatusFilter.paused), 1);
    expect(provider.countFor(StatusFilter.notStarted), 1);
    provider.setStatus(StatusFilter.paused);
    expect(provider.filteredBooks.single.title, 'Zebra');
  });

  test('filtro por gênero', () {
    provider.setGenre('Aventura');
    expect(provider.filteredBooks.single.title, 'Ação Rápida');
    expect(provider.genres, containsAll(['Aventura', 'Clássico', 'Romance']));
  });

  test('ordenação por título ignora acento e alterna direção', () {
    expect(provider.filteredBooks.map((e) => e.title).first, 'Ação Rápida');
    provider.setSort(BookSort.title); // mesma opção => inverte
    expect(provider.filteredBooks.first.title, 'Zebra');
  });

  test('ordenação por prazo deixa livros sem meta no fim', () {
    provider.setSort(BookSort.deadline);
    final titles = provider.filteredBooks.map((e) => e.title).toList();
    expect(titles.take(2), ['Zebra', 'Ação Rápida']);
    provider.setSort(BookSort.deadline); // inverte
    expect(provider.filteredBooks.last.targetDate, isNull);
  });
}
