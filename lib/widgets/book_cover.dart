import 'dart:io';
import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/file_storage.dart';

/// Capa do livro com a linha de lombada do brandbook.
/// Sem imagem, usa um gradiente azul/terracota derivado do título.
class BookCover extends StatelessWidget {
  const BookCover({super.key, required this.book, this.width = 54, this.height = 80});
  final Book book;
  final double width;
  final double height;

  static const _gradients = <List<Color>>[
    [Color(0xFF4B7FCF), Color(0xFF1B3A70)],
    [Color(0xFFE0894A), Color(0xFF8A3F12)],
    [Color(0xFF6C8FB8), Color(0xFF2A3F66)],
    [Color(0xFF3C6FA8), Color(0xFF12294D)],
  ];

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft: Radius.circular(width * 0.11),
      bottomLeft: Radius.circular(width * 0.11),
      topRight: Radius.circular(width * 0.19),
      bottomRight: Radius.circular(width * 0.19),
    );
    final resolvedPath = FileStorage.instance.resolve(book.imagePath);
    final String? imageFile =
        (resolvedPath != null && File(resolvedPath).existsSync()) ? resolvedPath : null;
    final colors = _gradients[book.title.length % _gradients.length];

    return Semantics(
      image: true,
      label: 'Capa de ${book.title}',
      child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [BoxShadow(color: Color(0x59030814), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageFile != null)
              Image.file(File(imageFile), fit: BoxFit.cover, cacheWidth: 300)
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                ),
              ),
            Positioned(
              left: width * 0.11,
              top: 0,
              bottom: 0,
              width: 2,
              child: ColoredBox(color: Colors.white.withValues(alpha: 0.3)),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
