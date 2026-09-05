import 'package:flutter/material.dart';

class LeitnerStrip extends StatelessWidget {
  const LeitnerStrip({
    super.key,
    required this.newCount,
    required this.boxCounts,
    this.compact = false,
  });

  final int newCount;
  final List<int> boxCounts;
  final bool compact;

  static const _boxColors = [
    Color(0xFFB91C1C),
    Color(0xFFC2410C),
    Color(0xFFB45309),
    Color(0xFF047857),
    Color(0xFF0F766E),
  ];

  @override
  Widget build(BuildContext context) {
    final boxes = [
      for (var i = 0; i < 5; i++) i < boxCounts.length ? boxCounts[i] : 0,
    ];
    return Wrap(
      spacing: compact ? 6 : 8,
      runSpacing: 6,
      children: [
        _Chip(
          label: compact ? 'N $newCount' : 'Nuevas $newCount',
          color: const Color(0xFF4338CA),
          compact: compact,
        ),
        for (var i = 0; i < 5; i++)
          _Chip(
            label: compact ? '${i + 1} ${boxes[i]}' : 'Caja ${i + 1}  ${boxes[i]}',
            color: _boxColors[i],
            compact: compact,
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
    required this.compact,
  });

  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 10, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: compact ? 11 : 12,
        ),
      ),
    );
  }
}
