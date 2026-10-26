import 'dart:async';
import 'dart:io';
import 'package:epub_view/epub_view.dart';
import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../models/book.dart';
import '../services/file_storage.dart';

// --- TELA LEITOR DE EPUB ---
class EpubReaderScreen extends StatefulWidget {
  final Book book;
  const EpubReaderScreen({super.key, required this.book});

  @override
  State<EpubReaderScreen> createState() => _EpubReaderScreenState();
}

class _EpubReaderScreenState extends State<EpubReaderScreen> with WidgetsBindingObserver {
  late EpubController _epubController;

  // "Página" do EPUB = número do capítulo (EPUB não tem páginas fixas)
  late int _currentChapter = widget.book.currentPage;
  late final int _initialChapter = widget.book.currentPage;
  late String? _lastSavedCfi = widget.book.epubCfi;
  late int _lastSavedChapter = widget.book.currentPage;
  Timer? _saveDebounce;
  bool _sessionSaved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _epubController = EpubController(
      document: EpubDocument.openFile(File(FileStorage.instance.resolve(widget.book.ebookPath)!)),
      // Retoma exatamente de onde parou (se houver posição salva)
      epubCfi: widget.book.epubCfi,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _flushProgress();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flushProgress();
    _epubController.dispose();
    super.dispose();
  }

  void _onChapterChanged(EpubChapterViewValue? value) {
    if (value == null) return;
    _currentChapter = value.chapterNumber;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 1), _saveProgress);
  }

  Future<void> _flushProgress() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    await _saveProgress();
  }

  Future<void> _saveProgress() async {
    String? cfi;
    try {
      cfi = _epubController.generateEpubCfi();
    } catch (_) {
      cfi = null;
    }
    final total = widget.book.pageCount;
    final chapter = total > 0 && _currentChapter > total ? total : _currentChapter;
    if (cfi == _lastSavedCfi && chapter == _lastSavedChapter) return;
    _lastSavedCfi = cfi;
    _lastSavedChapter = chapter;
    await DatabaseHelper.instance.update(
      widget.book.copyWith(currentPage: chapter, epubCfi: cfi),
    );
  }

  // Registra a sessão de leitura ao sair (se avançou de capítulo)
  Future<void> _saveSession() async {
    if (_sessionSaved || widget.book.id == null) return;
    if (_currentChapter > _initialChapter) {
      _sessionSaved = true;
      await DatabaseHelper.instance.addSession(
        ReadingSession(bookId: widget.book.id!, date: DateTime.now(), pageStopped: _currentChapter),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) async {
        await _flushProgress();
        await _saveSession();
      },
      child: Scaffold(
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
          onChapterChanged: _onChapterChanged,
        ),
      ),
    );
  }
}
