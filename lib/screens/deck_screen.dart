import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/deck.dart';
import '../models/fact.dart';
import '../state/memo_controller.dart';
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

  @override
  Widget build(BuildContext context) {
    final deck = _deck;
    final summaries = context.watch<MemoController>().summaries;
    final due = summaries
        .where((item) => item.deck.id == widget.deckId)
        .map((item) => item.dueCount)
        .firstWhere((_) => true, orElse: () => 0);

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
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => FlipSessionScreen(deckId: widget.deckId),
                              ),
                            );
                            await _load();
                          },
                    icon: const Icon(Icons.style_outlined),
                    label: Text(due == 0 ? 'Nada pendiente hoy' : 'Repasar $due'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${_facts.length} cartas',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  for (final fact in _facts)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(fact.prompt, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          fact.answer,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
