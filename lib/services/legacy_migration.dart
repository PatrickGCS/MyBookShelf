import '../data/database_helper.dart';
import 'file_storage.dart';

/// Converte caminhos absolutos antigos (cache do image_picker, pasta de bancos)
/// para arquivos dentro da pasta do app, gravando caminhos relativos no banco.
/// É idempotente: caminhos já relativos são ignorados.
Future<void> migrateLegacyFiles() async {
  final storage = FileStorage.instance;
  final db = await DatabaseHelper.instance.database;
  final rows = await db.query('books', columns: ['id', 'imagePath', 'ebookPath']);
  for (final r in rows) {
    final id = r['id'] as int;
    final values = <String, Object?>{};

    final cover = r['imagePath'] as String?;
    final newCover = await storage.migrateLegacy(cover, FileStorage.coversFolder);
    if (newCover != null) values['imagePath'] = newCover;

    final ebook = r['ebookPath'] as String?;
    final newEbook = await storage.migrateLegacy(ebook, FileStorage.ebooksFolder);
    if (newEbook != null) values['ebookPath'] = newEbook;

    if (values.isNotEmpty) {
      await db.update('books', values, where: 'id = ?', whereArgs: [id]);
    }
  }
}
