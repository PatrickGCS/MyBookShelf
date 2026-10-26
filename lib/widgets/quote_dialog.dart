import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../models/book.dart';

void showQuoteDialog(BuildContext context, Book book) {
  final rootContext = context;
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
            if (rootContext.mounted) {
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
