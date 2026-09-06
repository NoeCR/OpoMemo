import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opomemo/widgets/flip_card.dart';

void main() {
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
}
