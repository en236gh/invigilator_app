class User {
	final String? id;
	final String? name;
	final String? email;

	User({this.id, this.name, this.email});

	factory User.fromMap(Map m) => User(
				id: m['id']?.toString(),
				name: m['name'] as String?,
				email: m['email'] as String?,
			);
}
