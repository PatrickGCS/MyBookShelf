import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/books_provider.dart';
import '../theme/app_theme.dart';
import '../theme/mbs_palette.dart';

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
              child: _Pill(
                label: '${f.label} (${p.countFor(f)})',
                selected: p.status == f,
                onTap: () => p.setStatus(f),
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
              child: _Pill(
                icon: Icons.category_outlined,
                label: p.genre ?? 'Gênero',
                selected: p.genre != null,
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
              child: _Pill(
                icon: p.ascending ? Icons.arrow_upward : Icons.arrow_downward,
                label: p.sort.label,
              ),
            ),
          ),
          if (p.hasActiveFilters)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: _Pill(
                icon: Icons.filter_alt_off_outlined,
                label: 'Limpar',
                onTap: p.clearFilters,
              ),
            ),
        ],
      ),
    );
  }
}

/// Pílula do brandbook: vidro quando inativa, azul quando selecionada.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.icon, this.selected = false, this.onTap});
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = MbsPalette.of(context);
    final fg = selected ? p.blue : p.text;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? p.blue.withValues(alpha: 0.16) : p.glassFill,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? p.blue.withValues(alpha: 0.7) : p.glassBorder),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: fg),
                  const SizedBox(width: 6),
                ],
                ExcludeSemantics(
                  child: Text(
                    label,
                    style: AppTheme.body(fg, 13, weight: selected ? FontWeight.w700 : FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
