import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:pdfrx/pdfrx.dart'; // <--- Nova biblioteca PDF (sem conflitos)
import 'package:epub_view/epub_view.dart';
import 'package:permission_handler/permission_handler.dart'; // Adicionado para garantir acessos
import 'data/database_helper.dart';
import 'models/book.dart';

// --- CONTROLE DO TEMA (GLOBAL) ---
final ValueNotifier<ThemeMode> _themeNotifier = ValueNotifier(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'Gestor de Livros',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          // TEMA CLARO
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4), brightness: Brightness.light),
            textTheme: GoogleFonts.poppinsTextTheme(),
            inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true),
          ),
          // TEMA ESCURO
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4), brightness: Brightness.dark),
            textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
            inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true),
          ),
          home: const BooksScreen(),
        );
      },
    );
  }
}

class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key});

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  List<Book> allBooks = [];
  List<Book> filteredBooks = [];
  bool isLoading = true;
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    refreshBooks();
  }

  // --- CARREGAR LIVROS ---
  Future<void> refreshBooks() async {
    setState(() => isLoading = true);
    final data = await DatabaseHelper.instance.readAllBooks();
    setState(() {
      allBooks = data;
      filteredBooks = data;
      isLoading = false;
    });
    // Se tiver busca ativa, reaplica o filtro
    if (searchController.text.isNotEmpty) _runFilter(searchController.text);
  }

  // --- FILTRO DE BUSCA ---
  void _runFilter(String keyword) {
    List<Book> results = [];
    if (keyword.isEmpty) {
      results = allBooks;
    } else {
      results = allBooks.where((book) =>
          book.title.toLowerCase().contains(keyword.toLowerCase()) || 
          book.author.toLowerCase().contains(keyword.toLowerCase())
      ).toList();
    }
    setState(() => filteredBooks = results);
  }

  // --- EXPORTAR BACKUP ---
  Future<void> _exportDatabase() async {
    try {
      final dbFolder = await getDatabasesPath();
      final dbPath = path.join(dbFolder, 'livros_v9.db'); 
      final dbFile = File(dbPath);

      if (await dbFile.exists()) {
        await Share.shareXFiles([XFile(dbPath)], text: 'Backup da Minha Biblioteca');
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro: Banco de dados não encontrado.")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao exportar: $e")));
    }
  }

  // --- IMPORTAR BACKUP ---
  Future<void> _importDatabase() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        File sourceFile = File(result.files.single.path!);
        final dbFolder = await getDatabasesPath();
        final dbPath = path.join(dbFolder, 'livros_v9.db'); 

        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Restaurar Backup?"),
              content: const Text("Isso apagará todos os livros atuais e substituirá pelo backup. Tem certeza?"),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await DatabaseHelper.instance.close();
                    await sourceFile.copy(dbPath);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Backup restaurado com sucesso!")));
                    refreshBooks();
                  },
                  child: const Text("Sim, Restaurar"),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao importar: $e")));
    }
  }

  // --- ALTERNAR TEMA ---
  void _toggleTheme() {
    _themeNotifier.value = _themeNotifier.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Estatísticas para o Dashboard
    final int totalBooks = allBooks.length;
    final int readBooks = allBooks.where((b) => b.isRead).length;
    final int readingBooks = allBooks.where((b) => !b.isRead && b.startDate != null).length;
    final int unreadBooks = allBooks.where((b) => !b.isRead && b.startDate == null).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha Leitura', style: TextStyle(fontWeight: FontWeight.bold)),
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
                suffixIcon: searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { searchController.clear(); _runFilter(''); }) : null,
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
                                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(8), image: book.imagePath != null ? DecorationImage(image: FileImage(File(book.imagePath!)), fit: BoxFit.cover) : null),
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
                                          onSelected: (value) async { if (value == 'delete') { await DatabaseHelper.instance.delete(book.id!); refreshBooks(); searchController.clear(); } else if (value == 'edit') _showBookForm(context, book: book); },
                                          itemBuilder: (context) => [ const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text("Editar")])), const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text("Excluir", style: TextStyle(color: Colors.red))])), ],
                                        ),
                                        
                                        // BOTÃO DE CITAÇÃO (NOVO)
                                        IconButton(
                                          icon: const Icon(Icons.format_quote, color: Colors.purpleAccent),
                                          tooltip: "Adicionar Citação",
                                          onPressed: () => _showQuoteDialog(context, book),
                                        ),

                                        // BOTÃO PRINCIPAL (Ler/Iniciar)
                                        if (book.isRead)
                                          IconButton(
                                            icon: const Icon(Icons.check_circle, color: Colors.green),
                                            onPressed: () => _showReadingDialog(context, book),
                                            tooltip: "Lido (Editar Avaliação)",
                                          )
                                        else if (book.startDate == null)
                                          IconButton(
                                            icon: const Icon(Icons.play_circle_fill, color: Colors.green, size: 30),
                                            onPressed: () => _showStartReadingDialog(context, book),
                                            tooltip: "Iniciar Leitura",
                                          )
                                        else
                                          IconButton(
                                            icon: Icon(
                                              book.isPaused ? Icons.play_arrow : Icons.bookmark_add, 
                                              color: book.isPaused ? Colors.orange : Colors.blueAccent
                                            ),
                                            onPressed: () => _showLogReadingDialog(context, book),
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
      floatingActionButton: FloatingActionButton(onPressed: () => _showBookForm(context), child: const Icon(Icons.add)),
    );
  }

  Widget _buildStatCard(String label, int count, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: color.withOpacity(isDark ? 0.2 : 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.5))),
        child: Column(children: [Text(count.toString(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)), const SizedBox(height: 2), Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87))]),
      ),
    );
  }

  // --- DIALOGO DE CITAÇÃO ---
  void _showQuoteDialog(BuildContext context, Book book) {
    final textController = TextEditingController();
    final pageController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Nova Citação 💬"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: "A frase que te marcou...", hintText: "Ex: 'O essencial é invisível aos olhos'"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: pageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Página (opcional)", prefixIcon: Icon(Icons.bookmark_border)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          FilledButton(
            onPressed: () async {
              if (textController.text.isEmpty) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Escreva a citação.")));
                 return;
              }

              final int page = int.tryParse(pageController.text) ?? 0;

              // --- VALIDAÇÃO DE PÁGINA ---
              if (page > book.pageCount) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: O livro só tem ${book.pageCount} páginas.")));
                return;
              }

              final quote = Quote(
                bookId: book.id!,
                text: textController.text,
                page: page,
              );
              await DatabaseHelper.instance.addQuote(quote);
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Citação salva!")));
              }
            },
            child: const Text("Salvar"),
          ),
        ],
      ),
    );
  }

  // --- DIALOGO DE INICIAR LEITURA ---
  void _showStartReadingDialog(BuildContext context, Book book, {VoidCallback? onConfirm}) {
    DateTime targetDate = DateTime.now().add(const Duration(days: 30));
    
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text("Iniciar Leitura 🚀"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Vamos começar! Quando você pretende terminar este livro?"),
                const SizedBox(height: 20),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: targetDate, firstDate: DateTime.now(), lastDate: DateTime(2100));
                    if (picked != null) setState(() => targetDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(border: Border.all(color: Colors.blue), borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.flag, color: Colors.blue), const SizedBox(width: 8), Text(DateFormat('dd/MM/yyyy').format(targetDate), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
                  ),
                )
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
              FilledButton(
                onPressed: () async {
                  final updatedBook = Book(
                    id: book.id, title: book.title, author: book.author, publisher: book.publisher, genre: book.genre,
                    pageCount: book.pageCount, price: book.price, dateAcquired: book.dateAcquired,
                    currentPage: book.currentPage, isRead: book.isRead, imagePath: book.imagePath,
                    startDate: DateTime.now(),
                    targetDate: targetDate,
                    ebookPath: book.ebookPath, // Mantém o ebook
                  );
                  await DatabaseHelper.instance.update(updatedBook);
                  refreshBooks(); // <--- CORREÇÃO: Usando _refreshBook() (singular)
                  if (mounted) Navigator.pop(ctx);
                  
                  if (onConfirm != null) onConfirm();
                },
                child: const Text("Iniciar"),
              ),
            ],
          );
        });
      },
    );
  }

  void _showLogReadingDialog(BuildContext context, Book book) {
    final pageController = TextEditingController(text: book.currentPage.toString());
    final reviewController = TextEditingController(text: book.review ?? "");
    bool isFinished = false;
    double currentRating = book.rating;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(book.isPaused ? "Retomar Leitura ▶️" : "Registrar Leitura 📖"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isFinished && !book.isRead)
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: book.isPaused ? Colors.green : Colors.orange,
                            side: BorderSide(color: book.isPaused ? Colors.green : Colors.orange),
                          ),
                          icon: Icon(book.isPaused ? Icons.play_arrow : Icons.pause),
                          label: Text(book.isPaused ? "DESPAUSAR (Retomar Meta)" : "PAUSAR LEITURA"),
                          onPressed: () async {
                            if (book.isPaused) {
                              final now = DateTime.now();
                              final pauseStart = book.lastPauseDate ?? now;
                              final daysPaused = now.difference(pauseStart).inDays;
                              final newTarget = book.targetDate != null ? book.targetDate!.add(Duration(days: daysPaused)) : null;

                              final updatedBook = Book(
                                id: book.id, title: book.title, author: book.author, publisher: book.publisher, genre: book.genre,
                                pageCount: book.pageCount, price: book.price, dateAcquired: book.dateAcquired,
                                currentPage: book.currentPage, isRead: book.isRead, imagePath: book.imagePath, startDate: book.startDate,
                                rating: book.rating, review: book.review, isPaused: false, targetDate: newTarget, lastPauseDate: null,
                                ebookPath: book.ebookPath,
                              );
                              await DatabaseHelper.instance.update(updatedBook);
                              if (mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Leitura retomada! Meta adiada em $daysPaused dias."))); }
                            } else {
                              final updatedBook = Book(
                                id: book.id, title: book.title, author: book.author, publisher: book.publisher, genre: book.genre,
                                pageCount: book.pageCount, price: book.price, dateAcquired: book.dateAcquired,
                                currentPage: book.currentPage, isRead: book.isRead, imagePath: book.imagePath, startDate: book.startDate,
                                targetDate: book.targetDate, rating: book.rating, review: book.review, isPaused: true, lastPauseDate: DateTime.now(),
                                ebookPath: book.ebookPath,
                              );
                              await DatabaseHelper.instance.update(updatedBook);
                              if (mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Leitura pausada."))); }
                            }
                            refreshBooks();
                          },
                        ),
                      ),

                    if (book.isPaused)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text("O livro está pausado. Retome a leitura para registrar novas páginas.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                      )
                    else ...[
                      TextField(
                        controller: pageController, keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Página Atual", suffixText: "pág"),
                        onChanged: (val) { if (int.tryParse(val) == book.pageCount) setState(() => isFinished = true); },
                      ),
                      const SizedBox(height: 10),
                      CheckboxListTile(
                        title: const Text("Terminei o livro!"), value: isFinished,
                        onChanged: (val) => setState(() { isFinished = val!; if (isFinished) pageController.text = book.pageCount.toString(); }),
                      ),
                      
                      if (isFinished || book.isRead) ...[
                        const Divider(),
                        const Text("Avaliação", style: TextStyle(fontWeight: FontWeight.bold)),
                        RatingBar.builder(initialRating: currentRating, minRating: 1, direction: Axis.horizontal, allowHalfRating: true, itemCount: 5, itemSize: 30, itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber), onRatingUpdate: (rating) { currentRating = rating; }),
                        TextField(controller: reviewController, maxLines: 2, decoration: const InputDecoration(labelText: "Opinião (opcional)")),
                      ],
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
                if (!book.isPaused)
                  FilledButton(
                    onPressed: () async {
                      int newPage = int.tryParse(pageController.text) ?? book.currentPage;
                      if (newPage > book.pageCount) newPage = book.pageCount;
                      
                      final updatedBook = Book(
                        id: book.id, title: book.title, author: book.author, publisher: book.publisher, genre: book.genre,
                        pageCount: book.pageCount, price: book.price, dateAcquired: book.dateAcquired,
                        currentPage: newPage, isRead: isFinished || newPage == book.pageCount, imagePath: book.imagePath,
                        startDate: book.startDate, targetDate: book.targetDate,
                        rating: (isFinished || book.isRead) ? currentRating : book.rating,
                        review: (isFinished || book.isRead) ? reviewController.text : book.review,
                        isPaused: false,
                        ebookPath: book.ebookPath,
                      );
                      
                      await DatabaseHelper.instance.update(updatedBook);
                      if (newPage != book.currentPage) {
                        await DatabaseHelper.instance.addSession(ReadingSession(bookId: book.id!, date: DateTime.now(), pageStopped: newPage));
                      }
                      refreshBooks();
                      searchController.clear();
                      if (mounted) Navigator.pop(ctx);
                    },
                    child: const Text("Salvar"),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _showReadingDialog(BuildContext context, Book book) {
    _showLogReadingDialog(context, book);
  }

  void _showBookForm(BuildContext context, {Book? book}) {
    final isEditing = book != null;
    final titleController = TextEditingController(text: book?.title);
    final authorController = TextEditingController(text: book?.author);
    final publisherController = TextEditingController(text: book?.publisher);
    final genreController = TextEditingController(text: book?.genre);
    final pagesController = TextEditingController(text: book?.pageCount.toString());
    final priceController = TextEditingController(text: book?.price.toString());
    DateTime selectedDate = book?.dateAcquired ?? DateTime.now();
    DateTime? targetDate = book?.targetDate;
    
    final dateController = TextEditingController(text: DateFormat('dd/MM/yyyy').format(selectedDate));
    String? currentImagePath = book?.imagePath;
    String? currentEbookPath = book?.ebookPath; // --- VARIAVEL PARA O EBOOK
    bool alreadyRead = book?.isRead ?? false;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 20, left: 20, right: 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(isEditing ? "Editar Livro" : "Novo Livro", style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- FOTO ---
                        GestureDetector(
                          onTap: () async {
                            final ImagePicker picker = ImagePicker();
                            showModalBottomSheet(context: context, builder: (bsContext) { return SafeArea(child: Wrap(children: [ListTile(leading: const Icon(Icons.photo_camera), title: const Text('Câmera'), onTap: () async { final XFile? photo = await picker.pickImage(source: ImageSource.camera); if (photo != null) setModalState(() => currentImagePath = photo.path); Navigator.pop(bsContext); }), ListTile(leading: const Icon(Icons.photo_library), title: const Text('Galeria'), onTap: () async { final XFile? photo = await picker.pickImage(source: ImageSource.gallery); if (photo != null) setModalState(() => currentImagePath = photo.path); Navigator.pop(bsContext); })])); });
                          },
                          child: Container(height: 120, width: 80, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey), image: currentImagePath != null ? DecorationImage(image: FileImage(File(currentImagePath!)), fit: BoxFit.cover) : null), child: currentImagePath == null ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, size: 30, color: Colors.grey), Text("Capa", style: TextStyle(fontSize: 10))]) : null),
                        ),
                        const SizedBox(width: 15),
                        // --- BOTÃO EBOOK (NOVO) ---
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.upload_file),
                                  label: Text(currentEbookPath == null ? "Importar Ebook (PDF/EPUB)" : "Ebook Selecionado!"),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: currentEbookPath != null ? Colors.green : Colors.blue,
                                    side: BorderSide(color: currentEbookPath != null ? Colors.green : Colors.grey),
                                  ),
                                  onPressed: () async {
                                    // Solicita permissão se necessário
                                    await Permission.storage.request();
                                    
                                    // Selecionar PDF ou EPUB
                                    FilePickerResult? result = await FilePicker.platform.pickFiles(
                                      type: FileType.custom,
                                      allowedExtensions: ['pdf', 'epub'],
                                    );
                                    
                                    if(result != null) {
                                      PlatformFile file = result.files.first;
                                      
                                      // 1. Obter/Criar Diretório para Ebooks
                                      final dbDir = await getDatabasesPath();
                                      final ebooksDir = Directory(path.join(dbDir, 'ebooks'));
                                      if (!await ebooksDir.exists()) {
                                        await ebooksDir.create(recursive: true);
                                      }
                                      
                                      // 2. Corrigir Extensão (Lógica Blindada)
                                      String originalName = file.name;
                                      String extension = file.extension?.toLowerCase() ?? '';
                                      
                                      // Tenta extrair extensão do nome se vier vazia
                                      if (extension.isEmpty) {
                                        extension = path.extension(originalName).replaceAll('.', '').toLowerCase();
                                      }
                                      
                                      // Se ainda vazia e temos o caminho, tenta detectar pelo header (Magic Bytes)
                                      if (extension.isEmpty && file.path != null) {
                                         try {
                                           final f = File(file.path!);
                                           if (await f.exists()) {
                                             final bytes = await f.openRead(0, 20).first;
                                             final header = String.fromCharCodes(bytes);
                                             if (header.contains('%PDF')) {
                                               extension = 'pdf';
                                             } else if (header.contains('PK') || header.contains('epub')) {
                                               extension = 'epub';
                                             }
                                           }
                                         } catch (e) {
                                           debugPrint('Erro ao detectar header: $e');
                                         }
                                      }

                                      // Fallback final: se não achou nada, assume PDF (padrão seguro) ou Epub pelo nome
                                      if (extension.isEmpty) {
                                         if (originalName.toLowerCase().contains('epub')) extension = 'epub';
                                         else extension = 'pdf'; 
                                      }

                                      // 3. Montar Nome Final Limpo (Evita duplicatas tipo livro.pdf.pdf)
                                      String baseName = path.basenameWithoutExtension(originalName);
                                      String finalFileName = '$baseName.$extension';

                                      final savedPath = path.join(ebooksDir.path, finalFileName).trim();
                                      File savedFile = File(savedPath);
                                      
                                      try {
                                        // 4. Salvar Arquivo (Cópia Segura via Bytes)
                                        if (file.path != null) {
                                          final bytes = await File(file.path!).readAsBytes();
                                          await savedFile.writeAsBytes(bytes);
                                        }
                                        
                                        setModalState(() {
                                          currentEbookPath = savedPath;
                                        });
                                        
                                        // 5. Preenchimento Automático de Páginas (PDF e EPUB)
                                        if (extension == 'pdf') {
                                          try {
                                            // Tenta abrir lendo os dados primeiro (mais seguro no android)
                                            final fileData = await savedFile.readAsBytes();
                                            final doc = await PdfDocument.openData(fileData);
                                            setModalState(() {
                                              pagesController.text = doc.pages.length.toString();
                                            });
                                            doc.dispose();
                                          } catch (e) {
                                            debugPrint("Erro ao contar páginas PDF: $e");
                                          }
                                        } else if (extension == 'epub') {
                                          try {
                                            // EPUB não tem páginas físicas fixas. Usamos capítulos como estimativa ou contador
                                            final epubBook = await EpubDocument.openFile(savedFile);
                                            
                                            // Tenta contar capítulos como aproximação
                                            int count = epubBook.Chapters?.length ?? 0;
                                            
                                            // Se capítulos forem 0, tenta contar arquivos de conteúdo
                                            if (count == 0 && epubBook.Content?.Html != null) {
                                               count = epubBook.Content!.Html!.length;
                                            }
                                            
                                            if (count > 0) {
                                              setModalState(() {
                                                pagesController.text = count.toString();
                                              });
                                            }
                                          } catch (e) {
                                            debugPrint("Erro ao ler EPUB: $e");
                                          }
                                        }
                                        
                                      } catch (e) {
                                        if(mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar ebook: $e")));
                                        }
                                      }
                                    }
                                  },
                                ),
                                if (currentEbookPath != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(path.basename(currentEbookPath!), style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis),
                                  )
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(controller: titleController, decoration: const InputDecoration(labelText: "Título")),
                    const SizedBox(height: 10),
                    TextField(controller: authorController, decoration: const InputDecoration(labelText: "Autor")),
                    const SizedBox(height: 10),
                    TextField(controller: publisherController, decoration: const InputDecoration(labelText: "Editora")),
                    const SizedBox(height: 10),
                    TextField(controller: dateController, readOnly: true, decoration: const InputDecoration(labelText: "Comprou em", suffixIcon: Icon(Icons.calendar_today, size: 16)), onTap: () async { final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(1900), lastDate: DateTime(2100)); if (picked != null) { selectedDate = picked; dateController.text = DateFormat('dd/MM/yyyy').format(picked); } }),
                    const SizedBox(height: 10),
                    Row(children: [Expanded(child: TextField(controller: genreController, decoration: const InputDecoration(labelText: "Gênero"))), const SizedBox(width: 12), Expanded(child: TextField(controller: pagesController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Páginas")))]),
                    const SizedBox(height: 10),
                    TextField(controller: priceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "Preço (R\$)", prefixIcon: Icon(Icons.attach_money))),
                    const SizedBox(height: 10),
                    CheckboxListTile(title: const Text("Já li este livro"), subtitle: const Text("Marcar como concluído"), value: alreadyRead, onChanged: (val) { setModalState(() { alreadyRead = val!; }); }),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () async {
                        if (titleController.text.isEmpty) return;
                        int totalPages = int.tryParse(pagesController.text) ?? 0;
                        int currentPage = alreadyRead ? totalPages : (book?.currentPage ?? 0);
                        bool isRead = alreadyRead ? true : (book?.isRead ?? false);
                        
                        final newBook = Book(
                          id: book?.id, title: titleController.text, author: authorController.text, publisher: publisherController.text, genre: genreController.text,
                          pageCount: totalPages, price: double.tryParse(priceController.text.replaceAll(',', '.')) ?? 0.0,
                          isRead: isRead, currentPage: currentPage, dateAcquired: selectedDate, imagePath: currentImagePath,
                          rating: book?.rating ?? 0.0, review: book?.review, startDate: book?.startDate, targetDate: targetDate,
                          isPaused: book?.isPaused ?? false, lastPauseDate: book?.lastPauseDate,
                          ebookPath: currentEbookPath, // Salva o caminho
                        );
                        isEditing ? await DatabaseHelper.instance.update(newBook) : await DatabaseHelper.instance.create(newBook);
                        refreshBooks();
                        searchController.clear();
                        if (mounted) Navigator.pop(ctx);
                      },
                      child: const Text("Salvar"),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// --- TELA DE DETALHES COMPLETA ---
class BookDetailsScreen extends StatefulWidget {
  final Book book;
  const BookDetailsScreen({super.key, required this.book});
  @override
  State<BookDetailsScreen> createState() => _BookDetailsScreenState();
}

class _BookDetailsScreenState extends State<BookDetailsScreen> {
  late Future<List<ReadingSession>> history;
  late Future<List<Quote>> quotes; 
  late Book currentBook; // Variável de estado para o livro atualizado

  @override
  void initState() { 
    super.initState(); 
    currentBook = widget.book; // Inicializa com o livro passado
    history = DatabaseHelper.instance.getHistory(currentBook.id!);
    quotes = DatabaseHelper.instance.getQuotes(currentBook.id!);
  }
  
  // Função para recarregar os dados do livro do banco
  Future<void> _refreshBook() async {
    final books = await DatabaseHelper.instance.readAllBooks();
    try {
      final updated = books.firstWhere((b) => b.id == currentBook.id);
      setState(() {
        currentBook = updated;
        history = DatabaseHelper.instance.getHistory(currentBook.id!);
        quotes = DatabaseHelper.instance.getQuotes(currentBook.id!);
      });
    } catch (e) {
      // Livro pode ter sido deletado
    }
  }
  
  Future<void> _deleteQuote(int id) async {
    await DatabaseHelper.instance.deleteQuote(id);
    setState(() {
      quotes = DatabaseHelper.instance.getQuotes(currentBook.id!);
    });
  }

  // --- LÓGICA DE ABRIR EBOOK MODIFICADA ---
  void _openEbook() async {
    // Verifica usando o estado atualizado (currentBook)
    if (currentBook.startDate == null) {
      _showStartReadingDialog(context, currentBook, onConfirm: () {
        // Após iniciar (salvar no banco), atualizamos o estado local e abrimos
        _refreshBook().then((_) {
           _realOpenEbook(currentBook);
        });
      });
      return; 
    }
    
    _realOpenEbook(currentBook);
  }

  void _realOpenEbook(Book book) {
    if (book.ebookPath == null) return;
    String pathStr = book.ebookPath!.trim();
    
    // Verificação de existência mais robusta
    if (!File(pathStr).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Arquivo não encontrado. Talvez tenha sido movido.")));
      return;
    }

    // Verificação de extensão case-insensitive
    if (pathStr.toLowerCase().endsWith('.pdf')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PDFReaderScreen(book: book), 
        ),
      ).then((_) => _refreshBook()); // Recarrega os dados ao voltar do PDF
    } 
    else if (pathStr.toLowerCase().endsWith('.epub')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EpubReaderScreen(book: book), 
        ),
      ).then((_) => _refreshBook()); // Recarrega os dados ao voltar do Epub
    } else {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Formato não suportado: ${path.extension(pathStr)}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Usamos currentBook em vez de widget.book para garantir dados atualizados
    final dateFormatted = DateFormat('dd/MM/yyyy').format(currentBook.dateAcquired);
    final targetFormatted = currentBook.targetDate != null ? DateFormat('dd/MM/yyyy').format(currentBook.targetDate!) : "Não definida";
    final startFormatted = currentBook.startDate != null ? DateFormat('dd/MM/yyyy').format(currentBook.startDate!) : "Não iniciado";
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text("Detalhes")),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (currentBook.imagePath != null)
              Container(height: 250, width: double.infinity, decoration: BoxDecoration(image: DecorationImage(image: FileImage(File(currentBook.imagePath!)), fit: BoxFit.cover)))
            else
              Container(height: 150, width: double.infinity, color: isDark ? Colors.grey[800] : Colors.deepPurple[100], child: const Icon(Icons.menu_book, size: 80, color: Colors.deepPurple)),
            
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(currentBook.title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  Text(currentBook.author, style: const TextStyle(fontSize: 18, color: Colors.grey)),
                  
                  if (currentBook.rating > 0) ...[
                    const SizedBox(height: 10),
                    Row(children: [RatingBarIndicator(rating: currentBook.rating, itemBuilder: (context, index) => const Icon(Icons.star, color: Colors.amber), itemCount: 5, itemSize: 24.0), const SizedBox(width: 8), Text("${currentBook.rating}/5", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                  ],

                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: currentBook.progress, minHeight: 10, borderRadius: BorderRadius.circular(5), color: currentBook.getUrgencyColor(), backgroundColor: isDark ? Colors.grey[700] : Colors.grey[200]),
                  const SizedBox(height: 5),
                  Text("${(currentBook.progress * 100).toInt()}% Concluído (${currentBook.currentPage}/${currentBook.pageCount})"),
                  
                  if (currentBook.isPaused)
                    Container(margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(5)), child: const Row(children: [Icon(Icons.pause, size: 16, color: Colors.orange), SizedBox(width: 5), Text("Leitura Pausada", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))])),

                  // --- BOTÃO DE LER EBOOK (GRANDE) ---
                  if (currentBook.ebookPath != null) ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: _openEbook, // Chama a função com lógica de meta
                          icon: const Icon(Icons.menu_book),
                          label: const Text("LER EBOOK AGORA"),
                          style: FilledButton.styleFrom(backgroundColor: Colors.deepPurple),
                        ),
                      ),
                  ],

                  if (currentBook.review != null && currentBook.review!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text("Minha Resenha", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Container(width: double.infinity, margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.amber[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.grey[700]! : Colors.amber[200]!)), child: Text(currentBook.review!, style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 15)))
                  ],

                  const SizedBox(height: 20),
                  const Text("Informações Técnicas", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  _buildInfoRow(Icons.business, "Editora", currentBook.publisher),
                  _buildInfoRow(Icons.category, "Gênero", currentBook.genre),
                  _buildInfoRow(Icons.file_copy, "Páginas", "${currentBook.pageCount}"),
                  _buildInfoRow(Icons.monetization_on, "Preço", "R\$ ${currentBook.price.toStringAsFixed(2)}"),
                  _buildInfoRow(Icons.calendar_today, "Comprou", dateFormatted),
                  _buildInfoRow(Icons.start, "Iniciou", startFormatted),
                  _buildInfoRow(Icons.flag, "Meta", targetFormatted),

                  const SizedBox(height: 20),
                  Center(child: Chip(label: Text(currentBook.isRead ? "Lido" : "Lendo / Não Lido"), backgroundColor: currentBook.isRead ? Colors.green.shade900 : Colors.orange.shade900, labelStyle: const TextStyle(color: Colors.white), avatar: Icon(currentBook.isRead ? Icons.check_circle : Icons.hourglass_empty, color: Colors.white))),

                  // --- SEÇÃO DE CITAÇÕES (QUOTES) ---
                  const SizedBox(height: 30),
                  const Text("Citações Favoritas", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  FutureBuilder<List<Quote>>(
                    future: quotes,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text("Nenhuma citação salva.", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                        );
                      }
                      return Column(
                        children: snapshot.data!.map((quote) => Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          elevation: 1,
                          color: isDark ? Colors.grey[800] : Colors.amber[50], // Estilo de "post-it"
                          child: ListTile(
                            leading: const Icon(Icons.format_quote, color: Colors.amber),
                            title: Text(quote.text, style: const TextStyle(fontStyle: FontStyle.italic)),
                            subtitle: Text("Página: ${quote.page}"),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                              onPressed: () => _deleteQuote(quote.id!),
                            ),
                          ),
                        )).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 30),
                  const Text("Histórico de Leitura", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  FutureBuilder<List<ReadingSession>>(
                    future: history,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) return const Text("Nenhum registro ainda.", style: TextStyle(fontStyle: FontStyle.italic));
                      return ListView.separated(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: snapshot.data!.length, separatorBuilder: (context, index) => const Divider(height: 1), itemBuilder: (context, index) { final session = snapshot.data![index]; return ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.history_edu, color: Colors.blueGrey), title: Text(DateFormat('dd/MM/yyyy - HH:mm').format(session.date)), subtitle: Text("Avançou até a página ${session.pageStopped}")); });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [Icon(icon, size: 20, color: Colors.deepPurple[300]), const SizedBox(width: 10), Text("$label:", style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(width: 5), Expanded(child: Text(value))]));
  }

  // --- DIALOGO DE INICIAR LEITURA REUTILIZADO ---
  void _showStartReadingDialog(BuildContext context, Book book, {VoidCallback? onConfirm}) {
    DateTime targetDate = DateTime.now().add(const Duration(days: 30));
    
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text("Iniciar Leitura 🚀"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Vamos começar! Quando você pretende terminar este livro?"),
                const SizedBox(height: 20),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: targetDate, firstDate: DateTime.now(), lastDate: DateTime(2100));
                    if (picked != null) setState(() => targetDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(border: Border.all(color: Colors.blue), borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.flag, color: Colors.blue), const SizedBox(width: 8), Text(DateFormat('dd/MM/yyyy').format(targetDate), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
                  ),
                )
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
              FilledButton(
                onPressed: () async {
                  final updatedBook = Book(
                    id: book.id, title: book.title, author: book.author, publisher: book.publisher, genre: book.genre,
                    pageCount: book.pageCount, price: book.price, dateAcquired: book.dateAcquired,
                    currentPage: book.currentPage, isRead: book.isRead, imagePath: book.imagePath,
                    startDate: DateTime.now(),
                    targetDate: targetDate,
                    ebookPath: book.ebookPath, // Mantém o ebook
                  );
                  await DatabaseHelper.instance.update(updatedBook);
                  _refreshBook(); // <--- CORREÇÃO: Usando _refreshBook() (singular)
                  if (mounted) Navigator.pop(ctx);
                  
                  if (onConfirm != null) onConfirm();
                },
                child: const Text("Iniciar"),
              ),
            ],
          );
        });
      },
    );
  }
}

// --- TELA LEITOR DE PDF (CORRIGIDA E ATUALIZADA) ---
class PDFReaderScreen extends StatefulWidget {
  final Book book;
  const PDFReaderScreen({super.key, required this.book});

  @override
  State<PDFReaderScreen> createState() => _PDFReaderScreenState();
}

class _PDFReaderScreenState extends State<PDFReaderScreen> {
  late PdfViewerController _pdfController;
  int currentPage = 0;
  int initialPage = 0;
  int totalPages = 0;
  
  // Define se a rolagem é horizontal (livro) ou vertical (infinita)
  bool _isHorizontal = true; 

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    // Garante que a página inicial seja pelo menos 1
    int startPage = widget.book.currentPage > 0 ? widget.book.currentPage : 1;
    currentPage = startPage;
    initialPage = startPage;
  }

  // Alterna entre modo Vertical (Rolagem) e Horizontal (Paginação)
  void _toggleOrientation() {
    setState(() {
      _isHorizontal = !_isHorizontal;
    });
  }

  // Salva o progresso no banco de dados local
  Future<void> _updateBookProgress(int page) async {
    if (page != widget.book.currentPage) {
      final updatedBook = Book(
        id: widget.book.id,
        title: widget.book.title,
        author: widget.book.author,
        publisher: widget.book.publisher,
        genre: widget.book.genre,
        pageCount: widget.book.pageCount,
        price: widget.book.price,
        dateAcquired: widget.book.dateAcquired,
        currentPage: page,
        isRead: widget.book.isRead,
        imagePath: widget.book.imagePath,
        rating: widget.book.rating,
        review: widget.book.review,
        startDate: widget.book.startDate,
        targetDate: widget.book.targetDate,
        isPaused: widget.book.isPaused,
        lastPauseDate: widget.book.lastPauseDate,
        ebookPath: widget.book.ebookPath,
      );
      await DatabaseHelper.instance.update(updatedBook);
    }
  }

  // Salva a sessão no histórico ao sair da tela
  Future<void> _saveSessionHistory() async {
    // Se avançou pelo menos 1 página em relação ao início da sessão
    if (currentPage > initialPage) {
      await DatabaseHelper.instance.addSession(
        ReadingSession(
          bookId: widget.book.id!,
          date: DateTime.now(),
          pageStopped: currentPage,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Leitura salva! Você parou na pág $currentPage.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _saveSessionHistory();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.book.title, style: const TextStyle(fontSize: 16)),
          actions: [
            // Botão para alternar orientação
            IconButton(
              icon: Icon(_isHorizontal ? Icons.swap_vert : Icons.swap_horiz),
              tooltip: _isHorizontal ? "Mudar para Rolagem Vertical" : "Mudar para Paginação Lateral",
              onPressed: _toggleOrientation,
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text("$currentPage / ${totalPages > 0 ? totalPages : '-'}"),
              ),
            )
          ],
        ),
        body: PdfViewer.file(
          widget.book.ebookPath!,
          controller: _pdfController,
          // Usamos uma Key baseada na orientação para forçar o recarregamento do layout
          key: ValueKey(_isHorizontal),
          
          // Importante: Ao recriar (mudar orientação), usa a página ATUAL como inicial
          initialPageNumber: currentPage,
          
          // --- CONFIGURAÇÃO CORRETA DO PDFRX ---
          params: PdfViewerParams(
            // Define o layout: Horizontal ou Vertical dinamicamente
            layoutPages: (pages, params) {
              final double gap = 8.0;
              double currentOffset = 0.0;
              double maxCrossAxis = 0.0;
              final pageLayouts = <Rect>[]; // Alterado de pageOffsets (Offset) para pageLayouts (Rect)

              if (_isHorizontal) {
                // Layout Horizontal
                for (var page in pages) {
                  // Cria um Rect para representar a página
                  pageLayouts.add(Rect.fromLTWH(currentOffset, 0, page.width, page.height));
                  currentOffset += page.width + gap;
                  if (page.height > maxCrossAxis) maxCrossAxis = page.height;
                }
                return PdfPageLayout(
                  pageLayouts: pageLayouts, // Parâmetro correto: pageLayouts
                  documentSize: Size(currentOffset > 0 ? currentOffset - gap : 0, maxCrossAxis),
                );
              } else {
                // Layout Vertical
                for (var page in pages) {
                  // Cria um Rect para representar a página
                  pageLayouts.add(Rect.fromLTWH(0, currentOffset, page.width, page.height));
                  currentOffset += page.height + gap;
                  if (page.width > maxCrossAxis) maxCrossAxis = page.width;
                }
                return PdfPageLayout(
                  pageLayouts: pageLayouts, // Parâmetro correto: pageLayouts
                  documentSize: Size(maxCrossAxis, currentOffset > 0 ? currentOffset - gap : 0),
                );
              }
            },
            onPageChanged: (pageNumber) {
              if (pageNumber != null) {
                setState(() {
                  currentPage = pageNumber;
                  // Atualiza o total de páginas se ainda não estiver definido
                  if (totalPages == 0 && _pdfController.pages.isNotEmpty) {
                    totalPages = _pdfController.pages.length;
                  }
                });
                _updateBookProgress(pageNumber);
              }
            },
            // onViewerReady substitui o antigo onDocumentLoaded para pegar infos iniciais
            onViewerReady: (document, controller) {
              setState(() {
                totalPages = controller.pages.length;
              });
            },
            // Melhoria visual: define cor de fundo e garante que não seja nula com '!'
            backgroundColor: Colors.grey[200]!, 
          ),
          // ---------------------
        ),
      ),
    );
  }
}

// --- TELA LEITOR DE EPUB ---
class EpubReaderScreen extends StatefulWidget {
  final Book book;
  const EpubReaderScreen({super.key, required this.book});

  @override
  State<EpubReaderScreen> createState() => _EpubReaderScreenState();
}

class _EpubReaderScreenState extends State<EpubReaderScreen> {
  late EpubController _epubController;

  @override
  void initState() {
    super.initState();
    _epubController = EpubController(
      document: EpubDocument.openFile(File(widget.book.ebookPath!)),
    );
  }

  @override
  void dispose() {
    _epubController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: EpubViewActualChapter(
          controller: _epubController,
          builder: (chapterValue) => Text(
            chapterValue?.chapter?.Title?.replaceAll('\n', '').trim() ?? 'Lendo...',
            textAlign: TextAlign.start,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
      drawer: Drawer(
        child: EpubViewTableOfContents(controller: _epubController),
      ),
      body: EpubView(
        controller: _epubController,
        onDocumentLoaded: (document) {
        },
        onChapterChanged: (value) {
            // Lógica de salvar para EPUB
        },
      ),
    );
  }
}