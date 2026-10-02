class User {
  final String? id;
  // Set only when restoring a snapshot-verified owner from secure storage.
  final String? offlineStaffId;
  final String? name;
  final String? email;

  User({this.id, this.name, this.email, this.offlineStaffId});

  factory User.fromMap(Map m) => User(
    id: m['id']?.toString(),
    name: m['name'] as String?,
    email: m['email'] as String?,
  );
}
