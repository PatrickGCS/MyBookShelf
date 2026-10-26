import 'dart:io';
import 'package:epub_view/epub_view.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:pdfrx/pdfrx.dart';
import '../data/database_helper.dart';
import '../models/book.dart';
import '../services/book_lookup_service.dart';
import '../services/file_storage.dart';
import '../theme/mbs_palette.dart';
import 'cover_search_sheet.dart';

void showBookForm(BuildContext context, {Book? book, required VoidCallback onChanged}) {
  final rootContext = context;
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

  final palette = MbsPalette.of(context);
  showModalBottomSheet(
    context: context, isScrollControlled: true,
    backgroundColor: palette.dialogFill,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          final p = MbsPalette.of(context);
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 4, left: 20, right: 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(isEditing ? "Editar livro" : "Novo livro", style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- FOTO ---
                      GestureDetector(
                        onTap: () async {
                          final ImagePicker picker = ImagePicker();
                          showModalBottomSheet(context: context, backgroundColor: p.dialogFill, builder: (bsContext) { return SafeArea(child: Wrap(children: [ListTile(leading: const Icon(Icons.photo_camera), title: const Text('Câmera'), onTap: () async { final XFile? photo = await picker.pickImage(source: ImageSource.camera); if (photo != null) { final saved = await FileStorage.instance.saveCover(photo.path); setModalState(() => currentImagePath = saved); } if (bsContext.mounted) Navigator.pop(bsContext); }), ListTile(leading: const Icon(Icons.photo_library), title: const Text('Galeria'), onTap: () async { final XFile? photo = await picker.pickImage(source: ImageSource.gallery); if (photo != null) { final saved = await FileStorage.instance.saveCover(photo.path); setModalState(() => currentImagePath = saved); } if (bsContext.mounted) Navigator.pop(bsContext); })])); });
                        },
                        child: Container(height: 120, width: 80, decoration: BoxDecoration(color: p.glassFill, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.glassBorder), image: currentImagePath != null ? DecorationImage(image: ResizeImage(FileImage(File(FileStorage.instance.resolve(currentImagePath)!)), width: 240), fit: BoxFit.cover) : null), child: currentImagePath == null ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo_outlined, size: 28, color: p.muted), Text("Capa", style: TextStyle(fontSize: 11, color: p.muted))]) : null),
                      ),
                      const SizedBox(width: 15),
                      // --- BOTÃO EBOOK (NOVO) ---
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.upload_file),
                                label: Text(currentEbookPath == null ? "Importar ebook (PDF/EPUB)" : "Ebook selecionado"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: currentEbookPath != null ? p.blue : p.text,
                                  side: BorderSide(color: currentEbookPath != null ? p.blue : p.glassBorder),
                                ),
                                onPressed: () async {
                                  // Selecionar PDF ou EPUB
                                  FilePickerResult? result = await FilePicker.platform.pickFiles(
                                    type: FileType.custom,
                                    allowedExtensions: ['pdf', 'epub'],
                                  );
                                  
                                  if(result != null) {
                                    PlatformFile file = result.files.first;
                                    
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

                                    String savedPath = '';
                                    File savedFile = File('');

                                    try {
                                      // 3. Copia em streaming para a pasta do app, com nome único
                                      if (file.path != null) {
                                        savedPath = await FileStorage.instance.saveEbook(file.path!, extension);
                                        savedFile = File(FileStorage.instance.resolve(savedPath)!);
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
                                      if (rootContext.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar ebook: $e")));
                                      }
                                    }
                                  }
                                },
                              ),
                              if (currentEbookPath != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(path.basename(currentEbookPath!), style: TextStyle(fontSize: 12, color: p.muted), overflow: TextOverflow.ellipsis),
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
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: p.blue),
                      icon: const Icon(Icons.image_search),
                      label: const Text("Buscar capa e dados online"),
                      onPressed: () async {
                        final title = titleController.text.trim();
                        if (title.isEmpty) {
                          ScaffoldMessenger.of(rootContext).showSnackBar(const SnackBar(content: Text("Digite o título para buscar.")));
                          return;
                        }
                        final lookup = BookLookupService();
                        try {
                          final picked = await showCoverSearch(context, service: lookup, title: title, author: authorController.text);
                          if (picked == null) return;

                          // Baixa a capa (tenta as URLs em ordem) e guarda no armazenamento do app
                          final cover = picked.hasCover ? await lookup.downloadCover(picked) : null;
                          String? savedCover;
                          if (cover != null) {
                            savedCover = await FileStorage.instance.saveCoverBytes(cover.bytes, ext: cover.extension);
                          }

                          setModalState(() {
                            if (savedCover != null) {
                              // Descarta a capa baixada anteriormente nesta tela, se não for a original do livro
                              if (currentImagePath != null && currentImagePath != book?.imagePath) {
                                FileStorage.instance.delete(currentImagePath);
                              }
                              currentImagePath = savedCover;
                            }
                            // Preenche apenas campos vazios; nunca sobrescreve o que o usuário digitou
                            if (authorController.text.trim().isEmpty && picked.authorText.isNotEmpty) authorController.text = picked.authorText;
                            if (publisherController.text.trim().isEmpty && picked.publisher != null) publisherController.text = picked.publisher!;
                            if (genreController.text.trim().isEmpty && picked.genre != null) genreController.text = picked.genre!;
                            if ((int.tryParse(pagesController.text) ?? 0) == 0 && picked.pageCount != null) pagesController.text = picked.pageCount.toString();
                          });

                          if (rootContext.mounted) {
                            ScaffoldMessenger.of(rootContext).showSnackBar(SnackBar(
                              content: Text(picked.hasCover && cover == null
                                  ? "Dados preenchidos, mas não foi possível baixar a capa."
                                  : (cover == null ? "Dados preenchidos (este livro não tem capa online)." : "Capa e dados aplicados!")),
                            ));
                          }
                        } finally {
                          lookup.dispose();
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: publisherController, decoration: const InputDecoration(labelText: "Editora")),
                  const SizedBox(height: 10),
                  TextField(controller: dateController, readOnly: true, decoration: const InputDecoration(labelText: "Comprou em", suffixIcon: Icon(Icons.calendar_today, size: 16)), onTap: () async { final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(1900), lastDate: DateTime(2100)); if (picked != null) { selectedDate = picked; dateController.text = DateFormat('dd/MM/yyyy').format(picked); } }),
                  const SizedBox(height: 10),
                  Row(children: [Expanded(child: TextField(controller: genreController, decoration: const InputDecoration(labelText: "Gênero"))), const SizedBox(width: 12), Expanded(child: TextField(controller: pagesController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Páginas")))]),
                  const SizedBox(height: 10),
                  TextField(controller: priceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "Preço (R\$)", prefixIcon: Icon(Icons.attach_money_rounded))),
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
                          // Mantém a posição do EPUB, exceto se o arquivo foi trocado/removido
                          epubCfi: currentEbookPath == book?.ebookPath ? book?.epubCfi : null,
                      );
                      isEditing ? await DatabaseHelper.instance.update(newBook) : await DatabaseHelper.instance.create(newBook);
                      // Remove arquivos antigos que foram substituídos/removidos no formulário
                      if (book?.imagePath != null && book!.imagePath != currentImagePath) await FileStorage.instance.delete(book.imagePath);
                      if (book?.ebookPath != null && book!.ebookPath != currentEbookPath) await FileStorage.instance.delete(book.ebookPath);
                      onChanged();
                      if (ctx.mounted) Navigator.pop(ctx);
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
