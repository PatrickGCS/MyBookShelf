import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/database_helper.dart';
import '../services/stats_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late Future<LibraryStats> _future = _load();

  Future<LibraryStats> _load() async {
    final books = await DatabaseHelper.instance.readAllBooks();
    final sessions = await DatabaseHelper.instance.getAllSessions();
    return LibraryStats.compute(books, sessions);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Estatísticas')),
      body: FutureBuilder<LibraryStats>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Erro ao calcular: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final s = snap.data!;
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = _load());
              await _future;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _StreakCard(stats: s),
                const SizedBox(height: 16),
                _SummaryGrid(stats: s),
                const SizedBox(height: 24),
                Text('Páginas por dia (últimos 14 dias)', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _PagesChart(series: s.pagesPerDay),
                const SizedBox(height: 24),
                Text('Livros por gênero', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _GenreBars(entries: s.genreCounts),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.stats});
  final LibraryStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = stats;
    final message = s.readToday
        ? 'Você já leu hoje. Continue assim!'
        : s.currentStreak > 0
            ? 'Leia hoje para manter sua sequência!'
            : 'Registre uma leitura hoje para começar uma sequência.';
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Text('🔥', style: TextStyle(fontSize: 40)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${s.currentStreak} ${s.currentStreak == 1 ? 'dia' : 'dias'} seguidos',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  Text(message),
                  const SizedBox(height: 4),
                  Text('Recorde: ${s.longestStreak} · Dias lendo nos últimos 30: ${s.daysReadLast30}',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.stats});
  final LibraryStats stats;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final money = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
    final items = <(IconData, String, String)>[
      (Icons.menu_book, 'Livros', '${s.totalBooks}'),
      (Icons.check_circle, 'Lidos', '${s.readBooks}'),
      (Icons.auto_stories, 'Lendo', '${s.readingBooks}'),
      (Icons.pause_circle, 'Pausados', '${s.pausedBooks}'),
      (Icons.pages, 'Páginas lidas', '${s.totalPagesRead}'),
      (Icons.star, 'Nota média', s.averageRating == 0 ? '-' : s.averageRating.toStringAsFixed(1)),
      (Icons.payments, 'Investido', money.format(s.totalSpent)),
      (Icons.bookmark_border, 'Não iniciados', '${s.notStartedBooks}'),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.4,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (final (icon, label, value) in items)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(icon, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
                        Text(label, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PagesChart extends StatelessWidget {
  const _PagesChart({required this.series});
  final List<MapEntry<DateTime, int>> series;

  @override
  Widget build(BuildContext context) {
    final maxV = series.fold<int>(0, (m, e) => e.value > m ? e.value : m);
    final color = Theme.of(context).colorScheme.primary;
    if (maxV == 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('Nenhuma leitura registrada neste período.')),
      );
    }
    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final e in series)
            Expanded(
              child: Semantics(
                label: '${DateFormat('dd/MM').format(e.key)}: ${e.value} páginas',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (e.value > 0) Text('${e.value}', style: const TextStyle(fontSize: 9)),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: e.value == 0 ? 2 : 110 * e.value / maxV,
                      decoration: BoxDecoration(
                        color: e.value == 0 ? Colors.grey.withValues(alpha: 0.4) : color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(DateFormat('dd').format(e.key), style: const TextStyle(fontSize: 9)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GenreBars extends StatelessWidget {
  const _GenreBars({required this.entries});
  final List<MapEntry<String, int>> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const Text('Nenhum livro cadastrado.');
    final maxV = entries.first.value;
    return Column(
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 100, child: Text(e.key, overflow: TextOverflow.ellipsis)),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: e.value / maxV, minHeight: 14, semanticsLabel: '${e.key}: ${e.value}'),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${e.value}'),
              ],
            ),
          ),
      ],
    );
  }
}
