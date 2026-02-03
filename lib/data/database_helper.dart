import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/book.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    // Subi a versão para 2 para disparar o onUpgrade
    _database = await _initDB('livros_v9.db'); 
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    // Adicionado onUpgrade para migração
    return await openDatabase(path, version: 2, onCreate: _createDB, onUpgrade: _onUpgrade);
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
        isPaused BOOLEAN DEFAULT 0,
        lastPauseDate TEXT,
        ebookPath TEXT 
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

    await db.execute('''
      CREATE TABLE quotes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bookId INTEGER NOT NULL,
        text TEXT NOT NULL,
        page INTEGER NOT NULL,
        FOREIGN KEY (bookId) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');
  }

  // --- MIGRAÇÃO DE BANCO DE DADOS (V1 -> V2) ---
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Se o usuário já tem o app, adicionamos a coluna nova sem apagar nada
      await db.execute("ALTER TABLE books ADD COLUMN ebookPath TEXT");
    }
  }

  Future close() async { final db = await instance.database; db.close(); }
  Future<int> create(Book book) async { final db = await instance.database; return await db.insert('books', book.toMap()); }
  Future<List<Book>> readAllBooks() async { final db = await instance.database; final result = await db.query('books', orderBy: 'title ASC'); return result.map((json) => Book.fromMap(json)).toList(); }
  Future<int> update(Book book) async { final db = await instance.database; return await db.update('books', book.toMap(), where: 'id = ?', whereArgs: [book.id]); }
  Future<int> delete(int id) async { final db = await instance.database; return await db.delete('books', where: 'id = ?', whereArgs: [id]); }
  Future<int> addSession(ReadingSession session) async { final db = await instance.database; return await db.insert('reading_sessions', session.toMap()); }
  Future<List<ReadingSession>> getHistory(int bookId) async { final db = await instance.database; final result = await db.query('reading_sessions', where: 'bookId = ?', whereArgs: [bookId], orderBy: 'date DESC'); return result.map((json) => ReadingSession.fromMap(json)).toList(); }

  Future<int> addQuote(Quote quote) async { 
    final db = await instance.database; 
    return await db.insert('quotes', quote.toMap()); 
  }
  
  Future<List<Quote>> getQuotes(int bookId) async { 
    final db = await instance.database; 
    final result = await db.query('quotes', where: 'bookId = ?', whereArgs: [bookId], orderBy: 'page ASC'); 
    return result.map((json) => Quote.fromMap(json)).toList(); 
  }

  Future<int> deleteQuote(int id) async {
    final db = await instance.database;
    return await db.delete('quotes', where: 'id = ?', whereArgs: [id]);
  }
}