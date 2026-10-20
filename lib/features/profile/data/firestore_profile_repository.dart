import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/app_failure.dart';
import '../../auth/domain/auth_repository.dart';
import '../domain/profile_repository.dart';
import '../domain/user_profile.dart';

class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository(this._firestore);
  final FirebaseFirestore _firestore;

  @override
  Future<UserProfile> synchronize(AccountIdentity identity) async {
    try {
      final reference = _firestore.collection('users').doc(identity.uid);
      await _firestore
          .runTransaction((transaction) async {
            final existing = await transaction.get(reference);
            if (existing.exists) {
              _decode(identity.uid, existing.data());
              transaction.update(reference, {
                'displayName': identity.displayName,
                'email': identity.email,
                'photoUrl': identity.photoUrl,
                'lastLoginAt': FieldValue.serverTimestamp(),
              });
            } else {
              transaction.set(reference, {
                'uid': identity.uid,
                'displayName': identity.displayName,
                'email': identity.email,
                'photoUrl': identity.photoUrl,
                'createdAt': FieldValue.serverTimestamp(),
                'lastLoginAt': FieldValue.serverTimestamp(),
              });
            }
          })
          .timeout(const Duration(seconds: 25));
      final result = await reference
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 20));
      return _decode(identity.uid, result.data());
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  UserProfile _decode(String uid, Map<String, dynamic>? data) {
    const expected = {
      'uid',
      'displayName',
      'email',
      'photoUrl',
      'createdAt',
      'lastLoginAt',
    };
    if (data == null ||
        data.length != expected.length ||
        !data.keys.toSet().containsAll(expected) ||
        data['uid'] != uid ||
        data['email'] is! String ||
        (data['displayName'] != null && data['displayName'] is! String) ||
        (data['photoUrl'] != null && data['photoUrl'] is! String) ||
        data['createdAt'] is! Timestamp ||
        data['lastLoginAt'] is! Timestamp) {
      throw const AppFailure(
        FailureKind.invalidData,
        'Your saved account profile could not be read safely. Please contact support.',
      );
    }
    return UserProfile(
      uid: uid,
      email: data['email'] as String,
      displayName: data['displayName'] as String?,
      photoUrl: data['photoUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp).toDate(),
    );
  }
}

class UnconfiguredProfileRepository implements ProfileRepository {
  @override
  Future<UserProfile> synchronize(AccountIdentity identity) async =>
      throw const AppFailure(
        FailureKind.configuration,
        'Account services are not connected.',
      );
}
