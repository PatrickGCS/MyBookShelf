import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../data/database_helper.dart';
import '../models/book.dart';

void showLogReadingDialog(BuildContext context, Book book, {required VoidCallback onChanged}) {
  final rootContext = context;
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

                            final updatedBook = book.copyWith(isPaused: false, targetDate: newTarget, clearTargetDate: newTarget == null, clearLastPauseDate: true);
                            await DatabaseHelper.instance.update(updatedBook);
                            if (rootContext.mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Leitura retomada! Meta adiada em $daysPaused dias."))); }
                          } else {
                            final updatedBook = book.copyWith(isPaused: true, lastPauseDate: DateTime.now());
                            await DatabaseHelper.instance.update(updatedBook);
                            if (rootContext.mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Leitura pausada."))); }
                          }
                          onChanged();
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
                    
                    final finishing = isFinished || book.isRead;
                    final updatedBook = book.copyWith(
                      currentPage: newPage,
                      isRead: isFinished || newPage == book.pageCount,
                      rating: finishing ? currentRating : null,
                      review: finishing ? reviewController.text : null,
                      isPaused: false,
                    );
                    
                    await DatabaseHelper.instance.update(updatedBook);
                    if (newPage != book.currentPage) {
                      await DatabaseHelper.instance.addSession(ReadingSession(bookId: book.id!, date: DateTime.now(), pageStopped: newPage));
                    }
                    onChanged();
                    if (ctx.mounted) Navigator.pop(ctx);
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
