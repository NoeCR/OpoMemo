import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:opomemo/domain/cloze.dart';
import 'package:opomemo/domain/cloze_bank.dart';

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

  test('el banco incluye las respuestas y relleno de distractores', () {
    final chips = ClozeBank.chips(
      answers: const ['6 meses'],
      distractors: const ['3 meses', '1 mes'],
      extras: const ['10 días', '15 días'],
      random: Random(1),
    );
    expect(chips, contains('6 meses'));
    expect(chips, contains('3 meses'));
    expect(chips.length, greaterThanOrEqualTo(5));
    expect(chips.toSet().length, chips.length);
  });

  test('tocar una ficha llena el hueco y se puede devolver al banco', () {
    final pick = ClozePick(answers: const ['6 meses', '10 días'], bank: const ['6 meses', '3 meses', '10 días']);
    pick.tapBank(0);
    expect(pick.slots.first, isNotNull);
    expect(pick.complete, isFalse);
    pick.tapBank(0);
    expect(pick.complete, isTrue);
    expect(pick.hits().where((item) => item).length, greaterThan(0));
    pick.tapSlot(0);
    expect(pick.complete, isFalse);
    expect(pick.unused, hasLength(2));
  });
}
