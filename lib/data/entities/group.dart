/// A named collection of friends, for splitting recurring shared
/// expenses (roommates, a trip, etc.) without re-selecting the same
/// people every time.
///
/// [memberIds] references Friend.id rather than embedding full Friend
/// objects — this is a many-to-many relationship (a friend can belong
/// to multiple groups, a group has multiple friends), which is why it's
/// backed by a join table (group_members) at the schema level rather
/// than a column on either side.
class Group {
  final String id;
  final String name;
  final List<String> memberIds;
  final DateTime createdAt;

  Group({
    required this.id,
    required this.name,
    required this.memberIds,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, Object?> toMap() {
    return {'id': id, 'name': name, 'createdAt': createdAt.toIso8601String()};
  }

  /// [memberIds] is supplied separately, same reasoning as
  /// Receipt.fromMap's items — it comes from a separate join-table
  /// query, so this class doesn't need to know how to fetch it.
  factory Group.fromMap(
    Map<String, Object?> map, {
    required List<String> memberIds,
  }) {
    return Group(
      id: map['id'] as String,
      name: map['name'] as String,
      memberIds: memberIds,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
