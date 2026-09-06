import 'package:flutter_test/flutter_test.dart';
import 'package:opomemo/domain/cloze.dart';

void main() {
  test('parsea varios huecos y deja el texto alrededor', () {
    final parts = Cloze.parse('El Congreso tiene {{300}} a {{400}} diputados.');
    expect(Cloze.hasBlanks('El Congreso tiene {{300}} a {{400}} diputados.'), isTrue);
    expect(Cloze.blanks('El Congreso tiene {{300}} a {{400}} diputados.'), ['300', '400']);
    expect(parts.where((part) => part.blank).map((part) => part.value), ['300', '400']);
    expect(parts.first.value, 'El Congreso tiene ');
  });

  test('compara el dato sin tildes ni mayúsculas', () {
    expect(Cloze.same('6 meses', '6 Meses'), isTrue);
    expect(Cloze.same('10 días', '10 dias'), isTrue);
    expect(Cloze.same('3 meses', '6 meses'), isFalse);
    expect(Cloze.same('mitad', ''), isFalse);
  });
}
