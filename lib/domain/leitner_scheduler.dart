import '../models/review.dart';

/// Leitner de 5 cajas: 1 / 3 / 7 / 16 / 30 días.
///
/// No resetea a caja 1. Casi mantiene la caja y vuelve mañana.
/// Sí avanza de caja (la primera vez entra en caja 1).
abstract final class LeitnerScheduler {
  static const boxCount = 5;
  static const intervalDays = [1, 3, 7, 16, 30];

  static DateTime calendarDay(DateTime at) => DateTime(at.year, at.month, at.day);

  static DateTime dueAfterBox(int box, DateTime now) {
    final clamped = box.clamp(1, boxCount);
    return calendarDay(now).add(Duration(days: intervalDays[clamped - 1]));
  }

  static bool isDue(ReviewState? state, DateTime now) {
    if (state == null) return true;
    return !calendarDay(state.nextDue).isAfter(calendarDay(now));
  }

  static ReviewState apply({
    required String factId,
    required ReviewState? current,
    required ReviewGrade grade,
    required DateTime now,
  }) {
    final count = (current?.reviewCount ?? 0) + 1;
    switch (grade) {
      case ReviewGrade.no:
        return ReviewState(
          factId: factId,
          box: 1,
          nextDue: dueAfterBox(1, now),
          lastGrade: grade,
          reviewCount: count,
          updatedAt: now,
        );
      case ReviewGrade.almost:
        final box = (current?.box ?? 1).clamp(1, boxCount);
        return ReviewState(
          factId: factId,
          box: box,
          nextDue: calendarDay(now).add(const Duration(days: 1)),
          lastGrade: grade,
          reviewCount: count,
          updatedAt: now,
        );
      case ReviewGrade.yes:
        final nextBox = current == null
            ? 1
            : (current.box >= boxCount ? boxCount : current.box + 1);
        return ReviewState(
          factId: factId,
          box: nextBox,
          nextDue: dueAfterBox(nextBox, now),
          lastGrade: grade,
          reviewCount: count,
          updatedAt: now,
        );
    }
  }
}
