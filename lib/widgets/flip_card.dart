import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/memo_markup.dart';

class FlipCard extends StatefulWidget {
  const FlipCard({
    super.key,
    required this.flipped,
    required this.front,
    required this.back,
    required this.onTap,
  });

  final bool flipped;
  final Widget front;
  final Widget back;
  final VoidCallback onTap;

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      value: widget.flipped ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flipped == widget.flipped) return;
    if (widget.flipped) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final value = _controller.value;
          final showBack = value >= 0.5;
          final angle = value * math.pi;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(showBack ? angle + math.pi : angle),
            child: showBack ? widget.back : widget.front,
          );
        },
      ),
    );
  }
}

class MemoFace extends StatelessWidget {
  const MemoFace({
    super.key,
    required this.label,
    required this.text,
    this.caption,
    this.explanation,
    required this.tint,
  });

  final String label;
  final String text;
  final String? caption;
  final String? explanation;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final note = explanation?.trim() ?? '';
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 280),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tint.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
                color: tint,
              ),
            ),
            const SizedBox(height: 18),
            Text.rich(
              MemoMarkup.toSpan(
                text,
                const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                  color: Color(0xFF111827),
                ),
                accent: tint,
              ),
              textAlign: TextAlign.center,
            ),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aclaración',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w800,
                        color: tint,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text.rich(
                      MemoMarkup.toSpan(
                        note,
                        TextStyle(
                          fontSize: 16,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          color: Colors.black.withValues(alpha: 0.72),
                        ),
                        accent: tint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (caption != null && caption!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                caption!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.45),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
