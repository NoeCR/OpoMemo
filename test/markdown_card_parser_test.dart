import 'package:flutter_test/flutter_test.dart';
import 'package:opomemo/data/markdown_card_parser.dart';

void main() {
  test('un ## es un mazo; el truco va a explanation; el cuadro no se importa', () {
    const markdown = '''
# Tarjetas de prueba

Formato: Pregunta → Respuesta → Truco

## TÍTULO PRELIMINAR

**¿Cuántos títulos tiene la ley (art. 1)?**
Preliminar, I, II y III.
*El esqueleto: Preliminar → I → II → III.*

---

**¿Quién publica planes?**
Solo las Administraciones Públicas.

## Cuadro resumen de plazos y cifras clave (repaso rápido)

| Dato | Cifra |
|---|---|
| Umbral | 100.000 € |

## TÍTULO II. Buen gobierno

**¿A quién se aplica el Título II (art. 25)?**
Altos cargos de la AGE, CCAA y EELL.
''';

    final decks = MarkdownCardParser.parse(
      markdown,
      idPrefix: 'md.ley19',
      groupName: 'Ley 19/2013 · Transparencia',
      sourcePrefix: 'LTAIBG',
    );

    expect(decks, hasLength(2));
    expect(decks[0].id, 'md.ley19.s01');
    expect(decks[0].name, 'TÍTULO PRELIMINAR');
    expect(decks[0].facts, hasLength(2));
    expect(decks[0].facts[0].prompt, '¿Cuántos títulos tiene la ley (art. 1)?');
    expect(decks[0].facts[0].answer, 'Preliminar, I, II y III.');
    expect(decks[0].facts[0].explanation, 'El esqueleto: Preliminar → I → II → III.');
    expect(decks[0].facts[0].source, 'LTAIBG art. 1');
    expect(decks[0].facts[1].explanation, isEmpty);
    expect(decks[1].id, 'md.ley19.s02');
    expect(decks[1].facts, hasLength(1));
    expect(decks[1].facts.single.source, 'LTAIBG art. 25');
    expect(
      decks.expand((deck) => deck.facts).any((fact) => fact.answer.contains('100.000')),
      isFalse,
    );
  });
}
