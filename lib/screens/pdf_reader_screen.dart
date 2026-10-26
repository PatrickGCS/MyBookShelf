import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import '../data/database_helper.dart';
import '../models/book.dart';
import '../services/file_storage.dart';

class PDFReaderScreen extends StatefulWidget {
  final Book book;
  const PDFReaderScreen({super.key, required this.book});

  @override
  State<PDFReaderScreen> createState() => _PDFReaderScreenState();
}

class _PDFReaderScreenState extends State<PDFReaderScreen> with WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
  }

  Timer? _saveDebounce;
  late int _lastSavedPage = widget.book.currentPage;
  bool _sessionSaved = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App indo para segundo plano pode ser encerrado pelo sistema: grava já.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _flushProgress();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flushProgress();
    super.dispose();
  }

  void _scheduleProgressSave(int page) {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 800), () => _updateBookProgress(page));
  }

  Future<void> _flushProgress() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    await _updateBookProgress(currentPage);
  }

  // Alterna entre modo Vertical (Rolagem) e Horizontal (Paginação)
  void _toggleOrientation() {
    setState(() {
      _isHorizontal = !_isHorizontal;
    });
  }

  // Salva o progresso no banco de dados local
  Future<void> _updateBookProgress(int page) async {
    if (page != _lastSavedPage) {
      _lastSavedPage = page;
      final updatedBook = widget.book.copyWith(currentPage: page);
      await DatabaseHelper.instance.update(updatedBook);
    }
  }

  // Salva a sessão no histórico ao sair da tela
  Future<void> _saveSessionHistory() async {
    // Se avançou pelo menos 1 página em relação ao início da sessão
    if (_sessionSaved) return;
    if (currentPage > initialPage) {
      _sessionSaved = true;
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
    return PopScope(
      onPopInvokedWithResult: (didPop, result) async {
        await _flushProgress();
        await _saveSessionHistory();
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
          FileStorage.instance.resolve(widget.book.ebookPath)!,
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
                _scheduleProgressSave(pageNumber);
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
