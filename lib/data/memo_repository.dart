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
        ) AS due_count,
        (
          SELECT COUNT(*) FROM facts f
          LEFT JOIN review_states r ON r.fact_id = f.id
          WHERE f.deck_id = d.id AND r.fact_id IS NULL
        ) AS new_count,
        (SELECT COUNT(*) FROM facts f JOIN review_states r ON r.fact_id = f.id WHERE f.deck_id = d.id AND r.box = 1) AS box1,
        (SELECT COUNT(*) FROM facts f JOIN review_states r ON r.fact_id = f.id WHERE f.deck_id = d.id AND r.box = 2) AS box2,
        (SELECT COUNT(*) FROM facts f JOIN review_states r ON r.fact_id = f.id WHERE f.deck_id = d.id AND r.box = 3) AS box3,
        (SELECT COUNT(*) FROM facts f JOIN review_states r ON r.fact_id = f.id WHERE f.deck_id = d.id AND r.box = 4) AS box4,
        (SELECT COUNT(*) FROM facts f JOIN review_states r ON r.fact_id = f.id WHERE f.deck_id = d.id AND r.box = 5) AS box5,
        (SELECT COUNT(*) FROM facts f WHERE f.deck_id = d.id AND f.flagged = 1) AS flagged_count
      FROM decks d
      ORDER BY d.group_name ASC, d.name ASC
    ''', [dueDay]);

    return rows
        .map(
          (row) => DeckSummary(
            deck: Deck.fromMap(row),
            factCount: _asInt(row['fact_count']),
            dueCount: _asInt(row['due_count']),
            newCount: _asInt(row['new_count']),
            boxCounts: [
              _asInt(row['box1']),
              _asInt(row['box2']),
              _asInt(row['box3']),
              _asInt(row['box4']),
              _asInt(row['box5']),
            ],
            flaggedCount: _asInt(row['flagged_count']),
          ),
        )
        .toList();
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
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
    String groupName = Deck.defaultGroup,
    String source = 'user',
    String? id,
  }) async {
    final now = _clock();
    final deck = Deck(
      id: id ?? _uuid.v4(),
      name: name.trim(),
      description: description.trim(),
      domain: domain,
      groupName: groupName.trim().isEmpty ? Deck.defaultGroup : groupName.trim(),
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
    FactKind kind = FactKind.pregunta,
    String clozeText = '',
    List<String> distractors = const [],
    String? id,
  }) async {
    final now = _clock();
    final fact = Fact(
      id: id ?? _uuid.v4(),
      deckId: deckId,
      prompt: prompt.trim(),
      answer: answer.trim(),
      source: source.trim(),
      kind: kind,
      clozeText: clozeText.trim(),
      distractors: distractors,
      flagged: false,
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
    required List<SeedFact> facts,
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
        kind: item.kind,
        clozeText: item.clozeText,
        distractors: item.distractors,
        flagged: false,
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

  Future<List<Fact>> dueFacts({String? deckId, int limit = 20}) async {
    final dueDay = LeitnerScheduler.calendarDay(_clock()).toIso8601String();
    final rows = await _database.db.rawQuery(
      '''
      SELECT f.*
      FROM facts f
      LEFT JOIN review_states r ON r.fact_id = f.id
      WHERE (r.fact_id IS NULL OR r.next_due <= ?)
        AND (? IS NULL OR f.deck_id = ?)
      ORDER BY CASE WHEN r.fact_id IS NULL THEN 0 ELSE 1 END, f.created_at ASC
      LIMIT ?
      ''',
      [dueDay, deckId, deckId, limit],
    );
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

  Future<void> restoreReview(String factId, ReviewState? previous) async {
    if (previous == null) {
      await _database.db.delete('review_states', where: 'fact_id = ?', whereArgs: [factId]);
      return;
    }
    await _database.db.insert(
      'review_states',
      previous.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> setFlagged(String factId, bool flagged) async {
    await _database.db.update(
      'facts',
      {'flagged': flagged ? 1 : 0, 'updated_at': _nowIso},
      where: 'id = ?',
      whereArgs: [factId],
    );
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
