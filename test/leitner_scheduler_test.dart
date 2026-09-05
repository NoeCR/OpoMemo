import 'package:flutter_test/flutter_test.dart';
import 'package:opomemo/domain/leitner_scheduler.dart';
import 'package:opomemo/models/review.dart';

void main() {
  final now = DateTime(2026, 9, 5, 16, 20);

  test('una carta nueva está pendiente', () {
    expect(LeitnerScheduler.isDue(null, now), isTrue);
  });

  test('Sí en una carta nueva entra en caja 1 y vuelve mañana', () {
    final next = LeitnerScheduler.apply(
      factId: 'a',
      current: null,
      grade: ReviewGrade.yes,
      now: now,
    );
    expect(next.box, 1);
    expect(next.nextDue, DateTime(2026, 9, 6));
    expect(LeitnerScheduler.isDue(next, now), isFalse);
    expect(LeitnerScheduler.isDue(next, DateTime(2026, 9, 6)), isTrue);
  });

  test('No resetea a caja 1 y programa el día siguiente', () {
    final current = LeitnerScheduler.apply(
      factId: 'a',
      current: null,
      grade: ReviewGrade.yes,
      now: DateTime(2026, 8, 1),
    );
    final advanced = LeitnerScheduler.apply(
      factId: 'a',
      current: current,
      grade: ReviewGrade.yes,
      now: DateTime(2026, 8, 2),
    );
    expect(advanced.box, 2);

    final failed = LeitnerScheduler.apply(
      factId: 'a',
      current: advanced,
      grade: ReviewGrade.no,
      now: now,
    );
    expect(failed.box, 1);
    expect(failed.nextDue, DateTime(2026, 9, 6));
  });

  test('Casi mantiene la caja y vuelve mañana', () {
    var state = LeitnerScheduler.apply(
      factId: 'a',
      current: null,
      grade: ReviewGrade.yes,
      now: DateTime(2026, 8, 1),
    );
    state = LeitnerScheduler.apply(
      factId: 'a',
      current: state,
      grade: ReviewGrade.yes,
      now: DateTime(2026, 8, 2),
    );
    expect(state.box, 2);

    final almost = LeitnerScheduler.apply(
      factId: 'a',
      current: state,
      grade: ReviewGrade.almost,
      now: now,
    );
    expect(almost.box, 2);
    expect(almost.nextDue, DateTime(2026, 9, 6));
  });
}
