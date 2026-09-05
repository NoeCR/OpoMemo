class Fact {
  const Fact({
    required this.id,
    required this.deckId,
    required this.prompt,
    required this.answer,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String deckId;
  final String prompt;
  final String answer;
  final String source;
  final DateTime createdAt;
  final DateTime updatedAt;

  Fact copyWith({
    String? prompt,
    String? answer,
    String? source,
    DateTime? updatedAt,
  }) {
    return Fact(
      id: id,
      deckId: deckId,
      prompt: prompt ?? this.prompt,
      answer: answer ?? this.answer,
      source: source ?? this.source,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'deck_id': deckId,
        'prompt': prompt,
        'answer': answer,
        'source': source,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Fact.fromMap(Map<String, Object?> map) {
    return Fact(
      id: map['id']! as String,
      deckId: map['deck_id']! as String,
      prompt: map['prompt']! as String,
      answer: map['answer']! as String,
      source: map['source'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at']! as String),
      updatedAt: DateTime.parse(map['updated_at']! as String),
    );
  }
}
