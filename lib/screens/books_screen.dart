import 'dart:io';
import 'book_details_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/database_helper.dart';
import '../models/book.dart';
import '../providers/books_provider.dart';
import '../services/backup_service.dart';
import '../services/file_storage.dart';
import '../services/legacy_migration.dart';
import '../theme/app_theme.dart';
import '../widgets/book_form.dart';
import '../widgets/log_reading_dialog.dart';
import '../widgets/quote_dialog.dart';
import '../widgets/start_reading_dialog.dart';

class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key});

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  final TextEditingController searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // --- CARREGAR LIVROS (estado em BooksProvider) ---
  Future<void> refreshBooks() => context.read<BooksProvider>().load();

  void _runFilter(String keyword) => context.read<BooksProvider>().setQuery(keyword);

  void _clearSearch() {
    searchController.clear();
    _runFilter('');
  }

  /// Chamado pelos formulários/diálogos após alterar dados.
  void _onBooksChanged() {
    _clearSearch();
    refreshBooks();
  }

  BackupService _backupService(String dbPath) =>
      BackupService(dbPath: dbPath, storageDir: FileStorage.instance.baseDir);

  void _snack(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // --- EXPORTAR BACKUP (banco + capas + ebooks em um .mbs) ---
  Future<void> _exportDatabase() async {
    try {
      final dbPath = await DatabaseHelper.instance.dbPath;
      if (!await File(dbPath).exists()) {
        _snack("Erro: Banco de dados não encontrado.");
        return;
      }
      // Fecha a conexão para garantir que o arquivo esteja consistente (reabre sob demanda)
      await DatabaseHelper.instance.close();
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final out = path.join((await getTemporaryDirectory()).path, 'MyBookShelf_$stamp.mbs');
      await _backupService(dbPath).createBackup(out);
      await Share.shareXFiles([XFile(out)], text: 'Backup do MyBookShelf');
    } catch (e) {
      _snack("Erro ao exportar: $e");
    }
  }

  // --- IMPORTAR BACKUP ---
  Future<void> _importDatabase() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      final picked = result?.files.single.path;
      if (picked == null) return;

      final dbPath = await DatabaseHelper.instance.dbPath;
      final service = _backupService(dbPath);

      // 1. Valida ANTES de pedir confirmação e antes de tocar nos dados atuais
      final Directory staging;
      try {
        staging = await service.stage(picked);
      } on BackupException catch (e) {
        _snack(e.message);
        return;
      }

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Restaurar Backup?"),
          content: const Text("Isso substituirá todos os livros, capas e ebooks atuais pelo conteúdo do backup. Tem certeza?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Sim, Restaurar")),
          ],
        ),
      );
      if (confirmed != true) {
        await staging.delete(recursive: true);
        return;
      }

      // 2. Fecha o banco (aguardando) e aplica com cópia de segurança/rollback
      await DatabaseHelper.instance.close();
      try {
        await service.applyStaged(staging);
        _snack("Backup restaurado com sucesso!");
      } on BackupException catch (e) {
        _snack(e.message);
      }
      try { await migrateLegacyFiles(); } catch (_) {}
      _clearSearch();
      await refreshBooks();
    } catch (e) {
      _snack("Erro ao importar: $e");
    }
  }

  // --- ALTERNAR TEMA ---
  void _toggleTheme() {
    themeNotifier.value = themeNotifier.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BooksProvider>();
    final allBooks = provider.allBooks;
    final filteredBooks = provider.filteredBooks;
    final isLoading = provider.isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Estatísticas para o Dashboard
    final int totalBooks = allBooks.length;
    final int readBooks = allBooks.where((b) => b.isRead).length;
    final int readingBooks = allBooks.where((b) => !b.isRead && b.startDate != null).length;
    final int unreadBooks = allBooks.where((b) => !b.isRead && b.startDate == null).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MyBookShelf', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        actions: [
          IconButton(icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode), onPressed: _toggleTheme),
          PopupMenuButton<String>(
            onSelected: (value) { if (value == 'export') _exportDatabase(); else if (value == 'import') _importDatabase(); },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'export', child: Row(children: [Icon(Icons.upload, color: Colors.blue), SizedBox(width: 10), Text("Exportar Backup")])),
              const PopupMenuItem(value: 'import', child: Row(children: [Icon(Icons.download, color: Colors.green), SizedBox(width: 10), Text("Importar Backup")])),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // BARRA DE PESQUISA
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: searchController, onChanged: _runFilter,
              decoration: InputDecoration(
                labelText: 'Pesquisar...', prefixIcon: const Icon(Icons.search),
                suffixIcon: searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: _clearSearch) : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)), filled: true, fillColor: isDark ? Colors.grey[800] : Colors.grey[100], contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              ),
            ),
          ),
          
          // DASHBOARD (ESTATÍSTICAS)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatCard("Total", totalBooks, Colors.blue, isDark), const SizedBox(width: 8),
                _buildStatCard("Lendo", readingBooks, Colors.orange, isDark), const SizedBox(width: 8),
                _buildStatCard("Lidos", readBooks, Colors.green, isDark), const SizedBox(width: 8),
                _buildStatCard("Fila", unreadBooks, Colors.grey, isDark),
              ],
            ),
          ),

          // LISTA DE LIVROS
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredBooks.isEmpty
                    ? const Center(child: Text("Nenhum livro encontrado.", style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredBooks.length,
                        itemBuilder: (context, index) {
                          final book = filteredBooks[index];
                          final percent = book.progress;
                          
                          // Lógica da Meta Inteligente
                          final urgencyColor = book.getUrgencyColor();
                          final urgencyText = book.getUrgencyText();

                          return Card(
                            elevation: 3, margin: const EdgeInsets.only(bottom: 16), clipBehavior: Clip.antiAlias, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: InkWell(
                              onTap: () { Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailsScreen(book: book))).then((_) => refreshBooks()); },
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // CAPA
                                    Container(
                                      width: 60, height: 90,
                                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(8), image: book.imagePath != null ? DecorationImage(image: ResizeImage(FileImage(File(FileStorage.instance.resolve(book.imagePath)!)), width: 200), fit: BoxFit.cover) : null),
                                      child: book.imagePath == null ? const Icon(Icons.book, color: Colors.deepPurple) : null,
                                    ),
                                    const SizedBox(width: 12),
                                    // INFORMAÇÕES
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                          Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                          
                                          // Estrelas (se tiver nota)
                                          if (book.rating > 0)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: RatingBarIndicator(rating: book.rating, itemBuilder: (context, index) => const Icon(Icons.star, color: Colors.amber), itemCount: 5, itemSize: 14.0),
                                            ),

                                          const SizedBox(height: 8),
                                          // Barra de Progresso Inteligente
                                          LinearProgressIndicator(value: percent, minHeight: 8, backgroundColor: isDark ? Colors.grey[700] : Colors.grey[200], color: urgencyColor, borderRadius: BorderRadius.circular(3)),
                                          const SizedBox(height: 6),
                                          
                                          // --- BOX COLORIDA DE META ---
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text("${(percent * 100).toInt()}%", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(color: urgencyColor, borderRadius: BorderRadius.circular(6)),
                                                child: Text(urgencyText, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                    // BOTÕES
                                    Column(
                                      children: [
                                        PopupMenuButton(
                                          icon: const Icon(Icons.more_vert, size: 20), padding: EdgeInsets.zero,
                                          onSelected: (value) async { if (value == 'delete') { await _confirmAndDeleteBook(book); } else if (value == 'edit') showBookForm(context, book: book, onChanged: _onBooksChanged); },
                                          itemBuilder: (context) => [ const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text("Editar")])), const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text("Excluir", style: TextStyle(color: Colors.red))])), ],
                                        ),
                                        
                                        // BOTÃO DE CITAÇÃO (NOVO)
                                        IconButton(
                                          icon: const Icon(Icons.format_quote, color: Colors.purpleAccent),
                                          tooltip: "Adicionar Citação",
                                          onPressed: () => showQuoteDialog(context, book),
                                        ),

                                        // BOTÃO PRINCIPAL (Ler/Iniciar)
                                        if (book.isRead)
                                          IconButton(
                                            icon: const Icon(Icons.check_circle, color: Colors.green),
                                            onPressed: () => showLogReadingDialog(context, book, onChanged: _onBooksChanged),
                                            tooltip: "Lido (Editar Avaliação)",
                                          )
                                        else if (book.startDate == null)
                                          IconButton(
                                            icon: const Icon(Icons.play_circle_fill, color: Colors.green, size: 30),
                                            onPressed: () => showStartReadingDialog(context, book, onConfirm: refreshBooks),
                                            tooltip: "Iniciar Leitura",
                                          )
                                        else
                                          IconButton(
                                            icon: Icon(
                                              book.isPaused ? Icons.play_arrow : Icons.bookmark_add, 
                                              color: book.isPaused ? Colors.orange : Colors.blueAccent
                                            ),
                                            onPressed: () => showLogReadingDialog(context, book, onChanged: _onBooksChanged),
                                            tooltip: book.isPaused ? "Retomar" : "Registrar",
                                          )
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => showBookForm(context, onChanged: _onBooksChanged), child: const Icon(Icons.add)),
    );
  }

  Widget _buildStatCard(String label, int count, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: color.withValues(alpha: isDark ? 0.2 : 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.5))),
        child: Column(children: [Text(count.toString(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)), const SizedBox(height: 2), Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87))]),
      ),
    );
  }

  // --- DIALOGO DE CITAÇÃO ---


  // --- DIALOGO DE INICIAR LEITURA ---





  Future<void> _confirmAndDeleteBook(Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Excluir livro?"),
        content: Text("\"${book.title}\" será removido junto com suas citações, histórico de leitura e arquivos locais (capa e ebook). Esta ação não pode ser desfeita."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Excluir"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Remove os arquivos associados (melhor esforço) para não deixar lixo no armazenamento
    await FileStorage.instance.delete(book.imagePath);
    await FileStorage.instance.delete(book.ebookPath);

    await DatabaseHelper.instance.delete(book.id!);
    _clearSearch();
    await refreshBooks();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Livro excluído.")));
    }
  }


}
