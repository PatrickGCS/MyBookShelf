import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class BackupException implements Exception {
  final String message;
  BackupException(this.message);
  @override
  String toString() => message;
}

/// Backup completo: banco + capas + ebooks em um único .zip (extensão .mbs).
class BackupService {
  BackupService({required this.dbPath, required this.storageDir});

  final String dbPath;
  final String storageDir;

  static const dbEntry = 'livros.db';
  static const _folders = ['covers', 'ebooks'];

  /// Cria o arquivo de backup em [outPath]. O banco deve estar fechado ou
  /// sem escrita em andamento; use [checkpoint] antes se estiver aberto.
  Future<File> createBackup(String outPath) async {
    final encoder = ZipFileEncoder()..create(outPath);
    await encoder.addFile(File(dbPath), dbEntry);
    for (final folder in _folders) {
      final dir = Directory(p.join(storageDir, folder));
      if (!await dir.exists()) continue;
      await for (final e in dir.list(recursive: true)) {
        if (e is File) {
          final rel = p.relative(e.path, from: storageDir).replaceAll('\\', '/');
          await encoder.addFile(e, rel);
        }
      }
    }
    await encoder.close();
    return File(outPath);
  }

  /// Confere se [dbFile] é um SQLite do MyBookShelf (tabelas e colunas essenciais).
  static Future<bool> isValidDatabase(String dbFile) async {
    Database? db;
    try {
      db = await openDatabase(dbFile, readOnly: true, singleInstance: false);
      final tables = (await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'"))
          .map((r) => r['name'] as String)
          .toSet();
      if (!tables.containsAll({'books', 'reading_sessions', 'quotes'})) return false;
      final cols = (await db.rawQuery('PRAGMA table_info(books)')).map((r) => r['name'] as String).toSet();
      return cols.containsAll({'id', 'title', 'author', 'pageCount', 'currentPage'});
    } catch (_) {
      return false;
    } finally {
      await db?.close();
    }
  }

  /// Extrai [backupPath] numa pasta temporária e valida. Retorna o diretório
  /// de staging pronto para ser aplicado por [applyStaged]. Lança [BackupException].
  Future<Directory> stage(String backupPath) async {
    final file = File(backupPath);
    if (!await file.exists()) throw BackupException('Arquivo não encontrado.');
    final staging = await Directory.systemTemp.createTemp('mbs_restore_');
    try {
      final header = await file.openRead(0, 4).first;
      final isZip = header.length >= 2 && header[0] == 0x50 && header[1] == 0x4B; // "PK"
      if (isZip) {
        await extractFileToDisk(backupPath, staging.path);
        // Proteção contra path traversal: tudo deve estar dentro de staging
        await for (final e in staging.list(recursive: true, followLinks: false)) {
          if (!p.isWithin(staging.path, e.path)) throw BackupException('Backup inválido.');
        }
      } else {
        // Backup antigo: apenas o arquivo .db
        await file.copy(p.join(staging.path, dbEntry));
      }
      final stagedDb = p.join(staging.path, dbEntry);
      if (!await File(stagedDb).exists() || !await isValidDatabase(stagedDb)) {
        throw BackupException('O arquivo selecionado não é um backup válido do MyBookShelf.');
      }
      return staging;
    } catch (e) {
      await staging.delete(recursive: true);
      if (e is BackupException) rethrow;
      throw BackupException('Não foi possível ler o backup: $e');
    }
  }

  /// Aplica o conteúdo validado. O chamador deve ter FECHADO o banco antes.
  /// Cria uma cópia de segurança do estado atual e a restaura se algo falhar.
  Future<void> applyStaged(Directory staging) async {
    final safety = await Directory.systemTemp.createTemp('mbs_safety_');
    try {
      if (await File(dbPath).exists()) await File(dbPath).copy(p.join(safety.path, dbEntry));
      for (final f in _folders) {
        final src = Directory(p.join(storageDir, f));
        if (await src.exists()) await _copyDir(src, Directory(p.join(safety.path, f)));
      }
      try {
        await File(p.join(staging.path, dbEntry)).copy(dbPath);
        for (final f in _folders) {
          final target = Directory(p.join(storageDir, f));
          if (await target.exists()) await target.delete(recursive: true);
          final from = Directory(p.join(staging.path, f));
          if (await from.exists()) {
            await _copyDir(from, target);
          } else {
            await target.create(recursive: true);
          }
        }
      } catch (e) {
        // rollback
        await File(p.join(safety.path, dbEntry)).copy(dbPath);
        for (final f in _folders) {
          final target = Directory(p.join(storageDir, f));
          if (await target.exists()) await target.delete(recursive: true);
          final from = Directory(p.join(safety.path, f));
          if (await from.exists()) await _copyDir(from, target);
        }
        throw BackupException('Falha ao restaurar; seus dados atuais foram mantidos. ($e)');
      }
    } finally {
      await safety.delete(recursive: true);
      await staging.delete(recursive: true);
    }
  }

  static Future<void> _copyDir(Directory from, Directory to) async {
    await to.create(recursive: true);
    await for (final e in from.list(recursive: true)) {
      final rel = p.relative(e.path, from: from.path);
      if (e is File) {
        await Directory(p.dirname(p.join(to.path, rel))).create(recursive: true);
        await e.copy(p.join(to.path, rel));
      }
    }
  }
}
