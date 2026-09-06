import 'package:flutter/services.dart';

import '../models/deck.dart';
import 'markdown_card_parser.dart';
import 'memo_repository.dart';

class MarkdownSeedCatalog {
  const MarkdownSeedCatalog({
    required this.assetPath,
    required this.idPrefix,
    required this.groupName,
    required this.sourcePrefix,
  });

  final String assetPath;
  final String idPrefix;
  final String groupName;
  final String sourcePrefix;
}

/// Catálogo semilla activo. El resto (OpoTest, plazos, órganos, Redes) está
/// archivado en `assets/seed/archive` y en los Dart de `lib/data/*_seed.dart`.
abstract final class ContentSeed {
  static const catalog = [
    MarkdownSeedCatalog(
      assetPath: 'assets/seed/active/Tarjetas_Ley_19_2013.md',
      idPrefix: 'md.ley19',
      groupName: 'Ley 19/2013 · Transparencia',
      sourcePrefix: 'LTAIBG',
    ),
    MarkdownSeedCatalog(
      assetPath: 'assets/seed/active/Tarjetas_TREBEP_RDL_5_2015.md',
      idPrefix: 'md.trebep',
      groupName: 'TREBEP · RDL 5/2015',
      sourcePrefix: 'TREBEP',
    ),
    MarkdownSeedCatalog(
      assetPath: 'assets/seed/active/Tarjetas_Ley_30_1984.md',
      idPrefix: 'md.ley30',
      groupName: 'Ley 30/1984 · Reforma de la Función Pública',
      sourcePrefix: 'Ley 30/1984',
    ),
    MarkdownSeedCatalog(
      assetPath: 'assets/seed/active/Tarjetas_Ley_53_1984.md',
      idPrefix: 'md.ley53',
      groupName: 'Ley 53/1984 · Incompatibilidades',
      sourcePrefix: 'Ley 53/1984',
    ),
  ];

  static Future<void> ensure(
    MemoRepository repo, {
    Map<String, String>? markdownByPrefix,
  }) async {
    final keepIds = <String>{};
    for (final item in catalog) {
      final markdown = markdownByPrefix?[item.idPrefix] ?? await rootBundle.loadString(item.assetPath);
      final decks = MarkdownCardParser.parse(
        markdown,
        idPrefix: item.idPrefix,
        groupName: item.groupName,
        sourcePrefix: item.sourcePrefix,
      );
      for (final deck in decks) {
        keepIds.add(deck.id);
        await repo.seedDeck(
          id: deck.id,
          name: deck.name,
          description: deck.description,
          domain: DeckDomain.leyes,
          groupName: deck.groupName,
          facts: deck.facts,
        );
      }
    }
    await repo.deleteSeedDecksNotIn(keepIds);
  }
}
