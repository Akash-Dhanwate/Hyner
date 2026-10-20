import '../../auth/domain/auth_repository.dart';
import 'user_profile.dart';

abstract interface class ProfileRepository {
  Future<UserProfile> synchronize(AccountIdentity identity);
}
