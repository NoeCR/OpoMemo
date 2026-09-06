import 'package:flutter_test/flutter_test.dart';
import 'package:opomemo/domain/match_round.dart';
import 'package:opomemo/models/fact.dart';
import 'package:opomemo/models/review.dart';

void main() {
  Fact item(String id, String prompt, String answer) {
    final now = DateTime(2026, 9, 6);
    return Fact(
      id: id,
      deckId: 'd',
      prompt: prompt,
      answer: answer,
      source: '',
      kind: FactKind.termino,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('toque-toque acierta el par y lo califica Sí si no hubo fallo', () {
    final a = item('a', 'HTTPS', '443');
    final b = item('b', 'SSH', '22');
    final round = MatchRound([a, b]);
    expect(round.tap('a', true), MatchTapResult.selected);
    expect(round.tap('a', false), MatchTapResult.matched);
    expect(round.matched, {'a'});
    expect(round.gradeFor('a'), ReviewGrade.yes);
    expect(round.done, isFalse);
  });

  test('un fallo cuenta sobre el primer toque: Casi; el segundo, No', () {
    final a = item('a', 'HTTPS', '443');
    final b = item('b', 'SSH', '22');
    final round = MatchRound([a, b]);
    round.tap('a', true);
    expect(round.tap('b', false), MatchTapResult.missed);
    expect(round.selectedId, isNull);
    expect(round.gradeFor('a'), ReviewGrade.almost);
    round.tap('a', true);
    expect(round.tap('b', false), MatchTapResult.missed);
    expect(round.gradeFor('a'), ReviewGrade.no);
  });

  test('mismo lado cambia la selección; el mismo toque la cancela', () {
    final a = item('a', 'HTTPS', '443');
    final b = item('b', 'SSH', '22');
    final round = MatchRound([a, b]);
    expect(round.tap('a', true), MatchTapResult.selected);
    expect(round.tap('b', true), MatchTapResult.switched);
    expect(round.selectedId, 'b');
    expect(round.tap('b', true), MatchTapResult.cleared);
    expect(round.selectedId, isNull);
  });

  test('cada acierto guarda un índice de par distinto', () {
    final a = item('a', 'HTTPS', '443');
    final b = item('b', 'SSH', '22');
    final round = MatchRound([a, b]);
    round.tap('a', true);
    round.tap('a', false);
    round.tap('b', true);
    round.tap('b', false);
    expect(round.pairIndex['a'], 0);
    expect(round.pairIndex['b'], 1);
    round.unmatch('a');
    expect(round.pairIndex.containsKey('a'), isFalse);
    expect(round.pairIndex['b'], 1);
  });

  test('el tablero pide 4 pares y completa con la reserva', () {
    final remaining = [item('a', 'HTTPS', '443'), item('b', 'SSH', '22')];
    final reserve = [
      item('c', 'DNS', '53'),
      item('d', 'SMTP', '25'),
      item('e', 'FTP', '21'),
    ];
    final board = MatchRound.pickBoard(remaining: remaining, reserve: reserve);
    expect(board, hasLength(4));
    expect(board!.map((fact) => fact.id).toSet(), {'a', 'b', 'c', 'd'});
    expect(
      MatchRound.pickBoard(remaining: [item('a', 'HTTPS', '443')], reserve: const []),
      isNull,
    );
    expect(
      MatchRound.pickBoard(
        remaining: const [],
        reserve: [item('c', 'DNS', '53'), item('d', 'SMTP', '25'), item('e', 'FTP', '21'), item('f', 'SSH', '22')],
      ),
      isNull,
    );
  });
}
