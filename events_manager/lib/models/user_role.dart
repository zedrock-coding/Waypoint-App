enum UserRole {
  level1, // Admin / Senior
  level2, // User / Junior
}

class HelmUser {
  final String id;
  final String name;
  final UserRole role;
  final String? communityId;

  HelmUser({
    required this.id,
    required this.name,
    required this.role,
    this.communityId,
  });
}
