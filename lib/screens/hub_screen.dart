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
import 'match_session_screen.dart';

enum HubMode { flip, match }

class HubScreen extends StatefulWidget {
  const HubScreen({super.key, this.mode = HubMode.flip});

  final HubMode mode;

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  String? _group;
  var _query = '';
  final _expanded = <String>{};

  bool _isExpanded(DeckGroup group) {
    if (_query.trim().isNotEmpty) return true;
    return _expanded.contains(group.name);
  }

  void _toggleGroup(String name) {
    setState(() {
      if (!_expanded.add(name)) _expanded.remove(name);
    });
  }

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
      appBar: AppBar(title: Text(widget.mode == HubMode.match ? 'Relacionar' : 'Tarjetas')),
      floatingActionButton: widget.mode == HubMode.match
          ? null
          : FloatingActionButton.extended(
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
                                onTap: () => setState(() {
                                  _group = group.name;
                                  _expanded.add(group.name);
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _DailyReviewBar(
                          due: controller.summaries.fold<int>(0, (sum, item) => sum + item.dueCount),
                          match: widget.mode == HubMode.match,
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
                            _GroupSection(
                              group: group,
                              expanded: _isExpanded(group),
                              onToggle: () => _toggleGroup(group.name),
                              match: widget.mode == HubMode.match,
                            ),
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
  const _DailyReviewBar({required this.due, this.match = false});

  final int due;
  final bool match;

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
          onPressed: due == 0
              ? null
              : () => match ? MatchSessionScreen.open(context) : FlipSessionScreen.open(context),
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

class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.group,
    required this.expanded,
    required this.onToggle,
    this.match = false,
  });

  final DeckGroup group;
  final bool expanded;
  final VoidCallback onToggle;
  final bool match;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.muted(context, 0.65),
                  ),
                  const SizedBox(width: 4),
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
                  if (!match)
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
              ),
            ),
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 10),
          for (final summary in group.decks) ...[
            _DeckTile(summary: summary, match: match),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

class _DeckTile extends StatelessWidget {
  const _DeckTile({required this.summary, this.match = false});

  final DeckSummary summary;
  final bool match;

  @override
  Widget build(BuildContext context) {
    final deck = summary.deck;
    final due = summary.dueCount;
    return Material(
      color: AppTheme.card(context),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (match) {
            MatchSessionScreen.open(context, deckId: deck.id);
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => DeckScreen(deckId: deck.id)),
          );
        },
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
                    : () => match
                        ? MatchSessionScreen.open(context, deckId: deck.id)
                        : FlipSessionScreen.open(context, deckId: deck.id),
                child: Text(due == 0 ? 'Hecho' : 'Repasar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
