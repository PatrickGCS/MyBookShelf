import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Guarda capas e ebooks no diretório de documentos do app.
///
/// No banco são gravados caminhos RELATIVOS (ex.: `ebooks/abc.pdf`), o que
/// permite restaurar backups em outro aparelho. Caminhos absolutos antigos
/// continuam funcionando em [resolve].
class FileStorage {
  FileStorage._(this.baseDir);

  static FileStorage? _instance;
  static FileStorage get instance {
    final i = _instance;
    if (i == null) throw StateError('FileStorage.init() não foi chamado.');
    return i;
  }

  final String baseDir;

  static const coversFolder = 'covers';
  static const ebooksFolder = 'ebooks';

  /// Inicializa usando o diretório de documentos do app.
  static Future<FileStorage> init() async {
    final dir = await getApplicationDocumentsDirectory();
    return initWithDir(dir.path);
  }

  /// Usado em testes e na inicialização.
  static Future<FileStorage> initWithDir(String dir) async {
    final s = FileStorage._(dir);
    await Directory(p.join(dir, coversFolder)).create(recursive: true);
    await Directory(p.join(dir, ebooksFolder)).create(recursive: true);
    _instance = s;
    return s;
  }

  /// Converte o valor guardado no banco em caminho absoluto.
  String? resolve(String? stored) {
    if (stored == null || stored.trim().isEmpty) return null;
    final s = stored.trim();
    return p.isAbsolute(s) ? s : p.join(baseDir, s);
  }

  bool exists(String? stored) {
    final r = resolve(stored);
    return r != null && File(r).existsSync();
  }

  Future<String> saveCover(String sourcePath) => _copyIn(sourcePath, coversFolder, fallbackExt: '.jpg');

  Future<String> saveEbook(String sourcePath, String extension) =>
      _copyIn(sourcePath, ebooksFolder, forceExt: '.${extension.toLowerCase()}');

  /// Copia em streaming (sem carregar o arquivo inteiro na memória) com nome único.
  Future<String> _copyIn(String sourcePath, String folder, {String? forceExt, String fallbackExt = ''}) async {
    var ext = forceExt ?? p.extension(sourcePath).toLowerCase();
    if (ext.isEmpty) ext = fallbackExt;
    final name = '${DateTime.now().microsecondsSinceEpoch}$ext';
    final relative = p.join(folder, name);
    await File(sourcePath).copy(p.join(baseDir, relative));
    return relative;
  }

  /// Apaga o arquivo apontado por [stored], se existir (melhor esforço).
  Future<void> delete(String? stored) async {
    final r = resolve(stored);
    if (r == null) return;
    try {
      final f = File(r);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Move arquivos antigos (caminho absoluto fora da pasta do app) para a pasta
  /// do app. Retorna o novo valor relativo, ou null se nada mudou/ não existe.
  Future<String?> migrateLegacy(String? stored, String folder) async {
    if (stored == null || !p.isAbsolute(stored.trim())) return null;
    final src = File(stored.trim());
    if (!await src.exists()) return null;
    if (p.isWithin(baseDir, src.path)) return p.relative(src.path, from: baseDir);
    return _copyIn(src.path, folder);
  }
}
