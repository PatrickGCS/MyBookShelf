import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/database_helper.dart';
import '../services/reminder_service.dart';
import '../services/settings_service.dart';
import '../services/stats_service.dart';
import '../theme/app_theme.dart';
import '../theme/mbs_palette.dart';
import '../widgets/glass.dart';

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
    final p = MbsPalette.of(context);
    return MbsBackground(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: p.text,
        centerTitle: false,
        title: Text('Estatísticas', style: AppTheme.display(p.text, 24)),
      ),
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
                const SizedBox(height: 8),
                const _ReminderCard(),
                const SizedBox(height: 8),
                _SummaryGrid(stats: s),
                const SizedBox(height: 24),
                Text('Páginas por dia (últimos 14 dias)', style: AppTheme.display(p.text, 18)),
                const SizedBox(height: 12),
                _PagesChart(series: s.pagesPerDay),
                const SizedBox(height: 24),
                Text('Livros por gênero', style: AppTheme.display(p.text, 18)),
                const SizedBox(height: 12),
                _GenreBars(entries: s.genreCounts),
              ],
            ),
          );
        },
      ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.stats});
  final LibraryStats stats;

  @override
  Widget build(BuildContext context) {
    final p = MbsPalette.of(context);
    final s = stats;
    final message = s.readToday
        ? 'Você já leu hoje. Continue assim!'
        : s.currentStreak > 0
            ? 'Leia hoje para manter sua sequência!'
            : 'Registre uma leitura hoje para começar uma sequência.';
    return GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.local_fire_department_rounded, size: 44, color: p.accent),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${s.currentStreak} ${s.currentStreak == 1 ? 'dia' : 'dias'} seguidos',
                      style: AppTheme.display(p.text, 22)),
                  Text(message, style: AppTheme.body(p.text, 14)),
                  const SizedBox(height: 4),
                  Text('Recorde: ${s.longestStreak} · Dias lendo nos últimos 30: ${s.daysReadLast30}',
                      style: AppTheme.body(p.muted, 12)),
                ],
              ),
            ),
          ],
        ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.stats});
  final LibraryStats stats;

  @override
  Widget build(BuildContext context) {
    final p = MbsPalette.of(context);
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
          GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(icon, color: p.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(value, style: AppTheme.display(p.text, 18), overflow: TextOverflow.ellipsis),
                        Text(label, style: AppTheme.body(p.muted, 11.5)),
                      ],
                    ),
                  ),
                ],
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
    final p = MbsPalette.of(context);
    final color = p.blue;
    if (maxV == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('Nenhuma leitura registrada neste período.', style: AppTheme.body(p.muted, 14))),
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
                    if (e.value > 0) Text('${e.value}', style: AppTheme.body(p.muted, 9)),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: e.value == 0 ? 2 : 110 * e.value / maxV,
                      decoration: BoxDecoration(
                        color: e.value == 0 ? p.track : color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(DateFormat('dd').format(e.key), style: AppTheme.body(p.muted, 9)),
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
    final p = MbsPalette.of(context);
    if (entries.isEmpty) return Text('Nenhum livro cadastrado.', style: AppTheme.body(p.muted, 14));
    final maxV = entries.first.value;
    return Column(
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 100, child: Text(e.key, overflow: TextOverflow.ellipsis, style: AppTheme.body(p.text, 13))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: e.value / maxV, minHeight: 14, color: p.blue, backgroundColor: p.track, semanticsLabel: '${e.key}: ${e.value}'),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${e.value}', style: AppTheme.body(p.text, 13)),
              ],
            ),
          ),
      ],
    );
  }
}

class _ReminderCard extends StatefulWidget {
  const _ReminderCard();

  @override
  State<_ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends State<_ReminderCard> {
  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await SettingsService.loadReminderEnabled();
    final time = await SettingsService.loadReminderTime();
    if (mounted) setState(() { _enabled = enabled; _time = time; });
  }

  void _msg(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _toggle(bool value) async {
    try {
      if (value) {
        final ok = await ReminderService.instance.enable(_time);
        if (!ok) {
          _msg('Permissão de notificações negada. Ative nas configurações do aparelho.');
          return;
        }
        _msg('Lembrete diário ativado para ${_time.format(context)}.');
      } else {
        await ReminderService.instance.disable();
      }
      if (mounted) setState(() => _enabled = value);
    } catch (e) {
      _msg('Não foi possível configurar o lembrete: $e');
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked == null) return;
    setState(() => _time = picked);
    if (_enabled) {
      try {
        await ReminderService.instance.enable(picked);
      } catch (e) {
        _msg('Não foi possível reagendar: $e');
      }
    } else {
      await SettingsService.saveReminder(enabled: false, time: picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = MbsPalette.of(context);
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(Icons.notifications_active_outlined, color: p.blue),
        title: Text('Lembrete diário de leitura', style: AppTheme.body(p.text, 15, weight: FontWeight.w600)),
        subtitle: GestureDetector(
          onTap: _pickTime,
          child: Text('Todos os dias às ${_time.format(context)} (toque para mudar)', style: AppTheme.body(p.muted, 12.5)),
        ),
        trailing: Switch(
          value: _enabled,
          onChanged: _toggle,
        ),
      ),
    );
  }
}
