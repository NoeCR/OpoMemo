import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../domain/match_round.dart';
import '../models/fact.dart';
import '../models/review.dart';
import '../state/memo_controller.dart';
import '../state/session_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/page_frame.dart';

class MatchSessionScreen extends StatefulWidget {
  const MatchSessionScreen({super.key, this.limit = 20, this.deckId});

  final int limit;
  final String? deckId;

  static Future<void> open(BuildContext context, {String? deckId}) async {
    final limit = context.read<SessionSettings>().size;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => MatchSessionScreen(limit: limit, deckId: deckId)),
    );
    if (context.mounted) await context.read<MemoController>().reload();
  }

  @override
  State<MatchSessionScreen> createState() => _MatchSessionScreenState();
}

class _UndoMatch {
  const _UndoMatch({
    required this.fact,
    required this.previous,
    required this.grade,
    required this.requeued,
  });

  final Fact fact;
  final ReviewState? previous;
  final ReviewGrade grade;
  final bool requeued;
}

class _MatchSessionScreenState extends State<MatchSessionScreen> {
  final _focusNode = FocusNode();
  final _queues = <String, List<Fact>>{};
  final _pads = <String, List<Fact>>{};
  final _blocked = <String>{};
  var _deckOrder = <String>[];
  String? _currentDeckId;
  final _seenIds = <String>{};
  MatchRound? _round;
  final _undoStack = <_UndoMatch>[];
  final _requeuedIds = <String>{};
  final _flashIds = <String>{};
  var _loading = true;
  var _busy = false;
  var _skipped = 0;
  final _counts = <ReviewGrade, int>{
    ReviewGrade.no: 0,
    ReviewGrade.almost: 0,
    ReviewGrade.yes: 0,
  };

  bool get _done => !_loading && _round == null;

  int get _graded => _counts.values.fold(0, (sum, n) => sum + n);

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

  int get _pendingCount {
    var n = _round?.unmatchedCount ?? 0;
    for (final deckId in _deckOrder) {
      if (_blocked.contains(deckId)) continue;
      n += _queues[deckId]?.length ?? 0;
    }
    return n;
  }

  String? _deckTitle(String? deckId) {
    if (deckId == null) return null;
    for (final summary in context.read<MemoController>().summaries) {
      if (summary.deck.id == deckId) {
        final group = summary.deck.groupName;
        return group.isEmpty ? summary.deck.name : '$group · ${summary.deck.name}';
      }
    }
    return null;
  }

  Future<void> _load() async {
    final controller = context.read<MemoController>();
    final due = await controller.dueFacts(
      deckId: widget.deckId,
      limit: widget.limit,
      kind: FactKind.termino,
    );
    if (!mounted) return;
    final queues = <String, List<Fact>>{};
    for (final fact in due) {
      queues.putIfAbsent(fact.deckId, () => []).add(fact);
    }
    final pads = <String, List<Fact>>{};
    final exclude = {for (final fact in due) fact.id};
    for (final deckId in queues.keys) {
      pads[deckId] = await controller.factsByKind(
        FactKind.termino,
        deckId: deckId,
        limit: MatchRound.boardSize,
        excludeIds: exclude,
      );
      if (!mounted) return;
    }
    setState(() {
      _queues
        ..clear()
        ..addAll(queues);
      _pads
        ..clear()
        ..addAll(pads);
      _deckOrder = queues.keys.toList();
      _blocked.clear();
      _seenIds.clear();
      _loading = false;
    });
    _deal();
  }

  void _deal() {
    _undoStack.clear();
    _flashIds.clear();
    for (final deckId in _deckOrder) {
      if (_blocked.contains(deckId)) continue;
      final queue = _queues[deckId] ?? [];
      if (queue.isEmpty) continue;
      final board = MatchRound.pickBoard(
        remaining: queue,
        reserve: queue.length >= MatchRound.boardSize ? const [] : (_pads[deckId] ?? const []),
        seen: _seenIds,
      );
      if (board == null) {
        _blocked.add(deckId);
        continue;
      }
      final ids = {for (final fact in board) fact.id};
      queue.removeWhere((fact) => ids.contains(fact.id));
      _pads[deckId]?.removeWhere((fact) => ids.contains(fact.id));
      _seenIds.addAll(ids);
      setState(() {
        _currentDeckId = deckId;
        _round = MatchRound(board);
      });
      return;
    }
    setState(() {
      _currentDeckId = null;
      _round = null;
    });
  }

  void _keepFocus() {
    if (!_focusNode.hasFocus) _focusNode.requestFocus();
  }

  Future<void> _onTap(String factId, bool isPrompt) async {
    final round = _round;
    if (_busy || round == null || round.matched.contains(factId)) return;
    final first = round.selectedId;
    final result = round.tap(factId, isPrompt);
    setState(() {});
    _keepFocus();
    if (result == MatchTapResult.missed && first != null) {
      setState(() {
        _busy = true;
        _flashIds
          ..clear()
          ..add(first)
          ..add(factId);
      });
      await Future<void>.delayed(const Duration(milliseconds: 480));
      if (!mounted) return;
      setState(() {
        _flashIds.clear();
        _busy = false;
      });
      return;
    }
    if (result == MatchTapResult.matched) {
      setState(() => _busy = true);
      await _commitMatch(factId);
    }
  }

  Future<void> _commitMatch(String factId) async {
    final round = _round;
    if (round == null) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    final fact = round.facts.firstWhere((item) => item.id == factId);
    final grade = round.gradeFor(factId);
    final controller = context.read<MemoController>();
    final previous = await controller.grade(fact.id, grade);
    if (!mounted) return;
    var requeued = false;
    if ((grade == ReviewGrade.no || grade == ReviewGrade.almost) && !_requeuedIds.contains(fact.id)) {
      _queues.putIfAbsent(fact.deckId, () => []).add(fact);
      _blocked.remove(fact.deckId);
      _requeuedIds.add(fact.id);
      requeued = true;
    }
    _undoStack.add(_UndoMatch(fact: fact, previous: previous, grade: grade, requeued: requeued));
    setState(() {
      _counts[grade] = (_counts[grade] ?? 0) + 1;
      _busy = false;
    });
    if (round.done) {
      _deal();
    } else {
      _keepFocus();
    }
  }

  Future<void> _undo() async {
    final round = _round;
    if (_undoStack.isEmpty || _busy || round == null) return;
    final entry = _undoStack.removeLast();
    await context.read<MemoController>().restoreReview(entry.fact.id, entry.previous);
    if (!mounted) return;
    if (entry.requeued) {
      final queue = _queues[entry.fact.deckId];
      final index = queue?.lastIndexWhere((item) => item.id == entry.fact.id) ?? -1;
      if (index >= 0) queue!.removeAt(index);
      _requeuedIds.remove(entry.fact.id);
    }
    round.unmatch(entry.fact.id);
    setState(() {
      _counts[entry.grade] = ((_counts[entry.grade] ?? 1) - 1).clamp(0, 999);
    });
    _keepFocus();
  }

  void _skipBoard() {
    final round = _round;
    if (_done || _busy || round == null) return;
    setState(() => _skipped += round.unmatchedCount);
    _deal();
    _keepFocus();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS): _skipBoard,
        const SingleActivator(LogicalKeyboardKey.keyZ): _undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.maybePop(context),
      },
      child: Focus(
        autofocus: true,
        focusNode: _focusNode,
        child: Scaffold(
          appBar: AppBar(
            title: Text(_done ? 'Sesión terminada' : 'Relacionar'),
            actions: [
              IconButton(
                tooltip: 'Deshacer último acierto (Z)',
                onPressed: _undoStack.isEmpty || _busy ? null : _undo,
                icon: const Icon(Icons.undo),
              ),
              IconButton(
                tooltip: 'Saltar tablero (S)',
                onPressed: _done || _busy ? null : _skipBoard,
                icon: const Icon(Icons.skip_next),
              ),
            ],
          ),
          body: PageFrame(
            maxWidth: 720,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: _done ? _summary() : _board(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _board() {
    final round = _round!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: round.facts.isEmpty ? 0 : round.matched.length / round.facts.length,
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(height: 8),
        Text(
          [
            if (_deckTitle(_currentDeckId) != null) _deckTitle(_currentDeckId)!,
            '${round.matched.length} de ${round.facts.length} en este tablero',
            '$_pendingCount pendientes',
          ].join(' · '),
          style: TextStyle(color: AppTheme.muted(context), fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          round.selectedId == null
              ? 'Toca un término o una definición. Cada pareja acertada lleva su color.'
              : 'Ahora toca su pareja al otro lado.',
          style: TextStyle(color: AppTheme.muted(context, 0.7), fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _column(prompts: true)),
              const SizedBox(width: 12),
              Expanded(child: _column(prompts: false)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _column({required bool prompts}) {
    final round = _round!;
    final items = prompts ? round.prompts : round.answers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          prompts ? 'TÉRMINO' : 'DEFINICIÓN',
          style: const TextStyle(
            fontSize: 12,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1D4ED8),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final fact = items[index];
              final pair = round.pairIndex[fact.id];
              return _MatchTile(
                text: prompts ? fact.prompt : fact.answer,
                selected: round.selectedId == fact.id && round.selectedIsPrompt == prompts,
                pairColor: pair == null ? null : MatchPalette.pair(pair),
                pairNumber: pair == null ? null : pair + 1,
                flash: _flashIds.contains(fact.id),
                onTap: () => _onTap(fact.id, prompts),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _summary() {
    if (_graded == 0 && _skipped == 0) {
      return const Center(
        child: Text(
          'No hay suficientes pares cortos. Hacen falta al menos 4 (CE · Órganos, LPACAP o Informática · Redes).',
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
              '$_graded emparejados',
              if (_skipped > 0) '$_skipped saltados',
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

class MatchPalette {
  static const selecting = Color(0xFFF59E0B);
  static const miss = Color(0xFFDC2626);
  static const pairs = [
    Color(0xFF0284C7),
    Color(0xFF7C3AED),
    Color(0xFF0D9488),
    Color(0xFFDB2777),
  ];

  static Color pair(int index) => pairs[index % pairs.length];
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({
    required this.text,
    required this.selected,
    required this.flash,
    required this.onTap,
    this.pairColor,
    this.pairNumber,
  });

  final String text;
  final bool selected;
  final bool flash;
  final Color? pairColor;
  final int? pairNumber;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final matched = pairColor != null;
    final color = flash
        ? MatchPalette.miss
        : matched
            ? pairColor!
            : selected
                ? MatchPalette.selecting
                : Theme.of(context).colorScheme.outlineVariant;
    final fill = flash || matched || selected ? color.withValues(alpha: 0.18) : AppTheme.card(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: matched ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color, width: selected || matched || flash ? 2.5 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (matched || selected || flash) ...[
                _StatusMark(
                  color: color,
                  label: pairNumber?.toString(),
                  miss: flash,
                  selected: selected && !matched,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: matched || selected || flash ? color : onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusMark extends StatelessWidget {
  const _StatusMark({
    required this.color,
    this.label,
    this.miss = false,
    this.selected = false,
  });

  final Color color;
  final String? label;
  final bool miss;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: miss
          ? const Icon(Icons.close, size: 16, color: Colors.white)
          : selected
              ? const Icon(Icons.touch_app, size: 14, color: Colors.white)
              : Text(
                  label ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                ),
    );
  }
}
