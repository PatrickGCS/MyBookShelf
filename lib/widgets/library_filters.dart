import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/books_provider.dart';

// PopupMenuButton trata valor null como "cancelado"; usamos um marcador.
const _allGenres = '__todos__';

/// Barra de filtros por status/gênero e menu de ordenação.
class LibraryFilters extends StatelessWidget {
  const LibraryFilters({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<BooksProvider>();
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final f in StatusFilter.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: ChoiceChip(
                label: Text('${f.label} (${p.countFor(f)})'),
                selected: p.status == f,
                onSelected: (_) => p.setStatus(f),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: PopupMenuButton<String>(
              tooltip: 'Filtrar por gênero',
              onSelected: (v) => p.setGenre(v == _allGenres ? null : v),
              itemBuilder: (_) => [
                const PopupMenuItem<String>(value: _allGenres, child: Text('Todos os gêneros')),
                for (final g in p.genres) PopupMenuItem<String>(value: g, child: Text(g)),
              ],
              child: Chip(
                avatar: const Icon(Icons.category, size: 16),
                label: Text(p.genre ?? 'Gênero'),
                backgroundColor: p.genre != null ? Theme.of(context).colorScheme.primaryContainer : null,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: PopupMenuButton<BookSort>(
              tooltip: 'Ordenar',
              onSelected: p.setSort,
              itemBuilder: (_) => [
                for (final s in BookSort.values)
                  CheckedPopupMenuItem<BookSort>(
                    value: s,
                    checked: p.sort == s,
                    child: Text(s.label),
                  ),
              ],
              child: Chip(
                avatar: Icon(p.ascending ? Icons.arrow_upward : Icons.arrow_downward, size: 16),
                label: Text(p.sort.label),
              ),
            ),
          ),
          if (p.hasActiveFilters)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: ActionChip(
                avatar: const Icon(Icons.filter_alt_off, size: 16),
                label: const Text('Limpar'),
                onPressed: p.clearFilters,
              ),
            ),
        ],
      ),
    );
  }
}
