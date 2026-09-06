import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/deck.dart';
import '../state/memo_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/leitner_strip.dart';
import '../widgets/memo_search_field.dart';
import '../widgets/page_frame.dart';
import 'deck_form_screen.dart';
import 'deck_screen.dart';
import 'flip_session_screen.dart';

class HubScreen extends StatefulWidget {
  const HubScreen({super.key});

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  String? _group;
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MemoController>();
    final groups = [
      for (final group in controller.groups)
        if (_group == null || group.name == _group)
          DeckGroup(
            name: group.name,
            decks: [
              for (final summary in group.decks)
                if (summary.matches(_query)) summary,
            ],
          ),
    ].where((group) => group.decks.isNotEmpty).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Tarjetas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => DeckFormScreen(initialGroup: _group),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo mazo'),
      ),
      body: controller.loading
          ? const Center(child: CircularProgressIndicator())
          : controller.error != null
              ? Center(child: Text(controller.error!))
              : RefreshIndicator(
                  onRefresh: controller.reload,
                  child: PageFrame(
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                      children: [
                        MemoSearchField(
                          hint: 'Buscar mazo o grupo',
                          onChanged: (value) => setState(() => _query = value),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _FilterChip(
                              label: 'Todas',
                              selected: _group == null,
                              onTap: () => setState(() => _group = null),
                            ),
                            for (final group in controller.groups)
                              _FilterChip(
                                label: group.chipLabel,
                                selected: _group == group.name,
                                onTap: () => setState(() => _group = group.name),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _DailyReviewBar(
                          due: controller.summaries.fold<int>(0, (sum, item) => sum + item.dueCount),
                        ),
                        const SizedBox(height: 16),
                        if (groups.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 48),
                            child: Center(
                              child: Text(
                                _query.trim().isEmpty
                                    ? 'Crea un mazo para empezar.'
                                    : 'Ningún mazo coincide con la búsqueda.',
                              ),
                            ),
                          )
                        else
                          for (final group in groups) ...[
                            _GroupHeader(group: group),
                            const SizedBox(height: 10),
                            for (final summary in group.decks) ...[
                              _DeckTile(summary: summary),
                              const SizedBox(height: 10),
                            ],
                            const SizedBox(height: 12),
                          ],
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _DailyReviewBar extends StatelessWidget {
  const _DailyReviewBar({required this.due});

  final int due;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            due == 0 ? 'Nada pendiente entre mazos' : '$due pendientes entre mazos',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.muted(context),
            ),
          ),
        ),
        FilledButton(
          onPressed: due == 0 ? null : () => FlipSessionScreen.open(context),
          child: const Text('Repaso del día'),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group});

  final DeckGroup group;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            group.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        Text(
          '${group.decks.length} mazos · ${group.dueCount} hoy',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.muted(context, 0.45),
          ),
        ),
        IconButton(
          tooltip: 'Nuevo mazo en ${group.name}',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => DeckFormScreen(initialGroup: group.name),
            ),
          ),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class _DeckTile extends StatelessWidget {
  const _DeckTile({required this.summary});

  final DeckSummary summary;

  @override
  Widget build(BuildContext context) {
    final deck = summary.deck;
    final due = summary.dueCount;
    return Material(
      color: AppTheme.card(context),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => DeckScreen(deckId: deck.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deck.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (deck.description.isNotEmpty) deck.description,
                        '${summary.factCount} cartas',
                        due == 0 ? 'al día' : '$due pendientes',
                        if (summary.flaggedCount > 0) '${summary.flaggedCount} marcadas',
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppTheme.muted(context)),
                    ),
                    const SizedBox(height: 8),
                    LeitnerStrip(
                      newCount: summary.newCount,
                      boxCounts: summary.boxCounts,
                      compact: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: due == 0
                    ? null
                    : () => FlipSessionScreen.open(context, deckId: deck.id),
                child: Text(due == 0 ? 'Hecho' : 'Repasar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
