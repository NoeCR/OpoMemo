import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/deck.dart';
import '../models/fact.dart';
import 'ce_organos_seed.dart';
import 'lpacap_plazos_seed.dart';
import 'memo_repository.dart';
import 'pilot_seed.dart';

abstract final class ContentSeed {
  static const assetPath = 'assets/seed/opotest_decks.json';

  static Future<void> ensure(MemoRepository repo, {String? jsonText}) async {
    await PilotSeed.ensure(repo);
    await LpacapPlazosSeed.ensure(repo);
    await CeOrganosSeed.ensure(repo);
    final raw = jsonText ?? await rootBundle.loadString(assetPath);
    final payload = jsonDecode(raw) as Map<String, dynamic>;
    final decks = payload['decks'] as List<dynamic>? ?? const [];
    for (final item in decks) {
      final map = Map<String, dynamic>.from(item as Map);
      final facts = (map['facts'] as List<dynamic>? ?? const []).map((rawFact) {
        final fact = Map<String, dynamic>.from(rawFact as Map);
        return SeedFact(
          id: fact['id'] as String,
          prompt: fact['prompt'] as String,
          answer: fact['answer'] as String,
          source: fact['source'] as String? ?? '',
          kind: FactKind.fromStorage(fact['kind'] as String? ?? 'pregunta'),
          clozeText: fact['cloze'] as String? ?? '',
        );
      }).toList();
      await repo.seedDeck(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String? ?? '',
        domain: DeckDomain.fromStorage(map['domain'] as String? ?? 'leyes'),
        groupName: map['group'] as String? ?? 'OpoTest',
        facts: facts,
      );
    }
  }
}
