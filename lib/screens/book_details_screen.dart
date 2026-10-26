import 'dart:io';
import 'epub_reader_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'pdf_reader_screen.dart';
import '../data/database_helper.dart';
import '../models/book.dart';
import '../services/file_storage.dart';
import '../theme/app_theme.dart';
import '../theme/mbs_palette.dart';
import '../widgets/book_cover.dart';
import '../widgets/book_form.dart';
import '../widgets/book_open_route.dart';
import '../widgets/glass.dart';
import '../widgets/pace_indicator.dart';
import '../widgets/quote_dialog.dart';
import '../widgets/start_reading_dialog.dart';

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
      showStartReadingDialog(context, currentBook, onConfirm: () {
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
    String pathStr = FileStorage.instance.resolve(book.ebookPath)!;
    
    // Verificação de existência mais robusta
    if (!File(pathStr).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Arquivo não encontrado. Talvez tenha sido movido.")));
      return;
    }

    // Verificação de extensão case-insensitive
    if (pathStr.toLowerCase().endsWith('.pdf')) {
      Navigator.push(
        context,
        BookOpenRoute<void>(
          cover: BookCover(book: book, width: 124, height: 186),
          reduceMotion: MediaQuery.of(context).disableAnimations,
          builder: (context) => PDFReaderScreen(book: book),
        ),
      ).then((_) => _refreshBook()); // Recarrega os dados ao voltar do PDF
    } 
    else if (pathStr.toLowerCase().endsWith('.epub')) {
      Navigator.push(
        context,
        BookOpenRoute<void>(
          cover: BookCover(book: book, width: 124, height: 186),
          reduceMotion: MediaQuery.of(context).disableAnimations,
          builder: (context) => EpubReaderScreen(book: book),
        ),
      ).then((_) => _refreshBook()); // Recarrega os dados ao voltar do Epub
    } else {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Formato não suportado: ${path.extension(pathStr)}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = MbsPalette.of(context);
    final book = currentBook;
    final dateFormatted = DateFormat('dd/MM/yyyy').format(book.dateAcquired);
    final targetFormatted = book.targetDate != null ? DateFormat('dd/MM/yyyy').format(book.targetDate!) : "Não definida";
    final startFormatted = book.startDate != null ? DateFormat('dd/MM/yyyy').format(book.startDate!) : "Não iniciado";
    final started = book.startDate != null && book.currentPage > 0;

    return MbsBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: MbsPalette.of(context).text,
          leading: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: GlassIconButton(icon: Icons.arrow_back_ios_new_rounded, tooltip: 'Voltar', onPressed: () => Navigator.maybePop(context)),
          ),
          leadingWidth: 56,
          actions: [
            GlassIconButton(
              icon: Icons.edit_outlined,
              tooltip: 'Editar livro',
              onPressed: () => showBookForm(context, book: book, onChanged: _refreshBook),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: BookCover(book: book, width: 124, height: 186)),
              const SizedBox(height: 18),
              Text(book.title, textAlign: TextAlign.center, style: AppTheme.display(p.text, 32, height: 1.25)),
              const SizedBox(height: 4),
              Text(book.author, textAlign: TextAlign.center, style: AppTheme.body(p.muted, 15)),
              if (book.rating > 0) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RatingBarIndicator(rating: book.rating, itemBuilder: (context, index) => Icon(Icons.star_rounded, color: p.amber), itemCount: 5, itemSize: 22.0),
                    const SizedBox(width: 8),
                    Text("${book.rating}/5", style: AppTheme.body(p.text, 14, weight: FontWeight.w600)),
                  ],
                ),
              ],
              const SizedBox(height: 18),

              // PROGRESSO
              GlassCard(
                radius: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("${(book.progress * 100).toInt()}%", style: AppTheme.display(p.text, 34, height: 1.2)),
                        Text("${book.currentPage} de ${book.pageCount} páginas", style: AppTheme.body(p.muted, 13)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    MbsProgressBar(value: book.progress, height: 8),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Meta: $targetFormatted", style: AppTheme.body(p.muted, 12)),
                        PaceIndicator(book: book),
                      ],
                    ),
                  ],
                ),
              ),

              // BOTÃO DE LER EBOOK
              if (book.ebookPath != null) ...[
                const SizedBox(height: 16),
                MbsGradientButton(
                  label: started ? "Continuar lendo" : "Começar a ler",
                  icon: Icons.menu_book_rounded,
                  onPressed: _openEbook, // Chama a função com lógica de meta
                ),
              ],

              if (book.review != null && book.review!.isNotEmpty) ...[
                const SizedBox(height: 16),
                GlassCard(
                  soft: true,
                  radius: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Minha resenha", style: AppTheme.display(p.highlight, 19, height: 1.3)),
                      const SizedBox(height: 8),
                      Text(book.review!, style: AppTheme.body(p.text, 15, height: 1.6, style: FontStyle.italic)),
                    ],
                  ),
                ),
              ],

              // CITAÇÕES
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(child: Text("Citações favoritas", style: AppTheme.display(p.highlight, 19, height: 1.3))),
                  GlassIconButton(
                    icon: Icons.format_quote_rounded,
                    size: 40,
                    color: p.blue,
                    tooltip: 'Adicionar citação',
                    onPressed: () async {
                      await showQuoteDialog(context, book);
                      if (mounted) _refreshBook();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<Quote>>(
                future: quotes,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text("Nenhuma citação salva.", style: AppTheme.body(p.muted, 14, style: FontStyle.italic)),
                    );
                  }
                  return Column(
                    children: snapshot.data!
                        .map(
                          (quote) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GlassCard(
                              soft: true,
                              radius: 24,
                              padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("“${quote.text}”", style: AppTheme.body(p.text, 15, height: 1.6, style: FontStyle.italic)),
                                        const SizedBox(height: 6),
                                        Text("p. ${quote.page}", style: AppTheme.body(p.muted, 12)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, size: 20, color: p.rose),
                                    tooltip: 'Excluir citação',
                                    onPressed: () => _deleteQuote(quote.id!),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),

              // INFORMAÇÕES
              const SizedBox(height: 12),
              GlassCard(
                soft: true,
                radius: 24,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                child: Column(
                  children: [
                    _infoRow(p, "Gênero", book.genre),
                    _infoRow(p, "Editora", book.publisher),
                    _infoRow(p, "Páginas", "${book.pageCount}"),
                    _infoRow(p, "Preço", "R\$ ${book.price.toStringAsFixed(2)}"),
                    _infoRow(p, "Comprou", dateFormatted),
                    _infoRow(p, "Iniciou", startFormatted),
                    _infoRow(p, "Meta", targetFormatted, last: true),
                  ],
                ),
              ),

              // HISTÓRICO
              const SizedBox(height: 22),
              Text("Histórico de leitura", style: AppTheme.display(p.blue, 19, height: 1.3)),
              const SizedBox(height: 8),
              FutureBuilder<List<ReadingSession>>(
                future: history,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Text("Nenhum registro ainda.", style: AppTheme.body(p.muted, 14, style: FontStyle.italic));
                  }
                  return GlassCard(
                    soft: true,
                    radius: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    child: Column(
                      children: [
                        for (var i = 0; i < snapshot.data!.length; i++)
                          _infoRow(
                            p,
                            DateFormat('dd/MM/yyyy - HH:mm').format(snapshot.data![i].date),
                            "até a pág. ${snapshot.data![i].pageStopped}",
                            last: i == snapshot.data!.length - 1,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(MbsPalette p, String label, String value, {bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: p.glassBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTheme.body(p.muted, 14)),
          const SizedBox(width: 12),
          Flexible(child: Text(value, textAlign: TextAlign.end, style: AppTheme.body(p.text, 14))),
        ],
      ),
    );
  }
}
