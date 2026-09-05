import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../domain/leitner_scheduler.dart';
import '../models/deck.dart';
import '../models/fact.dart';
import '../models/review.dart';

class MemoRepository {
  MemoRepository(this._database, {Uuid? uuid, DateTime Function()? clock})
      : _uuid = uuid ?? const Uuid(),
        _clock = clock ?? DateTime.now;

  final AppDatabase _database;
  final Uuid _uuid;
  final DateTime Function() _clock;

  String get _nowIso => _clock().toIso8601String();

  Future<List<DeckSummary>> summaries() async {
    final dueDay = LeitnerScheduler.calendarDay(_clock()).toIso8601String();
    final rows = await _database.db.rawQuery('''
      SELECT
        d.*,
        (SELECT COUNT(*) FROM facts f WHERE f.deck_id = d.id) AS fact_count,
        (
          SELECT COUNT(*)
          FROM facts f
          LEFT JOIN review_states r ON r.fact_id = f.id
          WHERE f.deck_id = d.id
            AND (r.fact_id IS NULL OR r.next_due <= ?)
        ) AS due_count
      FROM decks d
      ORDER BY d.group_name ASC, d.name ASC
    ''', [dueDay]);

    return rows
        .map(
          (row) => DeckSummary(
            deck: Deck.fromMap(row),
            factCount: row['fact_count'] as int? ?? 0,
            dueCount: row['due_count'] as int? ?? 0,
          ),
        )
        .toList();
  }

  Future<Deck?> deckById(String id) async {
    final rows = await _database.db.query('decks', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Deck.fromMap(rows.first);
  }

  Future<int> deckCount() async {
    final rows = await _database.db.rawQuery('SELECT COUNT(*) AS c FROM decks');
    return rows.first['c'] as int? ?? 0;
  }

  Future<Deck> createDeck({
    required String name,
    required String description,
    required DeckDomain domain,
    String groupName = 'Mis mazos',
    String source = 'user',
    String? id,
  }) async {
    final now = _clock();
    final deck = Deck(
      id: id ?? _uuid.v4(),
      name: name.trim(),
      description: description.trim(),
      domain: domain,
      groupName: groupName.trim().isEmpty ? 'Mis mazos' : groupName.trim(),
      source: source,
      createdAt: now,
      updatedAt: now,
    );
    await _database.db.insert('decks', deck.toMap());
    return deck;
  }

  Future<void> updateDeck(Deck deck) async {
    final updated = deck.copyWith(updatedAt: _clock());
    await _database.db.update(
      'decks',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [deck.id],
    );
  }

  Future<void> deleteDeck(String id) async {
    await _database.db.delete('decks', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Fact>> factsFor(String deckId) async {
    final rows = await _database.db.query(
      'facts',
      where: 'deck_id = ?',
      whereArgs: [deckId],
      orderBy: 'created_at ASC',
    );
    return rows.map(Fact.fromMap).toList();
  }

  Future<Fact> createFact({
    required String deckId,
    required String prompt,
    required String answer,
    String source = '',
    String? id,
  }) async {
    final now = _clock();
    final fact = Fact(
      id: id ?? _uuid.v4(),
      deckId: deckId,
      prompt: prompt.trim(),
      answer: answer.trim(),
      source: source.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await _database.db.insert('facts', fact.toMap());
    await _touchDeck(deckId);
    return fact;
  }

  Future<void> seedDeck({
    required String id,
    required String name,
    required String description,
    required DeckDomain domain,
    required String groupName,
    required List<({String id, String prompt, String answer, String source})> facts,
  }) async {
    final existing = await deckById(id);
    if (existing == null) {
      await createDeck(
        id: id,
        name: name,
        description: description,
        domain: domain,
        groupName: groupName,
        source: 'seed',
      );
    } else {
      await updateDeck(
        existing.copyWith(
          name: name,
          description: description,
          domain: domain,
          groupName: groupName,
          source: 'seed',
        ),
      );
    }
    for (final item in facts) {
      final fact = Fact(
        id: item.id,
        deckId: id,
        prompt: item.prompt,
        answer: item.answer,
        source: item.source,
        createdAt: _clock(),
        updatedAt: _clock(),
      );
      await _database.db.insert(
        'facts',
        fact.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> updateFact(Fact fact) async {
    final updated = fact.copyWith(updatedAt: _clock());
    await _database.db.update(
      'facts',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [fact.id],
    );
    await _touchDeck(fact.deckId);
  }

  Future<void> deleteFact(String id) async {
    final rows = await _database.db.query('facts', columns: ['deck_id'], where: 'id = ?', whereArgs: [id]);
    await _database.db.delete('facts', where: 'id = ?', whereArgs: [id]);
    if (rows.isNotEmpty) {
      await _touchDeck(rows.first['deck_id']! as String);
    }
  }

  Future<ReviewState?> reviewFor(String factId) async {
    final rows = await _database.db.query(
      'review_states',
      where: 'fact_id = ?',
      whereArgs: [factId],
    );
    if (rows.isEmpty) return null;
    return ReviewState.fromMap(rows.first);
  }

  Future<List<Fact>> dueFacts(String deckId, {int limit = 20}) async {
    final dueDay = LeitnerScheduler.calendarDay(_clock()).toIso8601String();
    final rows = await _database.db.rawQuery('''
      SELECT f.*
      FROM facts f
      LEFT JOIN review_states r ON r.fact_id = f.id
      WHERE f.deck_id = ?
        AND (r.fact_id IS NULL OR r.next_due <= ?)
      ORDER BY CASE WHEN r.fact_id IS NULL THEN 0 ELSE 1 END, f.created_at ASC
      LIMIT ?
    ''', [deckId, dueDay, limit]);
    final facts = rows.map(Fact.fromMap).toList();
    facts.shuffle();
    return facts;
  }

  Future<ReviewState> grade(String factId, ReviewGrade grade) async {
    final current = await reviewFor(factId);
    final next = LeitnerScheduler.apply(
      factId: factId,
      current: current,
      grade: grade,
      now: _clock(),
    );
    await _database.db.insert(
      'review_states',
      next.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return next;
  }

  Future<void> _touchDeck(String deckId) async {
    await _database.db.update(
      'decks',
      {'updated_at': _nowIso},
      where: 'id = ?',
      whereArgs: [deckId],
    );
  }
}
