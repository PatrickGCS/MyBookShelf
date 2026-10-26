import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestordelivros/data/database_helper.dart';
import 'package:gestordelivros/models/book.dart';
import 'package:gestordelivros/services/backup_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Book _book(String title, {String? cover}) => Book(
      title: title, author: 'A', publisher: 'P', genre: 'G', pageCount: 100,
      price: 1, isRead: false, dateAcquired: DateTime(2026, 1, 1), imagePath: cover,
    );

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tmp;
  late String dbPath;
  late BackupService service;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('mbs_test_');
    dbPath = p.join(tmp.path, 'test.db');
    await Directory(p.join(tmp.path, 'covers')).create();
    await Directory(p.join(tmp.path, 'ebooks')).create();
    await DatabaseHelper.instance.useDatabaseAt(dbPath);
    service = BackupService(dbPath: dbPath, storageDir: tmp.path);
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
    await tmp.delete(recursive: true);
  });

  test('foreign keys: excluir livro apaga citações e sessões (cascade)', () async {
    final id = await DatabaseHelper.instance.create(_book('X'));
    await DatabaseHelper.instance.addQuote(Quote(bookId: id, text: 'q', page: 1));
    await DatabaseHelper.instance.addSession(ReadingSession(bookId: id, date: DateTime.now(), pageStopped: 5));
    await DatabaseHelper.instance.delete(id);
    expect(await DatabaseHelper.instance.getQuotes(id), isEmpty);
    expect(await DatabaseHelper.instance.getHistory(id), isEmpty);
  });

  test('backup e restauração preservam livros e arquivos', () async {
    await File(p.join(tmp.path, 'covers', 'c.jpg')).writeAsString('capa');
    await DatabaseHelper.instance.create(_book('Original', cover: 'covers/c.jpg'));
    await DatabaseHelper.instance.close();

    final out = p.join(tmp.path, 'b.mbs');
    await service.createBackup(out);

    // altera o estado atual
    await DatabaseHelper.instance.create(_book('Depois'));
    await File(p.join(tmp.path, 'covers', 'c.jpg')).delete();
    await DatabaseHelper.instance.close();

    final staging = await service.stage(out);
    await service.applyStaged(staging);

    final books = await DatabaseHelper.instance.readAllBooks();
    expect(books.map((b) => b.title), ['Original']);
    expect(File(p.join(tmp.path, 'covers', 'c.jpg')).existsSync(), true);
  });

  test('arquivo inválido é rejeitado sem tocar nos dados atuais', () async {
    await DatabaseHelper.instance.create(_book('Seguro'));
    await DatabaseHelper.instance.close();
    final bad = File(p.join(tmp.path, 'lixo.txt'))..writeAsStringSync('não sou um banco');

    await expectLater(service.stage(bad.path), throwsA(isA<BackupException>()));
    expect((await DatabaseHelper.instance.readAllBooks()).single.title, 'Seguro');
  });

  test('backup antigo (.db puro) ainda é aceito', () async {
    await DatabaseHelper.instance.create(_book('Legado'));
    await DatabaseHelper.instance.close();
    final legacy = p.join(tmp.path, 'old.db');
    await File(dbPath).copy(legacy);
    final staging = await service.stage(legacy);
    expect(await File(p.join(staging.path, BackupService.dbEntry)).exists(), true);
    await staging.delete(recursive: true);
  });
}
