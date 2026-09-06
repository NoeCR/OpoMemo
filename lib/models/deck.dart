enum DeckDomain {
  leyes,
  info,
  mixed;

  String get label => switch (this) {
        DeckDomain.leyes => 'Leyes',
        DeckDomain.info => 'Informática',
        DeckDomain.mixed => 'Mixto',
      };

  static DeckDomain fromStorage(String value) {
    return DeckDomain.values.firstWhere(
      (item) => item.name == value,
      orElse: () => DeckDomain.mixed,
    );
  }
}

class Deck {
  static const defaultGroup = 'Mis mazos';

  const Deck({
    required this.id,
    required this.name,
    required this.description,
    required this.domain,
    required this.groupName,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final DeckDomain domain;
  final String groupName;
  final String source;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isSeed => source == 'seed';

  Deck copyWith({
    String? name,
    String? description,
    DeckDomain? domain,
    String? groupName,
    String? source,
    DateTime? updatedAt,
  }) {
    return Deck(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      domain: domain ?? this.domain,
      groupName: groupName ?? this.groupName,
      source: source ?? this.source,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'domain': domain.name,
        'group_name': groupName,
        'source': source,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Deck.fromMap(Map<String, Object?> map) {
    return Deck(
      id: map['id']! as String,
      name: map['name']! as String,
      description: map['description'] as String? ?? '',
      domain: DeckDomain.fromStorage(map['domain'] as String? ?? 'mixed'),
      groupName: map['group_name'] as String? ?? '',
      source: map['source'] as String? ?? 'user',
      createdAt: DateTime.parse(map['created_at']! as String),
      updatedAt: DateTime.parse(map['updated_at']! as String),
    );
  }
}

class DeckSummary {
  const DeckSummary({
    required this.deck,
    required this.factCount,
    required this.dueCount,
    this.newCount = 0,
    this.boxCounts = const [0, 0, 0, 0, 0],
    this.flaggedCount = 0,
  });

  final Deck deck;
  final int factCount;
  final int dueCount;
  final int newCount;
  final List<int> boxCounts;
  final int flaggedCount;

  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return deck.name.toLowerCase().contains(needle) ||
        deck.description.toLowerCase().contains(needle) ||
        deck.groupName.toLowerCase().contains(needle);
  }
}

class DeckGroup {
  const DeckGroup({required this.name, required this.decks});

  final String name;
  final List<DeckSummary> decks;

  int get dueCount => decks.fold(0, (sum, item) => sum + item.dueCount);
  int get factCount => decks.fold(0, (sum, item) => sum + item.factCount);

  String get chipLabel => switch (name) {
        'Ley 19/2013 · Transparencia' => 'LTAIBG',
        'TREBEP · RDL 5/2015' => 'TREBEP',
        'Ley 30/1984 · Reforma de la Función Pública' => '30/1984',
        'Ley 53/1984 · Incompatibilidades' => '53/1984',
        Deck.defaultGroup => 'Míos',
        _ => name.split(' · ').first.replaceFirst(RegExp(r'^Ley\s+'), ''),
      };
}
