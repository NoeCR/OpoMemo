import '../models/fact.dart';

class ParsedSeedDeck {
  const ParsedSeedDeck({
    required this.id,
    required this.name,
    required this.description,
    required this.groupName,
    required this.facts,
  });

  final String id;
  final String name;
  final String description;
  final String groupName;
  final List<SeedFact> facts;
}

/// Convierte markdown Pregunta → Respuesta → *truco* en mazos semilla.
///
/// Cada `##` es un mazo. Se ignoran tablas y el apartado «Cuadro resumen».
abstract final class MarkdownCardParser {
  static final _prompt = RegExp(r'^\*\*(.+)\*\*\s*$');
  static final _article = RegExp(r'\((arts?\.\s*[^)]+)\)', caseSensitive: false);

  static List<ParsedSeedDeck> parse(
    String markdown, {
    required String idPrefix,
    required String groupName,
    required String sourcePrefix,
  }) {
    final lines = markdown.replaceAll('\r\n', '\n').split('\n');
    final decks = <ParsedSeedDeck>[];
    String? heading;
    var skippingSummary = false;
    var sectionIndex = 0;
    final body = <String>[];

    void flush() {
      final title = heading;
      if (title == null || skippingSummary) {
        body.clear();
        return;
      }
      final nextIndex = sectionIndex + 1;
      final facts = _cardsFrom(
        body,
        idPrefix: idPrefix,
        sectionIndex: nextIndex,
        sourcePrefix: sourcePrefix,
      );
      body.clear();
      if (facts.isEmpty) return;
      sectionIndex = nextIndex;
      decks.add(
        ParsedSeedDeck(
          id: '$idPrefix.s${_pad(sectionIndex)}',
          name: title,
          description: title,
          groupName: groupName,
          facts: facts,
        ),
      );
    }

    for (final raw in lines) {
      final trimmed = raw.trim();
      if (trimmed.startsWith('## ')) {
        flush();
        heading = trimmed.substring(3).trim();
        skippingSummary = heading.toLowerCase().contains('cuadro resumen');
        continue;
      }
      if (heading == null || skippingSummary) continue;
      if (trimmed.startsWith('# ')) continue;
      body.add(trimmed);
    }
    flush();
    return decks;
  }

  static List<SeedFact> _cardsFrom(
    List<String> lines, {
    required String idPrefix,
    required int sectionIndex,
    required String sourcePrefix,
  }) {
    final facts = <SeedFact>[];
    String? prompt;
    final answer = StringBuffer();
    var explanation = '';
    var cardIndex = 0;

    void flushCard() {
      final text = answer.toString().trim();
      if (prompt == null || text.isEmpty) {
        prompt = null;
        answer.clear();
        explanation = '';
        return;
      }
      cardIndex += 1;
      facts.add(
        SeedFact(
          id: '$idPrefix.s${_pad(sectionIndex)}.c${_pad(cardIndex)}',
          prompt: prompt!,
          answer: text,
          source: _source(prompt!, sourcePrefix),
          explanation: explanation.trim(),
        ),
      );
      prompt = null;
      answer.clear();
      explanation = '';
    }

    for (final line in lines) {
      if (line.isEmpty || line == '---' || line.startsWith('|')) continue;
      final promptMatch = _prompt.firstMatch(line);
      if (promptMatch != null) {
        flushCard();
        prompt = promptMatch.group(1)!.trim();
        continue;
      }
      if (prompt == null) continue;
      if (_isTrick(line)) {
        explanation = line.substring(1, line.length - 1).trim();
        continue;
      }
      if (answer.isNotEmpty) answer.writeln();
      answer.write(line);
    }
    flushCard();
    return facts;
  }

  static bool _isTrick(String line) {
    return line.startsWith('*') && line.endsWith('*') && !line.startsWith('**');
  }

  static String _source(String prompt, String sourcePrefix) {
    final matches = _article.allMatches(prompt);
    if (matches.isEmpty) return sourcePrefix;
    return '$sourcePrefix ${matches.last.group(1)!.trim()}';
  }

  static String _pad(int value) => value.toString().padLeft(2, '0');
}
