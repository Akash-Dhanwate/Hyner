import '../../../core/errors/app_failure.dart';

class UserProfile {
  UserProfile({
    required this.uid,
    required this.email,
    required this.createdAt,
    required this.lastLoginAt,
    this.displayName,
    this.photoUrl,
  }) {
    if (uid.isEmpty ||
        email.isEmpty ||
        !email.contains('@') ||
        lastLoginAt.isBefore(createdAt)) {
      throw const AppFailure(
        FailureKind.invalidData,
        'Your account profile contains invalid information. Please contact support.',
      );
    }
    if (photoUrl != null) {
      final uri = Uri.tryParse(photoUrl!);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        throw const AppFailure(
          FailureKind.invalidData,
          'Your account profile contains an invalid photo address. Please contact support.',
        );
      }
    }
  }

  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime lastLoginAt;

  String get label => displayName?.trim().isNotEmpty == true
      ? displayName!.trim()
      : 'Your account';
  String get firstName => displayName?.trim().isNotEmpty == true
      ? displayName!.trim().split(RegExp(r'\s+')).first
      : 'there';
  String get initials {
    final words =
        (displayName?.trim().isNotEmpty == true ? displayName!.trim() : email)
            .split(RegExp(r'\s+'));
    return words
        .take(2)
        .map(
          (word) => word.isEmpty ? '' : String.fromCharCode(word.runes.first),
        )
        .join()
        .toUpperCase();
  }
}
