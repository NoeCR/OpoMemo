import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../domain/cloze.dart';
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
    required this.grade,
    required this.requeued,
  });

  final int index;
  final Fact fact;
  final ReviewState? previous;
  final ReviewGrade grade;
  final bool requeued;
}

class _ClozeSessionScreenState extends State<ClozeSessionScreen> {
  final _focusNode = FocusNode();
  List<Fact> _queue = const [];
  final _undoStack = <_UndoEntry>[];
  final _requeuedIds = <String>{};
  var _inputs = <TextEditingController>[];
  var _index = 0;
  var _skipped = 0;
  var _revealed = false;
  var _loading = true;
  var _grading = false;
  List<bool>? _hits;
  final _counts = <ReviewGrade, int>{
    ReviewGrade.no: 0,
    ReviewGrade.almost: 0,
    ReviewGrade.yes: 0,
  };

  bool get _done => !_loading && _index >= _queue.length;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    for (final input in _inputs) {
      input.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final queue = await context.read<MemoController>().dueFacts(
          limit: widget.limit,
          clozeOnly: true,
        );
    if (!mounted) return;
    setState(() {
      _queue = queue;
      _loading = false;
    });
    if (queue.isNotEmpty) _armCard(queue.first);
  }

  void _armCard(Fact fact) {
    for (final input in _inputs) {
      input.dispose();
    }
    _inputs = [
      for (var i = 0; i < Cloze.blanks(fact.clozeText).length; i++) TextEditingController(),
    ];
    _revealed = false;
    _hits = null;
  }

  void _keepFocus() {
    if (!_focusNode.hasFocus) _focusNode.requestFocus();
  }

  void _check() {
    if (_done || _grading || _revealed || _queue.isEmpty) return;
    final expected = Cloze.blanks(_queue[_index].clozeText);
    if (expected.isEmpty) return;
    setState(() {
      _hits = [
        for (var i = 0; i < expected.length; i++)
          i < _inputs.length && Cloze.same(expected[i], _inputs[i].text),
      ];
      _revealed = true;
    });
    _keepFocus();
  }

  Future<void> _grade(ReviewGrade grade) async {
    if (_grading || _done || !_revealed || _queue.isEmpty) return;
    setState(() => _grading = true);
    final fact = _queue[_index];
    final controller = context.read<MemoController>();
    final previous = await controller.grade(fact.id, grade);
    if (!mounted) return;
    var requeued = false;
    final nextQueue = [..._queue];
    if ((grade == ReviewGrade.no || grade == ReviewGrade.almost) && !_requeuedIds.contains(fact.id)) {
      nextQueue.add(fact);
      _requeuedIds.add(fact.id);
      requeued = true;
    }
    _undoStack.add(
      _UndoEntry(index: _index, fact: fact, previous: previous, grade: grade, requeued: requeued),
    );
    final nextIndex = _index + 1;
    setState(() {
      _queue = nextQueue;
      _counts[grade] = (_counts[grade] ?? 0) + 1;
      _index = nextIndex;
      _grading = false;
    });
    if (nextIndex < nextQueue.length) _armCard(nextQueue[nextIndex]);
    _keepFocus();
  }

  Future<void> _undo() async {
    if (_undoStack.isEmpty || _grading) return;
    final entry = _undoStack.removeLast();
    await context.read<MemoController>().restoreReview(entry.fact.id, entry.previous);
    if (!mounted) return;
    final nextQueue = [..._queue];
    if (entry.requeued && nextQueue.isNotEmpty) {
      nextQueue.removeLast();
      _requeuedIds.remove(entry.fact.id);
    }
    setState(() {
      _queue = nextQueue;
      _index = entry.index;
      _counts[entry.grade] = ((_counts[entry.grade] ?? 1) - 1).clamp(0, 999);
    });
    _armCard(entry.fact);
    _keepFocus();
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
        const SingleActivator(LogicalKeyboardKey.enter): _check,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _check,
        const SingleActivator(LogicalKeyboardKey.digit1): () => _grade(ReviewGrade.no),
        const SingleActivator(LogicalKeyboardKey.numpad1): () => _grade(ReviewGrade.no),
        const SingleActivator(LogicalKeyboardKey.digit2): () => _grade(ReviewGrade.almost),
        const SingleActivator(LogicalKeyboardKey.numpad2): () => _grade(ReviewGrade.almost),
        const SingleActivator(LogicalKeyboardKey.digit3): () => _grade(ReviewGrade.yes),
        const SingleActivator(LogicalKeyboardKey.numpad3): () => _grade(ReviewGrade.yes),
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
    final blanks = Cloze.blanks(fact.clozeText);
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
                Text(
                  'HUECO',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFB45309),
                  ),
                ),
                const SizedBox(height: 12),
                _ClozeSentence(template: fact.clozeText, hits: _hits),
                const SizedBox(height: 20),
                if (!_revealed)
                  for (var i = 0; i < blanks.length; i++) ...[
                    TextField(
                      controller: _inputs[i],
                      autofocus: i == 0,
                      textInputAction: i == blanks.length - 1 ? TextInputAction.done : TextInputAction.next,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) {
                        if (i == blanks.length - 1) {
                          _check();
                        }
                      },
                      decoration: InputDecoration(
                        labelText: blanks.length == 1 ? 'Dato que falta' : 'Hueco ${i + 1}',
                        hintText: 'Escríbelo y pulsa Intro',
                      ),
                    ),
                    const SizedBox(height: 10),
                  ]
                else ...[
                  Text(
                    allHit ? 'Coincide. 1 No · 2 Casi · 3 Sí.' : 'Comprueba el dato y califica.',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: allHit ? AppTheme.primary : const Color(0xFFB45309),
                    ),
                  ),
                  if (fact.explanation.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(fact.explanation, style: TextStyle(color: AppTheme.muted(context, 0.72), height: 1.4)),
                  ],
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
        if (!_revealed)
          FilledButton(
            onPressed: _grading ? null : _check,
            child: const Text('Comprobar'),
          )
        else
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _grading ? null : () => _grade(ReviewGrade.no),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB91C1C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('No  1'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _grading ? null : () => _grade(ReviewGrade.almost),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB45309),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Casi  2'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _grading ? null : () => _grade(ReviewGrade.yes),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Sí  3'),
                ),
              ),
            ],
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
              '${_queue.length} en cola',
              if (_skipped > 0) '$_skipped saltadas',
              'los No y Casi vuelven mañana (y una vez más en esta sesión)',
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
  const _ClozeSentence({required this.template, this.hits});

  final String template;
  final List<bool>? hits;

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
      final hit = hits == null || blank >= hits!.length ? null : hits![blank];
      blank += 1;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: _BlankChip(
            text: hits == null ? '______' : part.value,
            hit: hit,
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
  const _BlankChip({required this.text, this.hit});

  final String text;
  final bool? hit;

  @override
  Widget build(BuildContext context) {
    final color = switch (hit) {
      true => const Color(0xFF047857),
      false => const Color(0xFFB91C1C),
      null => const Color(0xFFB45309),
    };
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border(bottom: BorderSide(color: color, width: 2)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 20),
      ),
    );
  }
}
