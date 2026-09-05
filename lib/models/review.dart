enum ReviewGrade {
  no,
  almost,
  yes;

  String get label => switch (this) {
        ReviewGrade.no => 'No',
        ReviewGrade.almost => 'Casi',
        ReviewGrade.yes => 'Sí',
      };
}

class ReviewState {
  const ReviewState({
    required this.factId,
    required this.box,
    required this.nextDue,
    required this.lastGrade,
    required this.reviewCount,
    required this.updatedAt,
  });

  final String factId;
  final int box;
  final DateTime nextDue;
  final ReviewGrade? lastGrade;
  final int reviewCount;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
        'fact_id': factId,
        'box': box,
        'next_due': nextDue.toIso8601String(),
        'last_grade': lastGrade?.name,
        'review_count': reviewCount,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory ReviewState.fromMap(Map<String, Object?> map) {
    final grade = map['last_grade'] as String?;
    return ReviewState(
      factId: map['fact_id']! as String,
      box: map['box']! as int,
      nextDue: DateTime.parse(map['next_due']! as String),
      lastGrade: grade == null
          ? null
          : ReviewGrade.values.firstWhere(
              (item) => item.name == grade,
              orElse: () => ReviewGrade.no,
            ),
      reviewCount: map['review_count'] as int? ?? 0,
      updatedAt: DateTime.parse(map['updated_at']! as String),
    );
  }
}
