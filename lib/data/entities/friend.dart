/// A person the user can split bills with. Deliberately minimal for now
/// — just enough to reference someone by name when assigning items or
/// building a group. Fields like email/phone/avatar can be added later
/// without touching anything that depends on this class, since they'd
/// be purely additive.
class Friend {
  final String id;
  final String name;
  final DateTime createdAt;

  Friend({required this.id, required this.name, DateTime? createdAt})
    : createdAt = createdAt ?? DateTime.now();

  Map<String, Object?> toMap() {
    return {'id': id, 'name': name, 'createdAt': createdAt.toIso8601String()};
  }

  factory Friend.fromMap(Map<String, Object?> map) {
    return Friend(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
