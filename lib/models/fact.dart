import 'dart:convert';

enum FactKind {
  termino,
  pregunta,
  hueco;

  String get label => switch (this) {
        FactKind.termino => 'Término',
        FactKind.pregunta => 'Pregunta',
        FactKind.hueco => 'Hueco',
      };

  static FactKind fromStorage(String value) {
    return FactKind.values.firstWhere(
      (item) => item.name == value,
      orElse: () => FactKind.pregunta,
    );
  }
}

class Fact {
  const Fact({
    required this.id,
    required this.deckId,
    required this.prompt,
    required this.answer,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
    this.kind = FactKind.pregunta,
    this.clozeText = '',
    this.distractors = const [],
    this.flagged = false,
  });

  final String id;
  final String deckId;
  final String prompt;
  final String answer;
  final String source;
  final FactKind kind;
  final String clozeText;
  final List<String> distractors;
  final bool flagged;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return prompt.toLowerCase().contains(needle) ||
        answer.toLowerCase().contains(needle) ||
        source.toLowerCase().contains(needle) ||
        clozeText.toLowerCase().contains(needle);
  }

  Fact copyWith({
    String? prompt,
    String? answer,
    String? source,
    FactKind? kind,
    String? clozeText,
    List<String>? distractors,
    bool? flagged,
    DateTime? updatedAt,
  }) {
    return Fact(
      id: id,
      deckId: deckId,
      prompt: prompt ?? this.prompt,
      answer: answer ?? this.answer,
      source: source ?? this.source,
      kind: kind ?? this.kind,
      clozeText: clozeText ?? this.clozeText,
      distractors: distractors ?? this.distractors,
      flagged: flagged ?? this.flagged,
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
        'kind': kind.name,
        'cloze_text': clozeText,
        'distractors': jsonEncode(distractors),
        'flagged': flagged ? 1 : 0,
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
      kind: FactKind.fromStorage(map['kind'] as String? ?? 'pregunta'),
      clozeText: map['cloze_text'] as String? ?? '',
      distractors: _readDistractors(map['distractors']),
      flagged: (map['flagged'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at']! as String),
      updatedAt: DateTime.parse(map['updated_at']! as String),
    );
  }

  static List<String> _readDistractors(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item.toString().trim().isNotEmpty) item.toString().trim(),
      ];
    } catch (_) {
      return const [];
    }
  }
}

class SeedFact {
  const SeedFact({
    required this.id,
    required this.prompt,
    required this.answer,
    this.source = '',
    this.kind = FactKind.pregunta,
    this.clozeText = '',
    this.distractors = const [],
  });

  final String id;
  final String prompt;
  final String answer;
  final String source;
  final FactKind kind;
  final String clozeText;
  final List<String> distractors;
}
