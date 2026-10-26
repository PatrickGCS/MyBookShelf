import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/database_helper.dart';
import '../models/book.dart';
import '../theme/mbs_palette.dart';
import 'glass.dart';

Future<void> showStartReadingDialog(BuildContext context, Book book, {VoidCallback? onConfirm}) {
  DateTime targetDate = DateTime.now().add(const Duration(days: 30));
  
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(builder: (context, setState) {
        final p = MbsPalette.of(ctx);
        return MbsDialog(
          title: const Text("Iniciar leitura"),
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
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: p.blue.withValues(alpha: 0.14),
                    border: Border.all(color: p.blue.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.flag_outlined, color: p.blue), const SizedBox(width: 10), Text(DateFormat('dd/MM/yyyy').format(targetDate), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.blue))]),
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
