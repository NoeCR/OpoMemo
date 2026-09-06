import 'dart:math';

import 'cloze.dart';

/// Banco de fichas para rellenar huecos (estilo Duolingo).
abstract final class ClozeBank {
  static const fallback = [
    '1 mes',
    '3 meses',
    '6 meses',
    '10 días',
    '15 días',
    '30 días',
    '1 año',
    '4 años',
    'mitad',
    'Congreso',
    'Senado',
  ];

  static List<String> chips({
    required List<String> answers,
    List<String> distractors = const [],
    List<String> extras = const [],
    int minSize = 5,
    Random? random,
  }) {
    final rng = random ?? Random();
    final out = [for (final item in answers) item.trim()].where((item) => item.isNotEmpty).toList();
    final want = max(minSize, out.length + 2);
    bool has(String word) => out.any((item) => Cloze.same(item, word));
    void offer(String raw) {
      final word = raw.trim();
      if (word.isEmpty || has(word) || out.length >= want) return;
      out.add(word);
    }

    final decoys = [...distractors, ...extras]..shuffle(rng);
    for (final item in decoys) {
      offer(item);
    }
    final spare = [...fallback]..shuffle(rng);
    for (final item in spare) {
      offer(item);
    }
    out.shuffle(rng);
    return out;
  }
}

/// Estado de una frase: tocas fichas del banco para llenar los huecos.
class ClozePick {
  ClozePick({required this.answers, required List<String> bank})
      : slots = List<String?>.filled(answers.length, null),
        unused = [...bank];

  final List<String> answers;
  final List<String?> slots;
  final List<String> unused;
  int? selectedSlot;

  bool get complete => answers.isNotEmpty && slots.every((item) => item != null);

  int get activeSlot {
    if (selectedSlot != null && selectedSlot! >= 0 && selectedSlot! < slots.length && slots[selectedSlot!] == null) {
      return selectedSlot!;
    }
    return slots.indexWhere((item) => item == null);
  }

  void tapBank(int unusedIndex) {
    if (unusedIndex < 0 || unusedIndex >= unused.length) return;
    final target = activeSlot;
    if (target < 0) return;
    slots[target] = unused.removeAt(unusedIndex);
    selectedSlot = null;
  }

  void tapSlot(int index) {
    if (index < 0 || index >= slots.length) return;
    final placed = slots[index];
    if (placed != null) {
      unused.add(placed);
      slots[index] = null;
      selectedSlot = index;
      return;
    }
    selectedSlot = index;
  }

  List<bool> hits() => [
        for (var i = 0; i < answers.length; i++) Cloze.same(answers[i], slots[i] ?? ''),
      ];
}
