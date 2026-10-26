import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/database_helper.dart';
import '../models/book.dart';

Future<void> showStartReadingDialog(BuildContext context, Book book, {VoidCallback? onConfirm}) {
  DateTime targetDate = DateTime.now().add(const Duration(days: 30));
  
  return showDialog<void>(
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
                final updatedBook = book.copyWith(startDate: DateTime.now(), targetDate: targetDate);
                await DatabaseHelper.instance.update(updatedBook);
                if (ctx.mounted) Navigator.pop(ctx);
                onConfirm?.call();
              },
              child: const Text("Iniciar"),
            ),
          ],
        );
      });
    },
  );
}
