import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/deck.dart';
import '../state/memo_controller.dart';
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

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MemoController>();
    final groups = [
      for (final group in controller.groups)
        if (_group == null || group.name == _group) group,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Tarjetas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const DeckFormScreen()),
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
                                label: group.name,
                                selected: _group == group.name,
                                onTap: () => setState(() => _group = group.name),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (groups.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 48),
                            child: Center(child: Text('Crea un mazo para empezar.')),
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
            color: Colors.black.withValues(alpha: 0.45),
          ),
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
      color: Colors.white,
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
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.black.withValues(alpha: 0.55)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: due == 0
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => FlipSessionScreen(deckId: deck.id),
                          ),
                        ),
                child: Text(due == 0 ? 'Hecho' : 'Repasar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
