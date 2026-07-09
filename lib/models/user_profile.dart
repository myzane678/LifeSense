class UserProfile {
  const UserProfile({
    required this.userID,
    required this.nickname,
    required this.avatarPath,
    required this.updatedAt,
  });

  final String userID;
  final String nickname;
  final String avatarPath;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'userID': userID,
      'nickname': nickname,
      'avatarPath': avatarPath,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userID: json['userID'] as String,
      nickname: json['nickname'] as String? ?? '',
      avatarPath: json['avatarPath'] as String? ?? '',
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
