import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/book.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('livros_v7.db'); // <--- Versão 7
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE books ( 
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        publisher TEXT NOT NULL,
        genre TEXT NOT NULL,
        pageCount INTEGER NOT NULL,
        currentPage INTEGER DEFAULT 0,
        price REAL NOT NULL,
        isRead BOOLEAN NOT NULL,
        dateAcquired TEXT NOT NULL,
        startDate TEXT,
        targetDate TEXT,
        imagePath TEXT,
        rating REAL DEFAULT 0.0,
        review TEXT,
        isPaused BOOLEAN DEFAULT 0, -- <--- NOVO
        lastPauseDate TEXT          -- <--- NOVO
      )
    ''');

    await db.execute('''
      CREATE TABLE reading_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bookId INTEGER NOT NULL,
        date TEXT NOT NULL,
        pageStopped INTEGER NOT NULL,
        FOREIGN KEY (bookId) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');
  }

  Future close() async { final db = await instance.database; db.close(); }
  Future<int> create(Book book) async { final db = await instance.database; return await db.insert('books', book.toMap()); }
  Future<List<Book>> readAllBooks() async { final db = await instance.database; final result = await db.query('books', orderBy: 'title ASC'); return result.map((json) => Book.fromMap(json)).toList(); }
  Future<int> update(Book book) async { final db = await instance.database; return await db.update('books', book.toMap(), where: 'id = ?', whereArgs: [book.id]); }
  Future<int> delete(int id) async { final db = await instance.database; return await db.delete('books', where: 'id = ?', whereArgs: [id]); }
  Future<int> addSession(ReadingSession session) async { final db = await instance.database; return await db.insert('reading_sessions', session.toMap()); }
  Future<List<ReadingSession>> getHistory(int bookId) async { final db = await instance.database; final result = await db.query('reading_sessions', where: 'bookId = ?', whereArgs: [bookId], orderBy: 'date DESC'); return result.map((json) => ReadingSession.fromMap(json)).toList(); }
}