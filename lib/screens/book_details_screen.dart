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
              Semantics(image: true, label: 'Capa de ${currentBook.title}', child: Container(height: 250, width: double.infinity, decoration: BoxDecoration(image: DecorationImage(image: ResizeImage(FileImage(File(FileStorage.instance.resolve(currentBook.imagePath)!)), width: 1080), fit: BoxFit.cover))))
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
                  LinearProgressIndicator(semanticsLabel: 'Progresso da leitura', value: currentBook.progress, minHeight: 10, borderRadius: BorderRadius.circular(5), color: currentBook.getUrgencyColor(), backgroundColor: isDark ? Colors.grey[700] : Colors.grey[200]),
                  const SizedBox(height: 5),
                  Text("${(currentBook.progress * 100).toInt()}% Concluído (${currentBook.currentPage}/${currentBook.pageCount})"),
                  
                  if (currentBook.isPaused)
                    Container(margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(5)), child: const Row(children: [Icon(Icons.pause, size: 16, color: Colors.orange), SizedBox(width: 5), Text("Leitura Pausada", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))])),

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
                              tooltip: 'Excluir citação',
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

}
