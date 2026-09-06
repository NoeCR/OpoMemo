import 'dart:math';

import '../models/fact.dart';
import '../models/review.dart';

enum MatchTapResult { selected, switched, cleared, matched, missed }

/// Una ronda de emparejar término ↔ definición. Toque-toque, sin flechas.
class MatchRound {
  MatchRound(List<Fact> facts, {Random? random}) : facts = List.unmodifiable(facts) {
    final rng = random ?? Random();
    prompts = [...facts]..shuffle(rng);
    answers = [...facts]..shuffle(rng);
  }

  static const boardSize = 4;

  final List<Fact> facts;
  late final List<Fact> prompts;
  late final List<Fact> answers;
  final matched = <String>{};
  final pairIndex = <String, int>{};
  final misses = <String, int>{};
  String? selectedId;
  bool? selectedIsPrompt;
  var _nextPair = 0;

  bool get done => matched.length == facts.length;

  int get unmatchedCount => facts.length - matched.length;

  /// Arma un tablero de [size] pares del mismo lote. No empieza un tablero nuevo
  /// solo con la reserva: si [remaining] está vacío, no hay más ronda.
  static List<Fact>? pickBoard({
    required List<Fact> remaining,
    List<Fact> reserve = const [],
    int size = boardSize,
    Set<String> seen = const {},
  }) {
    final picked = <Fact>[];
    final used = <String>{};
    for (final fact in remaining) {
      if (picked.length >= size) break;
      if (!used.add(fact.id)) continue;
      picked.add(fact);
    }
    if (picked.isEmpty) return null;
    if (picked.length >= size) return picked;
    for (final fact in reserve) {
      if (picked.length >= size) break;
      if (seen.contains(fact.id) || !used.add(fact.id)) continue;
      picked.add(fact);
    }
    if (picked.length < size) return null;
    return picked;
  }

  ReviewGrade gradeFor(String factId) {
    final n = misses[factId] ?? 0;
    if (n <= 0) return ReviewGrade.yes;
    if (n == 1) return ReviewGrade.almost;
    return ReviewGrade.no;
  }

  MatchTapResult tap(String factId, bool isPrompt) {
    if (matched.contains(factId)) return MatchTapResult.cleared;
    if (selectedId == null) {
      selectedId = factId;
      selectedIsPrompt = isPrompt;
      return MatchTapResult.selected;
    }
    if (selectedId == factId && selectedIsPrompt == isPrompt) {
      selectedId = null;
      selectedIsPrompt = null;
      return MatchTapResult.cleared;
    }
    if (selectedIsPrompt == isPrompt) {
      selectedId = factId;
      return MatchTapResult.switched;
    }
    if (selectedId == factId) {
      matched.add(factId);
      pairIndex[factId] = _nextPair;
      _nextPair += 1;
      selectedId = null;
      selectedIsPrompt = null;
      return MatchTapResult.matched;
    }
    misses[selectedId!] = (misses[selectedId!] ?? 0) + 1;
    selectedId = null;
    selectedIsPrompt = null;
    return MatchTapResult.missed;
  }

  void unmatch(String factId) {
    matched.remove(factId);
    pairIndex.remove(factId);
    selectedId = null;
    selectedIsPrompt = null;
  }
}
