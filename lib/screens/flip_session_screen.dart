import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/fact.dart';
import '../models/review.dart';
import '../state/memo_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/flip_card.dart';
import '../widgets/page_frame.dart';

class FlipSessionScreen extends StatefulWidget {
  const FlipSessionScreen({super.key, required this.deckId});

  final String deckId;

  @override
  State<FlipSessionScreen> createState() => _FlipSessionScreenState();
}

class _FlipSessionScreenState extends State<FlipSessionScreen> {
  List<Fact> _queue = const [];
  var _index = 0;
  var _flipped = false;
  var _loading = true;
  var _grading = false;
  final _counts = <ReviewGrade, int>{
    ReviewGrade.no: 0,
    ReviewGrade.almost: 0,
    ReviewGrade.yes: 0,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final queue = await context.read<MemoController>().dueFacts(widget.deckId);
    if (!mounted) return;
    setState(() {
      _queue = queue;
      _loading = false;
    });
  }

  Future<void> _grade(ReviewGrade grade) async {
    if (_grading || _queue.isEmpty) return;
    setState(() => _grading = true);
    final fact = _queue[_index];
    await context.read<MemoController>().grade(fact.id, grade);
    if (!mounted) return;
    setState(() {
      _counts[grade] = (_counts[grade] ?? 0) + 1;
      _grading = false;
      _flipped = false;
      _index += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final done = _index >= _queue.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(done ? 'Sesión terminada' : '${_index + 1} / ${_queue.length}'),
      ),
      body: PageFrame(
        maxWidth: 640,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: done ? _Summary(counts: _counts, total: _queue.length) : _buildCard(),
        ),
      ),
    );
  }

  Widget _buildCard() {
    final fact = _queue[_index];
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
              key: ValueKey(fact.id),
              flipped: _flipped,
              onTap: () => setState(() => _flipped = !_flipped),
              front: MemoFace(
                label: 'Pregunta',
                text: fact.prompt,
                caption: 'Toca para voltear',
                tint: AppTheme.primary,
              ),
              back: MemoFace(
                label: 'Respuesta',
                text: fact.answer,
                caption: fact.source.isEmpty ? null : fact.source,
                tint: const Color(0xFF4338CA),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!_flipped)
          Text(
            'Intenta responder en voz alta antes de voltear.',
            style: TextStyle(color: Colors.black.withValues(alpha: 0.5)),
          )
        else
          Row(
            children: [
              Expanded(
                child: _GradeButton(
                  label: 'No',
                  color: const Color(0xFFB91C1C),
                  onPressed: _grading ? null : () => _grade(ReviewGrade.no),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GradeButton(
                  label: 'Casi',
                  color: const Color(0xFFB45309),
                  onPressed: _grading ? null : () => _grade(ReviewGrade.almost),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GradeButton(
                  label: 'Sí',
                  color: AppTheme.primary,
                  onPressed: _grading ? null : () => _grade(ReviewGrade.yes),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _GradeButton extends StatelessWidget {
  const _GradeButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
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
      child: Text(label),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.counts, required this.total});

  final Map<ReviewGrade, int> counts;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (total == 0) {
      return const Center(child: Text('Este mazo no tiene cartas pendientes hoy.'));
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Sesión hecha', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('$total cartas · mañana salen los No y los Casi'),
          const SizedBox(height: 24),
          _line('No', counts[ReviewGrade.no] ?? 0, const Color(0xFFB91C1C)),
          _line('Casi', counts[ReviewGrade.almost] ?? 0, const Color(0xFFB45309)),
          _line('Sí', counts[ReviewGrade.yes] ?? 0, AppTheme.primary),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Volver a mazos'),
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
