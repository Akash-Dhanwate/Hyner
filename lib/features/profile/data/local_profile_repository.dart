import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/domain/auth_repository.dart';
import '../domain/profile_repository.dart';
import '../domain/user_profile.dart';

class LocalProfileRepository implements ProfileRepository {
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  String _key(String uid, String field) => 'hyner.profile.$uid.$field';

  @override
  Future<UserProfile> synchronize(AccountIdentity identity) async {
    final key = 'hyner.profile.created.${identity.uid}';
    final savedCreatedAt = await _preferences.getString(key);
    final createdAt = savedCreatedAt == null
        ? DateTime.now().toUtc()
        : DateTime.tryParse(savedCreatedAt)?.toUtc() ?? DateTime.now().toUtc();
    await _preferences.setString(key, createdAt.toIso8601String());
    final displayName = await _preferences.getString(
      _key(identity.uid, 'displayName'),
    );
    final contactEmail = await _preferences.getString(
      _key(identity.uid, 'contactEmail'),
    );
    final phone = await _preferences.getString(_key(identity.uid, 'phone'));
    final photoUrl = await _preferences.getString(
      _key(identity.uid, 'photoUrl'),
    );
    return UserProfile(
      uid: identity.uid,
      email: identity.email,
      displayName: displayName ?? identity.displayName,
      photoUrl: photoUrl == null
          ? identity.photoUrl
          : photoUrl.isEmpty
          ? null
          : photoUrl,
      contactEmail: contactEmail ?? identity.email,
      phone: phone ?? '',
      createdAt: createdAt,
      lastLoginAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<UserProfile> update(UserProfile current, ProfileDraft draft) async {
    draft.validate();
    final photoUrl = draft.photoUrl?.trim() ?? '';
    await Future.wait([
      _preferences.setString(
        _key(current.uid, 'displayName'),
        draft.displayName.trim(),
      ),
      _preferences.setString(
        _key(current.uid, 'contactEmail'),
        draft.contactEmail.trim(),
      ),
      _preferences.setString(_key(current.uid, 'phone'), draft.phone.trim()),
      _preferences.setString(_key(current.uid, 'photoUrl'), photoUrl),
    ]);
    return UserProfile(
      uid: current.uid,
      email: current.email,
      displayName: draft.displayName.trim(),
      photoUrl: photoUrl.isEmpty ? null : photoUrl,
      contactEmail: draft.contactEmail.trim(),
      phone: draft.phone.trim(),
      createdAt: current.createdAt,
      lastLoginAt: current.lastLoginAt,
    );
  }
}
