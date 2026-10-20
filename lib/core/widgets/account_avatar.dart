import 'package:flutter/material.dart';

import '../../features/profile/domain/user_profile.dart';

class AccountAvatar extends StatelessWidget {
  const AccountAvatar({super.key, required this.profile, this.radius = 22});
  final UserProfile profile;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final imagePixels = (radius * 2 * MediaQuery.devicePixelRatioOf(context))
        .ceil();
    final fallback = Center(
      child: Text(
        profile.initials,
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontSize: radius * .65,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return Semantics(
      label: 'Profile picture for ${profile.label}',
      image: true,
      child: ClipOval(
        child: ColoredBox(
          color: scheme.primaryContainer,
          child: SizedBox.square(
            dimension: radius * 2,
            child: profile.photoUrl == null
                ? fallback
                : Image.network(
                    profile.photoUrl!,
                    fit: BoxFit.cover,
                    cacheWidth: imagePixels,
                    cacheHeight: imagePixels,
                    loadingBuilder: (context, child, progress) =>
                        progress == null ? child : fallback,
                    errorBuilder: (context, error, stack) => fallback,
                  ),
          ),
        ),
      ),
    );
  }
}
