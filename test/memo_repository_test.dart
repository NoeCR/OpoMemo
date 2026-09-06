import 'package:flutter_test/flutter_test.dart';
import 'package:opomemo/data/memo_repository.dart';
import 'package:opomemo/database/app_database.dart';
import 'package:opomemo/models/deck.dart';
import 'package:opomemo/models/fact.dart';
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
    expect(summaries.first.newCount, 2);
    expect(summaries.first.boxCounts, [0, 0, 0, 0, 0]);
  });

  test('tras un Sí la carta no sale hoy y sí mañana', () async {
    final deck = await repo.createDeck(
      name: 'Redes',
      description: '',
      domain: DeckDomain.info,
    );
    final fact = await repo.createFact(deckId: deck.id, prompt: 'HTTPS', answer: '443');
    await repo.grade(fact.id, ReviewGrade.yes);

    expect(await repo.dueFacts(deckId: deck.id), isEmpty);

    now = DateTime(2026, 9, 6, 9);
    final due = await repo.dueFacts(deckId: deck.id);
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

    expect(await repo.dueFacts(deckId: deck.id), isEmpty);
    now = DateTime(2026, 9, 6, 8);
    expect(await repo.dueFacts(deckId: deck.id), isNotEmpty);
  });

  test('el repaso del día mezcla mazos y respeta el tope', () async {
    final redes = await repo.createDeck(name: 'Redes', description: '', domain: DeckDomain.info);
    final leyes = await repo.createDeck(name: 'CE', description: '', domain: DeckDomain.leyes);
    await repo.createFact(deckId: redes.id, prompt: 'HTTPS', answer: '443');
    await repo.createFact(deckId: leyes.id, prompt: 'Forma política', answer: 'Monarquía parlamentaria');
    final mixed = await repo.dueFacts(limit: 10);
    expect(mixed.map((item) => item.deckId).toSet(), {redes.id, leyes.id});
  });

  test('deshacer restaura el estado de repaso anterior', () async {
    final deck = await repo.createDeck(name: 'Redes', description: '', domain: DeckDomain.info);
    final fact = await repo.createFact(deckId: deck.id, prompt: 'HTTPS', answer: '443');
    await repo.grade(fact.id, ReviewGrade.yes);
    expect(await repo.dueFacts(deckId: deck.id), isEmpty);
    await repo.restoreReview(fact.id, null);
    expect(await repo.dueFacts(deckId: deck.id), isNotEmpty);
  });

  test('un Sí pasa la carta a caja 1 y deja de contar como nueva', () async {
    final deck = await repo.createDeck(name: 'Redes', description: '', domain: DeckDomain.info);
    final fact = await repo.createFact(deckId: deck.id, prompt: 'HTTPS', answer: '443');
    await repo.createFact(deckId: deck.id, prompt: 'SSH', answer: '22');
    await repo.grade(fact.id, ReviewGrade.yes);

    final summary = (await repo.summaries()).first;
    expect(summary.newCount, 1);
    expect(summary.boxCounts, [1, 0, 0, 0, 0]);
  });

  test('marcar una carta persiste el flag', () async {
    final deck = await repo.createDeck(name: 'Redes', description: '', domain: DeckDomain.info);
    final fact = await repo.createFact(deckId: deck.id, prompt: 'HTTPS', answer: '443');
    expect(fact.flagged, isFalse);

    await repo.setFlagged(fact.id, true);
    final marked = (await repo.factsFor(deck.id)).first;
    expect(marked.flagged, isTrue);
    expect((await repo.summaries()).first.flaggedCount, 1);

    await repo.setFlagged(fact.id, false);
    expect((await repo.factsFor(deck.id)).first.flagged, isFalse);
  });

  test('el hecho guarda tipo, hueco y distractores', () async {
    final deck = await repo.createDeck(name: 'Plazos', description: '', domain: DeckDomain.leyes);
    final fact = await repo.createFact(
      deckId: deck.id,
      prompt: 'Plazo máximo si la norma no lo fija',
      answer: '3 meses',
      source: 'LPACAP art. 21.3',
      kind: FactKind.hueco,
      clozeText: 'El plazo máximo será de {{3 meses}}.',
      distractors: const ['6 meses', '1 mes'],
    );
    final stored = (await repo.factsFor(deck.id)).firstWhere((item) => item.id == fact.id);
    expect(stored.kind, FactKind.hueco);
    expect(stored.clozeText, contains('{{3 meses}}'));
    expect(stored.distractors, ['6 meses', '1 mes']);
  });

  test('el hecho guarda la aclaración del dorso', () async {
    final deck = await repo.createDeck(name: 'Plazos', description: '', domain: DeckDomain.leyes);
    final fact = await repo.createFact(
      deckId: deck.id,
      prompt: 'Plazo de alzada (acto expreso)',
      answer: '1 mes',
      explanation: 'Si el acto no es expreso, cabe en cualquier momento.',
    );
    expect((await repo.factsFor(deck.id)).firstWhere((item) => item.id == fact.id).explanation, contains('cualquier momento'));
  });

  test('dueFacts puede filtrar por tipo de hecho', () async {
    final deck = await repo.createDeck(name: 'Mixto', description: '', domain: DeckDomain.leyes);
    await repo.createFact(deckId: deck.id, prompt: 'Pregunta', answer: 'Larga', kind: FactKind.pregunta);
    await repo.createFact(deckId: deck.id, prompt: 'HTTPS', answer: '443', kind: FactKind.termino);
    final pairs = await repo.dueFacts(deckId: deck.id, kind: FactKind.termino);
    expect(pairs, hasLength(1));
    expect(pairs.single.prompt, 'HTTPS');
  });

  test('el mazo se crea en una sección y se puede mover', () async {
    final deck = await repo.createDeck(
      name: 'Plazos',
      description: '',
      domain: DeckDomain.leyes,
      groupName: 'LPACAP',
    );
    expect((await repo.deckById(deck.id))!.groupName, 'LPACAP');

    await repo.updateDeck(deck.copyWith(groupName: Deck.defaultGroup));
    expect((await repo.deckById(deck.id))!.groupName, Deck.defaultGroup);
  });

  test('volver a sembrar no mueve un mazo de sección', () async {
    await repo.seedDeck(
      id: 'seed.plazos',
      name: 'Plazos',
      description: '',
      domain: DeckDomain.leyes,
      groupName: 'LPACAP',
      facts: const [],
    );
    final deck = await repo.deckById('seed.plazos');
    await repo.updateDeck(deck!.copyWith(groupName: Deck.defaultGroup));
    await repo.seedDeck(
      id: 'seed.plazos',
      name: 'Plazos actualizado',
      description: '',
      domain: DeckDomain.leyes,
      groupName: 'LPACAP',
      facts: const [],
    );
    final again = await repo.deckById('seed.plazos');
    expect(again!.name, 'Plazos actualizado');
    expect(again.groupName, Deck.defaultGroup);
  });
}
