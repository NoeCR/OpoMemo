import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/deck.dart';
import '../models/fact.dart';
import '../state/memo_controller.dart';
import '../widgets/leitner_strip.dart';
import '../widgets/memo_search_field.dart';
import '../widgets/page_frame.dart';
import 'deck_form_screen.dart';
import 'fact_form_screen.dart';
import 'flip_session_screen.dart';

class DeckScreen extends StatefulWidget {
  const DeckScreen({super.key, required this.deckId});

  final String deckId;

  @override
  State<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends State<DeckScreen> {
  Deck? _deck;
  List<Fact> _facts = const [];
  var _loading = true;
  var _query = '';
  var _flaggedOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final controller = context.read<MemoController>();
    final deck = await controller.deckById(widget.deckId);
    final facts = await controller.factsFor(widget.deckId);
    if (!mounted) return;
    setState(() {
      _deck = deck;
      _facts = facts;
      _loading = false;
    });
  }

  Future<void> _toggleFlag(Fact fact) async {
    final next = !fact.flagged;
    await context.read<MemoController>().setFlagged(fact.id, next);
    if (!mounted) return;
    setState(() {
      _facts = [
        for (final item in _facts)
          if (item.id == fact.id) item.copyWith(flagged: next) else item,
      ];
    });
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar mazo'),
        content: const Text('Se borrarán todas las cartas de esta sección.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<MemoController>().deleteDeck(widget.deckId);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  List<Fact> get _visible {
    return [
      for (final fact in _facts)
        if (fact.matches(_query) && (!_flaggedOnly || fact.flagged)) fact,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final deck = _deck;
    final summaries = context.watch<MemoController>().summaries;
    DeckSummary? summary;
    for (final item in summaries) {
      if (item.deck.id == widget.deckId) {
        summary = item;
        break;
      }
    }
    final due = summary?.dueCount ?? 0;
    final visible = _visible;

    return Scaffold(
      appBar: AppBar(
        title: Text(deck?.name ?? 'Mazo'),
        actions: [
          IconButton(
            tooltip: 'Editar mazo',
            onPressed: deck == null
                ? null
                : () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DeckFormScreen(existing: deck),
                      ),
                    );
                    await _load();
                  },
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Eliminar',
            onPressed: _confirmDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FactFormScreen(deckId: widget.deckId),
            ),
          );
          await _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Añadir carta'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : PageFrame(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                children: [
                  if (deck?.description.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        deck!.description,
                        style: TextStyle(color: Colors.black.withValues(alpha: 0.6)),
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: due == 0
                        ? null
                        : () async {
                            await FlipSessionScreen.open(context, deckId: widget.deckId);
                            await _load();
                          },
                    icon: const Icon(Icons.style_outlined),
                    label: Text(due == 0 ? 'Nada pendiente hoy' : 'Repasar $due'),
                  ),
                  if (summary != null) ...[
                    const SizedBox(height: 14),
                    LeitnerStrip(
                      newCount: summary.newCount,
                      boxCounts: summary.boxCounts,
                    ),
                  ],
                  const SizedBox(height: 16),
                  MemoSearchField(
                    hint: 'Buscar carta',
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text('Todas (${_facts.length})'),
                        selected: !_flaggedOnly,
                        onSelected: (_) => setState(() => _flaggedOnly = false),
                      ),
                      ChoiceChip(
                        label: Text(
                          'Marcadas (${_facts.where((item) => item.flagged).length})',
                        ),
                        selected: _flaggedOnly,
                        onSelected: (_) => setState(() => _flaggedOnly = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    visible.length == _facts.length
                        ? '${_facts.length} cartas'
                        : '${visible.length} de ${_facts.length} cartas',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Text(
                        _flaggedOnly
                            ? 'No hay cartas marcadas${_query.trim().isEmpty ? '.' : ' que coincidan.'}'
                            : 'Ninguna carta coincide con la búsqueda.',
                        style: TextStyle(color: Colors.black.withValues(alpha: 0.55)),
                      ),
                    )
                  else
                    for (final fact in visible)
                      Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text(fact.prompt, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            [
                              fact.kind.label,
                              fact.answer,
                              if (fact.source.isNotEmpty) fact.source,
                            ].join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            tooltip: fact.flagged ? 'Quitar marca' : 'Marcar para editar luego',
                            onPressed: () => _toggleFlag(fact),
                            icon: Icon(
                              fact.flagged ? Icons.flag : Icons.flag_outlined,
                              color: fact.flagged ? const Color(0xFFB45309) : null,
                            ),
                          ),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => FactFormScreen(deckId: widget.deckId, existing: fact),
                              ),
                            );
                            await _load();
                          },
                        ),
                      ),
                ],
              ),
            ),
    );
  }
}
