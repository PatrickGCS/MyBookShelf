import 'dart:io';
import 'book_details_screen.dart';
import 'stats_screen.dart';
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
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../theme/mbs_palette.dart';
import '../widgets/book_cover.dart';
import '../widgets/glass.dart';
import '../widgets/library_filters.dart';
import '../widgets/pace_indicator.dart';
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
        builder: (ctx) => MbsDialog(
          title: const Text("Restaurar backup?"),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
    SettingsService.saveThemeMode(themeNotifier.value);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BooksProvider>();
    if (provider.query.isEmpty && searchController.text.isNotEmpty) {
      // 'Limpar' filtros esvazia a busca no provider: refletir no campo
      WidgetsBinding.instance.addPostFrameCallback((_) => searchController.clear());
    }
    final allBooks = provider.allBooks;
    final filteredBooks = provider.filteredBooks;
    final isLoading = provider.isLoading;
    final p = MbsPalette.of(context);

    // Estatísticas para o Dashboard
    final int totalBooks = allBooks.length;
    final int readBooks = allBooks.where((b) => b.isRead).length;
    final int readingBooks = allBooks.where((b) => !b.isRead && b.startDate != null).length;
    final int unreadBooks = allBooks.where((b) => !b.isRead && b.startDate == null).length;

    return MbsBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // CABEÇALHO
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                child: Row(
                  children: [
                    Expanded(child: Text('MyBookShelf', style: AppTheme.display(p.text, 28, height: 1.3))),
                    GlassIconButton(
                      icon: Icons.insights_rounded,
                      tooltip: 'Estatísticas',
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen())),
                    ),
                    GlassIconButton(
                      icon: p.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                      tooltip: p.isDark ? 'Tema claro' : 'Tema escuro',
                      onPressed: _toggleTheme,
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Backup',
                      padding: EdgeInsets.zero,
                      onSelected: (value) {
                        if (value == 'export') {
                          _exportDatabase();
                        } else if (value == 'import') {
                          _importDatabase();
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(value: 'export', child: Row(children: [Icon(Icons.upload_rounded, color: p.blue), const SizedBox(width: 10), const Text("Exportar backup")])),
                        PopupMenuItem(value: 'import', child: Row(children: [Icon(Icons.download_rounded, color: p.blue), const SizedBox(width: 10), const Text("Importar backup")])),
                      ],
                      child: const SizedBox(width: 48, height: 48, child: Center(child: GlassCircle(icon: Icons.more_vert, size: 44, iconSize: 20))),
                    ),
                  ],
                ),
              ),

              // BARRA DE PESQUISA
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: TextField(
                  controller: searchController,
                  onChanged: _runFilter,
                  decoration: InputDecoration(
                    hintText: 'Pesquisar título ou autor',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear_rounded), tooltip: 'Limpar busca', onPressed: _clearSearch)
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: p.glassBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: p.glassBorder)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: p.blue, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ),

              // FILTROS E ORDENAÇÃO
              const LibraryFilters(),

              // DASHBOARD (ESTATÍSTICAS)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    _buildStatCard("Total", totalBooks, p.blue, p),
                    const SizedBox(width: 8),
                    _buildStatCard("Lendo", readingBooks, p.accent, p),
                    const SizedBox(width: 8),
                    _buildStatCard("Lidos", readBooks, p.paceDot, p),
                    const SizedBox(width: 8),
                    _buildStatCard("Fila", unreadBooks, p.muted, p),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Na sua estante', style: AppTheme.display(p.blue, 20, height: 1.3)),
                ),
              ),

              // LISTA DE LIVROS
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredBooks.isEmpty
                        ? Center(child: Text("Nenhum livro encontrado.", style: AppTheme.body(p.muted, 14)))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                            itemCount: filteredBooks.length,
                            itemBuilder: (context, index) => _buildBookCard(filteredBooks[index], p),
                          ),
              ),
            ],
          ),
        ),
        floatingActionButton: MbsFab(onPressed: () => showBookForm(context, onChanged: _onBooksChanged)),
      ),
    );
  }

  Widget _buildBookCard(Book book, MbsPalette p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailsScreen(book: book))).then((_) => refreshBooks());
        },
        child: Row(
          children: [
            BookCover(book: book),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(p.text, 15, weight: FontWeight.w600, height: 1.3)),
                      ),
                      SizedBox(
                        width: 36,
                        height: 32,
                        child: PopupMenuButton<String>(
                          tooltip: 'Mais opções do livro',
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.more_vert, size: 20, color: p.muted),
                          onSelected: (value) async {
                            if (value == 'delete') {
                              await _confirmAndDeleteBook(book);
                            } else if (value == 'edit') {
                              showBookForm(context, book: book, onChanged: _onBooksChanged);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 10), Text("Editar")])),
                            PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, color: p.rose, size: 18), const SizedBox(width: 10), Text("Excluir", style: TextStyle(color: p.rose))])),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(p.muted, 12.5)),
                  if (book.rating > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: RatingBarIndicator(rating: book.rating, itemBuilder: (context, index) => Icon(Icons.star_rounded, color: p.amber), itemCount: 5, itemSize: 14.0),
                    ),
                  const SizedBox(height: 8),
                  MbsProgressBar(value: book.progress),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text.rich(
                        TextSpan(
                          style: AppTheme.body(p.muted, 11.5),
                          children: [
                            TextSpan(text: "${book.currentPage}/${book.pageCount}", style: AppTheme.body(p.text, 11.5, weight: FontWeight.w600)),
                            const TextSpan(text: " pág."),
                          ],
                        ),
                      ),
                      PaceIndicator(book: book),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GlassIconButton(
                  icon: Icons.format_quote_rounded,
                  size: 40,
                  color: p.blue,
                  tooltip: 'Adicionar citação',
                  onPressed: () => showQuoteDialog(context, book),
                ),
                const SizedBox(height: 4),
                _buildMainAction(book),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Botão principal do card, por estado do livro.
  Widget _buildMainAction(Book book) {
    if (book.isRead) {
      return SquircleButton(
        icon: Icons.check_rounded,
        tone: MbsTone.blue,
        tooltip: 'Lido (editar avaliação)',
        onPressed: () => showLogReadingDialog(context, book, onChanged: _onBooksChanged),
      );
    }
    if (book.startDate == null) {
      return SquircleButton(
        icon: Icons.menu_book_rounded,
        tone: MbsTone.solid,
        tooltip: 'Iniciar leitura',
        onPressed: () => showStartReadingDialog(context, book, onConfirm: refreshBooks),
      );
    }
    return SquircleButton(
      icon: book.isPaused ? Icons.replay_rounded : Icons.bookmark_add_outlined,
      tone: book.isPaused ? MbsTone.amber : MbsTone.orange,
      tooltip: book.isPaused ? 'Retomar leitura' : 'Registrar leitura',
      onPressed: () => showLogReadingDialog(context, book, onChanged: _onBooksChanged),
    );
  }

  Widget _buildStatCard(String label, int count, Color dot, MbsPalette p) {
    return Expanded(
      child: GlassCard(
        radius: 18,
        padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
        child: Column(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(height: 4),
            Text(count.toString(), style: AppTheme.display(p.text, 28, height: 1.2)),
            Text(label, style: AppTheme.body(p.muted, 11)),
          ],
        ),
      ),
    );
  }

  // --- DIALOGO DE CITAÇÃO ---


  // --- DIALOGO DE INICIAR LEITURA ---





  Future<void> _confirmAndDeleteBook(Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => MbsDialog(
        title: const Text("Excluir livro?"),
        content: Text("\"${book.title}\" será removido junto com suas citações, histórico de leitura e arquivos locais (capa e ebook). Esta ação não pode ser desfeita."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: MbsPalette.of(ctx).rose, foregroundColor: MbsPalette.of(ctx).onRose),
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
