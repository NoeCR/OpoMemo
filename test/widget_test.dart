import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opomemo/models/deck.dart';
import 'package:opomemo/theme/app_theme.dart';
import 'package:opomemo/widgets/flip_card.dart';

void main() {
  test('los chips del hub acortan los grupos semilla', () {
    expect(const DeckGroup(name: 'Ley 19/2013 · Transparencia', decks: []).chipLabel, 'LTAIBG');
    expect(const DeckGroup(name: 'TREBEP · RDL 5/2015', decks: []).chipLabel, 'TREBEP');
    expect(const DeckGroup(name: 'Ley 30/1984 · Reforma de la Función Pública', decks: []).chipLabel, '30/1984');
    expect(const DeckGroup(name: 'Ley 53/1984 · Incompatibilidades', decks: []).chipLabel, '53/1984');
    expect(const DeckGroup(name: 'Ley 39/2015 · Procedimiento', decks: []).chipLabel, 'LPACAP');
    expect(const DeckGroup(name: 'Constitución Española', decks: []).chipLabel, 'CE');
  });

  testWidgets('al tocar la tarjeta muestra el dorso', (tester) async {
    var flipped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return FlipCard(
                flipped: flipped,
                onTap: () => setState(() => flipped = true),
                front: const MemoFace(
                  label: 'Pregunta',
                  text: 'Puerto HTTPS',
                  tint: Colors.teal,
                ),
                back: const MemoFace(
                  label: 'Respuesta',
                  text: '443',
                  explanation: 'Puerto por defecto de HTTPS.',
                  tint: Colors.indigo,
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Puerto HTTPS'), findsOneWidget);
    await tester.tap(find.text('Puerto HTTPS'));
    await tester.pumpAndSettle();
    expect(find.text('443'), findsOneWidget);
    expect(find.text('Aclaración'), findsOneWidget);
    expect(find.text('Puerto por defecto de HTTPS.'), findsOneWidget);
  });

  testWidgets('en tema oscuro el dorso sigue siendo legible', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: MemoFace(
            label: 'Respuesta',
            text: '443',
            explanation: 'Puerto por defecto de HTTPS.',
            tint: Colors.teal,
          ),
        ),
      ),
    );
    expect(find.text('443'), findsOneWidget);
    expect(find.text('Aclaración'), findsOneWidget);
  });
}
