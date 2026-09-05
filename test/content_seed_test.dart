import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opomemo/data/ce_organos_seed.dart';
import 'package:opomemo/data/content_seed.dart';
import 'package:opomemo/data/lpacap_plazos_seed.dart';
import 'package:opomemo/data/memo_repository.dart';
import 'package:opomemo/database/app_database.dart';

void main() {
  test('el extracto de OpoTest trae Constitución, LPACAP, Ley 40 y TREBEP', () {
    final file = File('assets/seed/opotest_decks.json');
    final payload = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final decks = payload['decks'] as List<dynamic>;
    expect(decks.length, greaterThanOrEqualTo(20));
    final groups = decks.map((item) => (item as Map)['group']).toSet();
    expect(groups, contains('Constitución Española'));
    expect(groups, contains('Ley 39/2015 · Procedimiento'));
    expect(groups, contains('Ley 40/2015 · Sector público'));
    expect(groups, contains('TREBEP'));
    final sample = Map<String, dynamic>.from(decks.first as Map);
    expect(sample['facts'], isNotEmpty);
    expect((sample['facts'] as List).first['prompt'], isNotEmpty);
  });

  test('siembra mazos de OpoTest sin duplicar al repetir', () async {
    final database = await AppDatabase.openInMemory();
    addTearDown(database.close);
    final repo = MemoRepository(database, clock: () => DateTime(2026, 9, 5));
    const json = '''
{"decks":[{"id":"opotest.5.19","name":"Título Preliminar","description":"Título Preliminar","group":"Constitución Española","domain":"leyes","facts":[{"id":"opotest.q.1","prompt":"Forma política del Estado","answer":"Monarquía parlamentaria","source":"CE art. 1"}]}]}
''';
    await ContentSeed.ensure(repo, jsonText: json);
    await ContentSeed.ensure(repo, jsonText: json);
    final summaries = await repo.summaries();
    expect(summaries.where((item) => item.deck.id == 'opotest.5.19'), hasLength(1));
    expect(summaries.firstWhere((item) => item.deck.id == 'opotest.5.19').factCount, 1);
    expect(summaries.any((item) => item.deck.groupName == 'Informática'), isTrue);
    final plazos = summaries.firstWhere((item) => item.deck.id == LpacapPlazosSeed.deckId);
    expect(plazos.factCount, greaterThanOrEqualTo(30));
    expect(plazos.deck.groupName, 'Ley 39/2015 · Procedimiento');
    final organos = summaries.firstWhere((item) => item.deck.id == CeOrganosSeed.deckId);
    expect(organos.factCount, greaterThanOrEqualTo(30));
    expect(organos.deck.groupName, 'Constitución Española');
  });
}
