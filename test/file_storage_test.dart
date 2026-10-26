import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestordelivros/services/file_storage.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  late FileStorage storage;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('mbs_fs_');
    storage = await FileStorage.initWithDir(tmp.path);
  });
  tearDown(() => tmp.delete(recursive: true));

  test('saveEbook copia com nome único e devolve caminho relativo', () async {
    final src = File(p.join(tmp.path, 'livro.pdf'))..writeAsStringSync('%PDF');
    final a = await storage.saveEbook(src.path, 'pdf');
    await Future.delayed(const Duration(milliseconds: 2));
    final b = await storage.saveEbook(src.path, 'pdf');
    expect(p.isRelative(a), true);
    expect(a, isNot(b));
    expect(storage.exists(a), true);
  });

  test('resolve aceita caminhos relativos e absolutos antigos', () {
    expect(storage.resolve('ebooks/x.pdf'), p.join(tmp.path, 'ebooks/x.pdf'));
    expect(storage.resolve('/data/antigo.pdf'), '/data/antigo.pdf');
    expect(storage.resolve(null), isNull);
  });

  test('migrateLegacy move arquivo absoluto externo para a pasta do app', () async {
    final ext = await Directory.systemTemp.createTemp('mbs_ext_');
    final old = File(p.join(ext.path, 'capa.jpg'))..writeAsStringSync('img');
    final rel = await storage.migrateLegacy(old.path, FileStorage.coversFolder);
    expect(rel, startsWith('covers'));
    expect(storage.exists(rel), true);
    expect(await storage.migrateLegacy('covers/ja_relativo.jpg', FileStorage.coversFolder), isNull);
    await ext.delete(recursive: true);
  });

  test('saveCoverBytes grava capa baixada com nome único e caminho relativo', () async {
    final rel = await storage.saveCoverBytes(Uint8List.fromList([1, 2, 3]), ext: '.png');
    expect(p.isRelative(rel), true);
    expect(rel, endsWith('.png'));
    expect(await File(storage.resolve(rel)!).readAsBytes(), [1, 2, 3]);
  });
}
