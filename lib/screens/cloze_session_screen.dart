import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../domain/cloze.dart';
import '../domain/cloze_bank.dart';
import '../models/fact.dart';
import '../models/review.dart';
import '../state/memo_controller.dart';
import '../state/session_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/page_frame.dart';

class ClozeSessionScreen extends StatefulWidget {
  const ClozeSessionScreen({super.key, this.limit = 20});

  final int limit;

  static Future<void> open(BuildContext context) async {
    final limit = context.read<SessionSettings>().size;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => ClozeSessionScreen(limit: limit)),
    );
    if (context.mounted) await context.read<MemoController>().reload();
  }

  @override
  State<ClozeSessionScreen> createState() => _ClozeSessionScreenState();
}

class _UndoEntry {
  const _UndoEntry({
    required this.index,
    required this.fact,
    required this.previous,
    required this.solved,
    required this.requeued,
  });

  final int index;
  final Fact fact;
  final ReviewState? previous;
  final bool solved;
  final bool requeued;
}

class _ClozeSessionScreenState extends State<ClozeSessionScreen> {
  final _focusNode = FocusNode();
  List<Fact> _queue = const [];
  List<Fact> _pool = const [];
  final _undoStack = <_UndoEntry>[];
  ClozePick? _pick;
  var _index = 0;
  var _skipped = 0;
  var _retries = 0;
  var _revealed = false;
  var _loading = true;
  var _grading = false;
  List<bool>? _hits;
  var _solved = 0;

  bool get _done => !_loading && _index >= _queue.length;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final limit = widget.limit;
    final pool = await context.read<MemoController>().dueFacts(
          limit: limit < 50 ? 50 : limit,
          clozeOnly: true,
        );
    if (!mounted) return;
    final queue = pool.take(limit).toList();
    setState(() {
      _pool = pool;
      _queue = queue;
      _loading = false;
    });
    if (queue.isNotEmpty) _armCard(queue.first);
  }

  void _armCard(Fact fact) {
    final answers = Cloze.blanks(fact.clozeText);
    final sameDeck = <String>[];
    final others = <String>[];
    for (final item in _pool) {
      if (item.id == fact.id) continue;
      final words = [...Cloze.blanks(item.clozeText), ...item.distractors];
      if (item.deckId == fact.deckId) {
        sameDeck.addAll(words);
      } else {
        others.addAll(words);
      }
    }
    _pick = ClozePick(
      answers: answers,
      bank: ClozeBank.chips(
        answers: answers,
        distractors: fact.distractors,
        extras: [...sameDeck, ...others],
      ),
    );
    _revealed = false;
    _hits = null;
  }

  void _keepFocus() {
    if (!_focusNode.hasFocus) _focusNode.requestFocus();
  }

  void _tapBank(int unusedIndex) {
    if (_done || _grading || _revealed || _pick == null) return;
    setState(() => _pick!.tapBank(unusedIndex));
    _keepFocus();
    if (_pick!.complete) _check();
  }

  void _tapSlot(int index) {
    if (_done || _grading || _revealed || _pick == null) return;
    setState(() => _pick!.tapSlot(index));
    _keepFocus();
  }

  void _check() {
    final pick = _pick;
    if (_done || _grading || _revealed || pick == null || !pick.complete) return;
    setState(() {
      _hits = pick.hits();
      _revealed = true;
    });
    _keepFocus();
  }

  Future<void> _continue() async {
    if (_grading || _done || !_revealed) return;
    final hits = _hits;
    if (hits == null || hits.isEmpty) return;
    await _advance(solved: hits.every((item) => item));
  }

  Future<void> _advance({required bool solved}) async {
    if (_queue.isEmpty) return;
    setState(() => _grading = true);
    final fact = _queue[_index];
    ReviewState? previous;
    if (solved) {
      previous = await context.read<MemoController>().grade(fact.id, ReviewGrade.yes);
    }
    if (!mounted) return;
    final nextQueue = [..._queue];
    var requeued = false;
    if (!solved) {
      nextQueue.add(fact);
      requeued = true;
    }
    _undoStack.add(
      _UndoEntry(index: _index, fact: fact, previous: previous, solved: solved, requeued: requeued),
    );
    final nextIndex = _index + 1;
    setState(() {
      _queue = nextQueue;
      _index = nextIndex;
      if (solved) {
        _solved += 1;
      } else {
        _retries += 1;
      }
      _grading = false;
    });
    if (nextIndex < nextQueue.length) _armCard(nextQueue[nextIndex]);
    _keepFocus();
  }

  Future<void> _undo() async {
    if (_undoStack.isEmpty || _grading) return;
    final entry = _undoStack.removeLast();
    if (entry.solved) {
      await context.read<MemoController>().restoreReview(entry.fact.id, entry.previous);
    }
    if (!mounted) return;
    final nextQueue = [..._queue];
    if (entry.requeued && nextQueue.isNotEmpty) {
      nextQueue.removeLast();
    }
    setState(() {
      _queue = nextQueue;
      _index = entry.index;
      if (entry.solved) {
        _solved = (_solved - 1).clamp(0, 999);
      } else {
        _retries = (_retries - 1).clamp(0, 999);
      }
    });
    _armCard(entry.fact);
    _keepFocus();
  }

  void _onEnter() {
    if (_revealed) {
      _continue();
      return;
    }
    _check();
  }

  void _skip() {
    if (_done || _grading || _queue.isEmpty) return;
    final nextIndex = _index + 1;
    setState(() {
      _skipped += 1;
      _index = nextIndex;
    });
    if (nextIndex < _queue.length) _armCard(_queue[nextIndex]);
    _keepFocus();
  }

  Future<void> _toggleFlag() async {
    if (_done || _grading || _queue.isEmpty) return;
    final fact = _queue[_index];
    final next = !fact.flagged;
    await context.read<MemoController>().setFlagged(fact.id, next);
    if (!mounted) return;
    setState(() {
      _queue = [
        for (final item in _queue)
          if (item.id == fact.id) item.copyWith(flagged: next) else item,
      ];
    });
  }

  String? _deckLabel(Fact fact) {
    for (final summary in context.read<MemoController>().summaries) {
      if (summary.deck.id == fact.deckId) {
        final group = summary.deck.groupName;
        return group.isEmpty ? summary.deck.name : '$group · ${summary.deck.name}';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final flagged = !_done && _queue.isNotEmpty && _queue[_index].flagged;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): _onEnter,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _onEnter,
        const SingleActivator(LogicalKeyboardKey.keyS): _skip,
        const SingleActivator(LogicalKeyboardKey.keyZ): _undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
        const SingleActivator(LogicalKeyboardKey.keyB): _toggleFlag,
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.maybePop(context),
      },
      child: Focus(
        autofocus: true,
        focusNode: _focusNode,
        child: Scaffold(
          appBar: AppBar(
            title: Text(_done ? 'Sesión terminada' : '${_index + 1} / ${_queue.length}'),
            actions: [
              IconButton(
                tooltip: flagged ? 'Quitar marca (B)' : 'Marcar para editar luego (B)',
                onPressed: _done || _queue.isEmpty ? null : _toggleFlag,
                icon: Icon(
                  flagged ? Icons.flag : Icons.flag_outlined,
                  color: flagged ? const Color(0xFFB45309) : null,
                ),
              ),
              IconButton(
                tooltip: 'Deshacer (Z)',
                onPressed: _undoStack.isEmpty || _grading ? null : _undo,
                icon: const Icon(Icons.undo),
              ),
              IconButton(
                tooltip: 'Saltar (S)',
                onPressed: _done || _grading ? null : _skip,
                icon: const Icon(Icons.skip_next),
              ),
            ],
          ),
          body: PageFrame(
            maxWidth: 640,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: _done ? _summary() : _buildCard(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    final fact = _queue[_index];
    final pick = _pick!;
    final allHit = _hits != null && _hits!.isNotEmpty && _hits!.every((item) => item);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: _queue.isEmpty ? 0 : _index / _queue.length,
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'HUECO',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFB45309),
                  ),
                ),
                const SizedBox(height: 12),
                _ClozeSentence(
                  template: fact.clozeText,
                  slots: pick.slots,
                  hits: _hits,
                  activeSlot: _revealed ? null : pick.activeSlot,
                  onSlotTap: _revealed ? null : _tapSlot,
                ),
                const SizedBox(height: 20),
                if (_revealed) ...[
                  Text(
                    allHit ? 'Correcto.' : 'No es correcto. Esta frase volverá a salir.',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: allHit ? AppTheme.primary : const Color(0xFFB91C1C),
                    ),
                  ),
                  if (fact.explanation.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(fact.explanation, style: TextStyle(color: AppTheme.muted(context, 0.72), height: 1.4)),
                  ],
                ] else ...[
                  Text(
                    pick.complete ? 'Comprobando…' : 'Toca una palabra para rellenar el hueco.',
                    style: TextStyle(color: AppTheme.muted(context), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < pick.unused.length; i++)
                        _BankChip(text: pick.unused[i], onTap: () => _tapBank(i)),
                    ],
                  ),
                ],
                if (fact.source.isNotEmpty || _deckLabel(fact) != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    [if (fact.source.isNotEmpty) fact.source, if (_deckLabel(fact) != null) _deckLabel(fact)!]
                        .join(' · '),
                    style: TextStyle(color: AppTheme.muted(context, 0.45), fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_revealed)
          FilledButton(
            onPressed: _grading ? null : _continue,
            child: const Text('Continuar'),
          ),
      ],
    );
  }

  Widget _summary() {
    if (_queue.isEmpty) {
      return const Center(
        child: Text(
          'No hay hechos con hueco pendientes. Usa LPACAP · Plazos o CE · Órganos, o añade {{dato}} al editar una carta.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Sesión hecha', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            [
              '$_solved acertadas',
              if (_retries > 0) '$_retries se repetirán hasta acertarlas',
              if (_skipped > 0) '$_skipped saltadas',
            ].join(' · '),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Volver al inicio'),
          ),
        ],
      ),
    );
  }
}

class _ClozeSentence extends StatelessWidget {
  const _ClozeSentence({
    required this.template,
    required this.slots,
    this.hits,
    this.activeSlot,
    this.onSlotTap,
  });

  final String template;
  final List<String?> slots;
  final List<bool>? hits;
  final int? activeSlot;
  final ValueChanged<int>? onSlotTap;

  @override
  Widget build(BuildContext context) {
    final parts = Cloze.parse(template);
    final spans = <InlineSpan>[];
    var blank = 0;
    for (final part in parts) {
      if (!part.blank) {
        spans.add(TextSpan(text: part.value));
        continue;
      }
      final index = blank;
      final hit = hits == null || index >= hits!.length ? null : hits![index];
      final placed = index < slots.length ? slots[index] : null;
      blank += 1;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: _BlankChip(
            text: placed ?? '______',
            hit: hit,
            selected: activeSlot == index,
            onTap: onSlotTap == null ? null : () => onSlotTap!(index),
          ),
        ),
      );
    }
    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: 22,
          height: 1.45,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        children: spans,
      ),
    );
  }
}

class _BlankChip extends StatelessWidget {
  const _BlankChip({
    required this.text,
    this.hit,
    this.selected = false,
    this.onTap,
  });

  final String text;
  final bool? hit;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (hit) {
      true => const Color(0xFF047857),
      false => const Color(0xFFB91C1C),
      null => const Color(0xFFB45309),
    };
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.22 : 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            bottom: BorderSide(color: color, width: selected ? 3 : 2),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 20),
        ),
      ),
    );
  }
}

class _BankChip extends StatelessWidget {
  const _BankChip({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card(context),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
