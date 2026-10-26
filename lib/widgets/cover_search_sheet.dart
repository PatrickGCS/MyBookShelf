import 'package:flutter/material.dart';
import '../services/book_lookup_service.dart';

/// Abre a busca online e devolve o resultado escolhido (ou null).
/// Busca pelo [title]; se [author] estiver preenchido, refina a busca.
Future<BookCandidate?> showCoverSearch(
  BuildContext context, {
  required BookLookupService service,
  required String title,
  String? author,
}) {
  return showModalBottomSheet<BookCandidate>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _CoverSearchSheet(service: service, title: title, author: author),
  );
}

class _CoverSearchSheet extends StatefulWidget {
  const _CoverSearchSheet({required this.service, required this.title, this.author});
  final BookLookupService service;
  final String title;
  final String? author;

  @override
  State<_CoverSearchSheet> createState() => _CoverSearchSheetState();
}

class _CoverSearchSheetState extends State<_CoverSearchSheet> {
  late Future<List<BookCandidate>> _future = widget.service.search(widget.title, author: widget.author);

  bool get _hasAuthor => (widget.author ?? '').trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final query = _hasAuthor ? '"${widget.title}" de ${widget.author!.trim()}' : '"${widget.title}"';
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.image_search),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Resultados para $query', style: Theme.of(context).textTheme.titleMedium),
                  ),
                ],
              ),
            ),
            Flexible(
              child: FutureBuilder<List<BookCandidate>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Buscando no Open Library e Google Books...'),
                      ]),
                    );
                  }
                  final results = snap.data ?? [];
                  if (snap.hasError || results.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.search_off, size: 40),
                        const SizedBox(height: 8),
                        Text(
                          snap.hasError
                              ? 'Não foi possível buscar agora. Verifique sua conexão.'
                              : 'Nenhum resultado encontrado. Tente ajustar o título ou o autor.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => setState(() => _future = widget.service.search(widget.title, author: widget.author)),
                          child: const Text('Tentar novamente'),
                        ),
                      ]),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) => _ResultTile(candidate: results[i]),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.candidate});
  final BookCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final c = candidate;
    final details = [
      if (c.authorText.isNotEmpty) c.authorText,
      if (c.year != null) '${c.year}',
      if (c.pageCount != null) '${c.pageCount} págs',
    ].join(' · ');
    return ListTile(
      leading: SizedBox(
        width: 44,
        height: 64,
        child: c.previewUrl == null
            ? const Icon(Icons.menu_book)
            : ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  c.previewUrl!,
                  fit: BoxFit.cover,
                  cacheWidth: 120,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                ),
              ),
      ),
      title: Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '$details${details.isEmpty ? '' : '\n'}${c.hasCover ? 'Com capa' : 'Sem capa'} · ${c.sources.join(' + ')}',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      onTap: () => Navigator.pop(context, c),
    );
  }
}
