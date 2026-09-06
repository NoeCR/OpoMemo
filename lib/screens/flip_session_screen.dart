import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/fact.dart';
import '../models/review.dart';
import '../state/memo_controller.dart';
import '../state/session_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/flip_card.dart';
import '../widgets/page_frame.dart';

class FlipSessionScreen extends StatefulWidget {
  const FlipSessionScreen({
    super.key,
    this.deckId,
    this.limit = 20,
  });

  /// Si es null, mezcla cartas pendientes de todos los mazos.
  final String? deckId;
  final int limit;

  static Future<void> open(BuildContext context, {String? deckId}) async {
    final limit = context.read<SessionSettings>().size;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FlipSessionScreen(deckId: deckId, limit: limit),
      ),
    );
    if (context.mounted) await context.read<MemoController>().reload();
  }

  @override
  State<FlipSessionScreen> createState() => _FlipSessionScreenState();
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

class _FlipSessionScreenState extends State<FlipSessionScreen> {
  final _focusNode = FocusNode();
  List<Fact> _queue = const [];
  final _undoStack = <_UndoEntry>[];
  final _requeuedIds = <String>{};
  var _index = 0;
  var _skipped = 0;
  var _flipped = false;
  var _loading = true;
  var _grading = false;
  final _counts = <ReviewGrade, int>{
    ReviewGrade.no: 0,
    ReviewGrade.almost: 0,
    ReviewGrade.yes: 0,
  };

  bool get _done => !_loading && _index >= _queue.length;
  bool get _daily => widget.deckId == null;

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
    final queue = await context.read<MemoController>().dueFacts(
          deckId: widget.deckId,
          limit: widget.limit,
        );
    if (!mounted) return;
    setState(() {
      _queue = queue;
      _loading = false;
    });
  }

  void _keepFocus() {
    if (!_focusNode.hasFocus) _focusNode.requestFocus();
  }

  void _toggleFlip() {
    if (_done || _grading || _queue.isEmpty) return;
    setState(() => _flipped = !_flipped);
    _keepFocus();
  }

  Future<void> _grade(ReviewGrade grade) async {
    if (_grading || _done || !_flipped || _queue.isEmpty) return;
    setState(() => _grading = true);
    final fact = _queue[_index];
    final controller = context.read<MemoController>();
    final previous = await controller.grade(fact.id, grade);
    if (!mounted) return;
    var requeued = false;
    final nextQueue = [..._queue];
    if ((grade == ReviewGrade.no || grade == ReviewGrade.almost) &&
        !_requeuedIds.contains(fact.id)) {
      nextQueue.add(fact);
      _requeuedIds.add(fact.id);
      requeued = true;
    }
    _undoStack.add(
      _UndoEntry(
        index: _index,
        fact: fact,
        previous: previous,
        grade: grade,
        requeued: requeued,
      ),
    );
    setState(() {
      _queue = nextQueue;
      _counts[grade] = (_counts[grade] ?? 0) + 1;
      _grading = false;
      _flipped = false;
      _index += 1;
    });
    _keepFocus();
  }

  Future<void> _undo() async {
    if (_undoStack.isEmpty || _grading) return;
    final entry = _undoStack.removeLast();
    await context.read<MemoController>().restoreReview(entry.fact.id, entry.previous);
    if (!mounted) return;
    if (entry.requeued) {
      _requeuedIds.remove(entry.fact.id);
      if (_queue.isNotEmpty && _queue.last.id == entry.fact.id) {
        _queue = _queue.sublist(0, _queue.length - 1);
      }
    }
    setState(() {
      _counts[entry.grade] = ((_counts[entry.grade] ?? 1) - 1).clamp(0, 999);
      _index = entry.index;
      _flipped = false;
    });
    _keepFocus();
  }

  void _skip() {
    if (_done || _grading || _queue.isEmpty) return;
    setState(() {
      _skipped += 1;
      _flipped = false;
      _index += 1;
    });
    _keepFocus();
  }

  void _toggleReversed() {
    if (_done) return;
    final settings = context.read<SessionSettings>();
    settings.setReversed(!settings.reversed);
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
    _keepFocus();
  }

  String? _deckLabel(Fact fact) {
    if (!_daily) return null;
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
    final reversed = context.watch<SessionSettings>().reversed;
    final flagged = !_done && _queue.isNotEmpty && _queue[_index].flagged;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): _toggleFlip,
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
        const SingleActivator(LogicalKeyboardKey.keyR): _toggleReversed,
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.maybePop(context),
      },
      child: Focus(
        autofocus: true,
        focusNode: _focusNode,
        child: Scaffold(
          appBar: AppBar(
            title: Text(_done ? 'Sesión terminada' : '${_index + 1} / ${_queue.length}'),
            actions: [
              ExcludeFocus(
                child: IconButton(
                  tooltip: reversed
                      ? 'Empezar por la pregunta (R)'
                      : 'Empezar por la respuesta (R)',
                  onPressed: _done ? null : _toggleReversed,
                  icon: Icon(reversed ? Icons.swap_horiz : Icons.swap_horiz_outlined),
                ),
              ),
              ExcludeFocus(
                child: IconButton(
                  tooltip: flagged ? 'Quitar marca (B)' : 'Marcar para editar luego (B)',
                  onPressed: _done || _queue.isEmpty ? null : _toggleFlag,
                  icon: Icon(
                    flagged ? Icons.flag : Icons.flag_outlined,
                    color: flagged ? const Color(0xFFB45309) : null,
                  ),
                ),
              ),
              ExcludeFocus(
                child: IconButton(
                  tooltip: 'Deshacer (Z)',
                  onPressed: _undoStack.isEmpty || _grading ? null : _undo,
                  icon: const Icon(Icons.undo),
                ),
              ),
              ExcludeFocus(
                child: IconButton(
                  tooltip: 'Saltar (S)',
                  onPressed: _done || _grading ? null : _skip,
                  icon: const Icon(Icons.skip_next),
                ),
              ),
            ],
          ),
          body: PageFrame(
            maxWidth: 640,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: _done
                  ? _Summary(
                      counts: _counts,
                      total: _queue.length,
                      skipped: _skipped,
                      daily: _daily,
                    )
                  : _buildCard(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    final fact = _queue[_index];
    final deckLabel = _deckLabel(fact);
    final reversed = context.watch<SessionSettings>().reversed;
    return Column(
      children: [
        LinearProgressIndicator(
          value: _queue.isEmpty ? 0 : _index / _queue.length,
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Center(
            child: FlipCard(
              key: ValueKey('${fact.id}-$_index-$reversed'),
              flipped: _flipped,
              onTap: _toggleFlip,
              front: MemoFace(
                label: reversed ? 'Respuesta' : 'Pregunta',
                text: reversed ? fact.answer : fact.prompt,
                caption: deckLabel ??
                    (reversed
                        ? 'Di el término. Espacio o toca para voltear'
                        : 'Espacio o toca para voltear'),
                tint: reversed ? const Color(0xFF4338CA) : AppTheme.primary,
              ),
              back: MemoFace(
                label: reversed ? 'Término' : 'Respuesta',
                text: reversed ? fact.prompt : fact.answer,
                explanation: fact.explanation,
                caption: _caption([
                  if (fact.source.isNotEmpty) fact.source,
                  if (deckLabel != null) deckLabel,
                ]),
                tint: reversed ? AppTheme.primary : const Color(0xFF4338CA),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!_flipped)
          Text(
            'Intenta responder en voz alta. 1 No · 2 Casi · 3 Sí · S salta · Z deshace · B marca · R invierte.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.muted(context, 0.5)),
          )
        else
          ExcludeFocus(
            child: Row(
              children: [
              Expanded(
                child: _GradeButton(
                  label: 'No',
                  hint: '1',
                  color: const Color(0xFFB91C1C),
                  onPressed: _grading ? null : () => _grade(ReviewGrade.no),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GradeButton(
                  label: 'Casi',
                  hint: '2',
                  color: const Color(0xFFB45309),
                  onPressed: _grading ? null : () => _grade(ReviewGrade.almost),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GradeButton(
                  label: 'Sí',
                  hint: '3',
                  color: AppTheme.primary,
                  onPressed: _grading ? null : () => _grade(ReviewGrade.yes),
                ),
              ),
            ],
            ),
          ),
      ],
    );
  }

  String? _caption(List<String> parts) {
    final text = parts.where((item) => item.isNotEmpty).join(' · ');
    return text.isEmpty ? null : text;
  }
}

class _GradeButton extends StatelessWidget {
  const _GradeButton({
    required this.label,
    required this.hint,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final String hint;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Text('$label  $hint'),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.counts,
    required this.total,
    required this.skipped,
    required this.daily,
  });

  final Map<ReviewGrade, int> counts;
  final int total;
  final int skipped;
  final bool daily;

  @override
  Widget build(BuildContext context) {
    if (total == 0) {
      return Center(
        child: Text(
          daily ? 'No hay cartas pendientes hoy.' : 'Este mazo no tiene cartas pendientes hoy.',
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
              '$total en cola',
              if (skipped > 0) '$skipped saltadas',
              'los No y Casi vuelven mañana (y una vez más en esta sesión)',
            ].join(' · '),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _line('No', counts[ReviewGrade.no] ?? 0, const Color(0xFFB91C1C)),
          _line('Casi', counts[ReviewGrade.almost] ?? 0, const Color(0xFFB45309)),
          _line('Sí', counts[ReviewGrade.yes] ?? 0, AppTheme.primary),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(daily ? 'Volver al inicio' : 'Volver a mazos'),
          ),
        ],
      ),
    );
  }

  Widget _line(String label, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text('$label  $value', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ],
      ),
    );
  }
}
