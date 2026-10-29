import '../../../core/errors/app_failure.dart';

class UserProfile {
  UserProfile({
    required this.uid,
    required this.email,
    required this.createdAt,
    required this.lastLoginAt,
    this.displayName,
    this.photoUrl,
    String? contactEmail,
    this.phone = '',
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
    this.contactEmail = contactEmail ?? email;
    if (this.contactEmail.trim().isEmpty ||
        !this.contactEmail.contains('@') ||
        this.contactEmail.length > 254 ||
        phone.length > 40) {
      throw const AppFailure(
        FailureKind.invalidData,
        'Your contact details are invalid. Please review your profile.',
      );
    }
    if (photoUrl != null && !_validPhoto(photoUrl!)) {
      throw const AppFailure(
        FailureKind.invalidData,
        'Your account profile contains an invalid photo address. Please contact support.',
      );
    }
  }

  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  late final String contactEmail;
  final String phone;
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

class ProfileDraft {
  const ProfileDraft({
    required this.displayName,
    required this.contactEmail,
    required this.phone,
    required this.photoUrl,
  });

  final String displayName;
  final String contactEmail;
  final String phone;
  final String? photoUrl;

  void validate() {
    if (displayName.trim().isEmpty || displayName.trim().length > 120) {
      throw const AppFailure(
        FailureKind.invalidData,
        'Enter a name of 1–120 characters.',
      );
    }
    final email = contactEmail.trim();
    if (email.isEmpty || email.length > 254 || !email.contains('@')) {
      throw const AppFailure(
        FailureKind.invalidData,
        'Enter a valid contact email address.',
      );
    }
    if (phone.trim().length > 40) {
      throw const AppFailure(
        FailureKind.invalidData,
        'Phone number must be at most 40 characters.',
      );
    }
    if (photoUrl != null && photoUrl!.trim().isNotEmpty) {
      if (!_validPhoto(photoUrl!.trim())) {
        throw const AppFailure(
          FailureKind.invalidData,
          'Use a valid HTTPS image address, or clear the photo field.',
        );
      }
    }
  }
}

bool _validPhoto(String value) {
  if (value.startsWith('/') &&
      value.contains('/profile-images/') &&
      !value.contains('/../')) {
    return true;
  }
  final uri = Uri.tryParse(value);
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
}
