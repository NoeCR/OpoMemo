import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opomemo/data/ce_organos_seed.dart';
import 'package:opomemo/data/content_seed.dart';
import 'package:opomemo/data/lpacap_plazos_seed.dart';
import 'package:opomemo/data/markdown_card_parser.dart';
import 'package:opomemo/data/memo_repository.dart';
import 'package:opomemo/database/app_database.dart';
import 'package:opomemo/models/deck.dart';
import 'package:opomemo/models/fact.dart';

void main() {
  String readAsset(String path) => File(path).readAsStringSync();

  Map<String, String> markdownByPrefix() => {
        for (final item in ContentSeed.catalog) item.idPrefix: readAsset(item.assetPath),
      };

  List<ParsedSeedDeck> parseCatalog(MarkdownSeedCatalog item) {
    return MarkdownCardParser.parse(
      readAsset(item.assetPath),
      idPrefix: item.idPrefix,
      groupName: item.groupName,
      sourcePrefix: item.sourcePrefix,
    );
  }

  test('cada markdown se parte en mazos por capítulo, sin el cuadro resumen', () {
    const expected = {
      'md.ley19': (decks: 8, facts: 67, source: 'LTAIBG'),
      'md.trebep': (decks: 16, facts: 86, source: 'TREBEP'),
      'md.ley30': (decks: 6, facts: 18, source: 'Ley 30/1984'),
      'md.ley53': (decks: 6, facts: 24, source: 'Ley 53/1984'),
    };

    for (final item in ContentSeed.catalog) {
      final decks = parseCatalog(item);
      final facts = decks.expand((deck) => deck.facts).toList();
      final want = expected[item.idPrefix]!;
      expect(decks, hasLength(want.decks), reason: item.idPrefix);
      expect(facts, hasLength(want.facts), reason: item.idPrefix);
      expect(facts.every((fact) => fact.prompt.isNotEmpty && fact.answer.isNotEmpty), isTrue);
      expect(decks.any((deck) => deck.name.toLowerCase().contains('cuadro')), isFalse);
      expect(facts.first.source, startsWith(want.source));
    }
  });

  test('siembra los markdown sin duplicar y retira mazos semilla viejos', () async {
    final database = await AppDatabase.openInMemory();
    addTearDown(database.close);
    final repo = MemoRepository(database, clock: () => DateTime(2026, 9, 6));
    await repo.seedDeck(
      id: 'opotest.5.19',
      name: 'Título Preliminar',
      description: '',
      domain: DeckDomain.leyes,
      groupName: 'Constitución Española',
      facts: const [
        SeedFact(id: 'opotest.q.1', prompt: 'Forma política', answer: 'Monarquía parlamentaria'),
      ],
    );

    final files = markdownByPrefix();
    await ContentSeed.ensure(repo, markdownByPrefix: files);
    await ContentSeed.ensure(repo, markdownByPrefix: files);

    final summaries = await repo.summaries();
    expect(summaries.any((item) => item.deck.id == 'opotest.5.19'), isFalse);
    expect(summaries.every((item) => item.deck.source == 'seed'), isTrue);
    expect(
      summaries.map((item) => item.deck.groupName).toSet(),
      {
        'Ley 19/2013 · Transparencia',
        'TREBEP · RDL 5/2015',
        'Ley 30/1984 · Reforma de la Función Pública',
        'Ley 53/1984 · Incompatibilidades',
        'Ley 39/2015 · Procedimiento',
        'Constitución Española',
      },
    );
    expect(summaries.where((item) => item.deck.id.startsWith('md.ley30.')), hasLength(6));
    expect(summaries.where((item) => item.deck.id.startsWith('md.ley53.')), hasLength(6));
    expect(summaries.any((item) => item.deck.id == LpacapPlazosSeed.deckId), isTrue);
    expect(summaries.any((item) => item.deck.id == CeOrganosSeed.deckId), isTrue);
    expect(summaries.fold<int>(0, (sum, item) => sum + item.factCount), greaterThan(195));
    final cloze = await repo.dueFacts(clozeOnly: true, limit: 80);
    expect(cloze, isNotEmpty);
    expect(cloze.every((fact) => fact.hasCloze), isTrue);
  });
}
