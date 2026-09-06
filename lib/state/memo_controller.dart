import 'package:flutter/foundation.dart';

import '../data/content_seed.dart';
import '../data/memo_repository.dart';
import '../models/deck.dart';
import '../models/fact.dart';
import '../models/review.dart';

class MemoController extends ChangeNotifier {
  MemoController(this._repo);

  final MemoRepository _repo;

  var loading = true;
  String? error;
  List<DeckSummary> summaries = const [];

  List<DeckGroup> get groups {
    final buckets = <String, List<DeckSummary>>{};
    for (final summary in summaries) {
      final name = summary.deck.groupName.trim().isEmpty ? Deck.defaultGroup : summary.deck.groupName;
      buckets.putIfAbsent(name, () => []).add(summary);
    }
    return [
      for (final entry in buckets.entries) DeckGroup(name: entry.key, decks: entry.value),
    ];
  }

  List<String> get groupNames {
    final seen = <String>{};
    final names = <String>[];
    void add(String raw) {
      final name = raw.trim().isEmpty ? Deck.defaultGroup : raw.trim();
      if (seen.add(name)) names.add(name);
    }

    add(Deck.defaultGroup);
    for (final group in groups) {
      add(group.name);
    }
    return names;
  }

  Future<void> bootstrap() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await ContentSeed.ensure(_repo);
      summaries = await _repo.summaries();
    } catch (e) {
      error = 'No se pudo abrir la base local.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> reload() async {
    summaries = await _repo.summaries();
    notifyListeners();
  }

  Future<Deck> createDeck({
    required String name,
    required String description,
    required DeckDomain domain,
    String groupName = Deck.defaultGroup,
  }) async {
    final deck = await _repo.createDeck(
      name: name,
      description: description,
      domain: domain,
      groupName: groupName,
    );
    await reload();
    return deck;
  }

  Future<void> updateDeck(Deck deck) async {
    await _repo.updateDeck(deck);
    await reload();
  }

  Future<void> deleteDeck(String id) async {
    await _repo.deleteDeck(id);
    await reload();
  }

  Future<Deck?> deckById(String id) => _repo.deckById(id);

  Future<List<Fact>> factsFor(String deckId) => _repo.factsFor(deckId);

  Future<Fact> createFact({
    required String deckId,
    required String prompt,
    required String answer,
    String source = '',
    FactKind kind = FactKind.pregunta,
    String clozeText = '',
    List<String> distractors = const [],
    String explanation = '',
  }) async {
    final fact = await _repo.createFact(
      deckId: deckId,
      prompt: prompt,
      answer: answer,
      source: source,
      kind: kind,
      clozeText: clozeText,
      distractors: distractors,
      explanation: explanation,
    );
    await reload();
    return fact;
  }

  Future<void> updateFact(Fact fact) async {
    await _repo.updateFact(fact);
    await reload();
  }

  Future<void> deleteFact(String id) async {
    await _repo.deleteFact(id);
    await reload();
  }

  Future<List<Fact>> dueFacts({String? deckId, int limit = 20}) {
    return _repo.dueFacts(deckId: deckId, limit: limit);
  }

  Future<ReviewState?> reviewFor(String factId) => _repo.reviewFor(factId);

  Future<ReviewState?> grade(String factId, ReviewGrade grade, {bool reload = false}) async {
    final previous = await _repo.reviewFor(factId);
    await _repo.grade(factId, grade);
    if (reload) await this.reload();
    return previous;
  }

  Future<void> restoreReview(String factId, ReviewState? previous) {
    return _repo.restoreReview(factId, previous);
  }

  Future<void> setFlagged(String factId, bool flagged) async {
    await _repo.setFlagged(factId, flagged);
    await reload();
  }
}
