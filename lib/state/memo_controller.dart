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
      final name = summary.deck.groupName.trim().isEmpty ? 'Mis mazos' : summary.deck.groupName;
      buckets.putIfAbsent(name, () => []).add(summary);
    }
    return [
      for (final entry in buckets.entries) DeckGroup(name: entry.key, decks: entry.value),
    ];
  }

  Future<void> bootstrap({String? seedJson}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await ContentSeed.ensure(_repo, jsonText: seedJson);
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
    String groupName = 'Mis mazos',
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
  }) async {
    final fact = await _repo.createFact(
      deckId: deckId,
      prompt: prompt,
      answer: answer,
      source: source,
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

  Future<List<Fact>> dueFacts(String deckId, {int limit = 20}) {
    return _repo.dueFacts(deckId, limit: limit);
  }

  Future<void> grade(String factId, ReviewGrade grade) async {
    await _repo.grade(factId, grade);
    await reload();
  }
}
