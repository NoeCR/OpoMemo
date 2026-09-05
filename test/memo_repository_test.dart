import 'package:flutter_test/flutter_test.dart';
import 'package:opomemo/data/memo_repository.dart';
import 'package:opomemo/database/app_database.dart';
import 'package:opomemo/models/deck.dart';
import 'package:opomemo/models/review.dart';

void main() {
  late AppDatabase database;
  late MemoRepository repo;
  var now = DateTime(2026, 9, 5, 10);

  setUp(() async {
    now = DateTime(2026, 9, 5, 10);
    database = await AppDatabase.openInMemory();
    repo = MemoRepository(database, clock: () => now);
  });

  tearDown(() async {
    await database.close();
  });

  test('crea mazo, cartas y cuenta pendientes', () async {
    final deck = await repo.createDeck(
      name: 'Redes',
      description: '',
      domain: DeckDomain.info,
    );
    await repo.createFact(deckId: deck.id, prompt: 'HTTPS', answer: '443');
    await repo.createFact(deckId: deck.id, prompt: 'SSH', answer: '22');

    final summaries = await repo.summaries();
    expect(summaries, hasLength(1));
    expect(summaries.first.factCount, 2);
    expect(summaries.first.dueCount, 2);
  });

  test('tras un Sí la carta no sale hoy y sí mañana', () async {
    final deck = await repo.createDeck(
      name: 'Redes',
      description: '',
      domain: DeckDomain.info,
    );
    final fact = await repo.createFact(deckId: deck.id, prompt: 'HTTPS', answer: '443');
    await repo.grade(fact.id, ReviewGrade.yes);

    expect(await repo.dueFacts(deck.id), isEmpty);

    now = DateTime(2026, 9, 6, 9);
    final due = await repo.dueFacts(deck.id);
    expect(due.map((item) => item.id), [fact.id]);
  });

  test('un No hace que la carta vuelva mañana, no hoy', () async {
    final deck = await repo.createDeck(
      name: 'Redes',
      description: '',
      domain: DeckDomain.info,
    );
    final fact = await repo.createFact(deckId: deck.id, prompt: 'HTTPS', answer: '443');
    await repo.grade(fact.id, ReviewGrade.no);

    expect(await repo.dueFacts(deck.id), isEmpty);
    now = DateTime(2026, 9, 6, 8);
    expect(await repo.dueFacts(deck.id), isNotEmpty);
  });
}
