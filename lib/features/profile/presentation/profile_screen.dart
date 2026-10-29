import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/account_avatar.dart';
import '../../../core/widgets/page_content.dart';
import '../../auth/presentation/session_controller.dart';
import '../domain/user_profile.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const _mediaChannel = MethodChannel('hyner/media');
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _contactEmail = TextEditingController();
  final _phone = TextEditingController();
  final _photoUrl = TextEditingController();
  bool _editing = false;
  bool _saving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _loadFields(ref.read(sessionProvider).profile);
  }

  void _loadFields(UserProfile? profile) {
    _name.text = profile?.displayName ?? '';
    _contactEmail.text = profile?.contactEmail ?? '';
    _phone.text = profile?.phone ?? '';
    _photoUrl.text = profile?.photoUrl ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _contactEmail.dispose();
    _phone.dispose();
    _photoUrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ref
          .read(sessionProvider.notifier)
          .updateProfile(
            ProfileDraft(
              displayName: _name.text,
              contactEmail: _contactEmail.text,
              phone: _phone.text,
              photoUrl: _photoUrl.text.trim().isEmpty ? null : _photoUrl.text,
            ),
          );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _editing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failure = AppFailure.from(error);
      });
    }
  }

  Future<void> _pickPhoto() async {
    final uid = ref.read(sessionProvider).profile?.uid;
    if (uid == null || _saving) return;
    try {
      final path = await _mediaChannel.invokeMethod<String>(
        'pickProfilePhoto',
        {'uid': uid},
      );
      if (path != null && mounted) setState(() => _photoUrl.text = path);
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Photo could not be selected.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final profile = session.profile;
    if (profile == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final created = MaterialLocalizations.of(context)
        .formatFullDate(profile.createdAt.toLocal());
    return PageContent(
      children: [
        const Eyebrow('Your account'),
        const SizedBox(height: 12),
        Text('Profile', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 32),
        Center(
          child: Column(
            children: [
              AccountAvatar(profile: profile, radius: 48),
              const SizedBox(height: 20),
              Text(
                profile.label,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              SelectableText(
                profile.contactEmail,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        if (_failure != null) ...[
          InlineNotice(_failure!.displayMessage, isError: true),
          const SizedBox(height: 16),
        ],
        if (_editing) ...[
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your name.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contactEmail,
                  enabled: !_saving,
                  keyboardType: TextInputType.emailAddress,
                  maxLength: 254,
                  decoration: const InputDecoration(
                    labelText: 'Contact email',
                    helperText: 'Used for business contact. Google sign-in is unchanged.',
                  ),
                  validator: (value) =>
                      value == null ||
                          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(value.trim())
                      ? 'Enter a valid email address.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  enabled: !_saving,
                  keyboardType: TextInputType.phone,
                  maxLength: 40,
                  decoration: const InputDecoration(labelText: 'Phone number'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _photoUrl,
                  enabled: !_saving,
                  keyboardType: TextInputType.url,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Profile photo URL or selected image',
                    helperText: 'Choose a photo from this device or use an HTTPS image address.',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return null;
                    if (text.startsWith('/') &&
                        text.contains('/profile-images/') &&
                        !text.contains('/../')) {
                      return null;
                    }
                    final uri = Uri.tryParse(text);
                    return uri == null ||
                            uri.scheme != 'https' ||
                            uri.host.isEmpty
                        ? 'Use a valid HTTPS image address.'
                        : null;
                  },
                ),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _pickPhoto,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose profile photo'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save profile'),
                ),
                TextButton(
                  onPressed: _saving
                      ? null
                      : () {
                          _loadFields(profile);
                          setState(() {
                            _editing = false;
                            _failure = null;
                          });
                        },
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ] else ...[
          const Divider(),
          const SizedBox(height: 20),
          _DetailRow(
            'Full name',
            profile.displayName?.trim().isNotEmpty == true
                ? profile.displayName!.trim()
                : 'Not provided',
          ),
          _DetailRow('Contact email', profile.contactEmail),
          _DetailRow(
            'Phone number',
            profile.phone.trim().isEmpty ? 'Not provided' : profile.phone,
          ),
          _DetailRow('Google sign-in email', profile.email),
          _DetailRow('Account created', created),
          const _DetailRow('Sign-in method', 'Google'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                _loadFields(profile);
                setState(() {
                  _editing = true;
                  _failure = null;
                });
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit profile'),
            ),
          ),
        ],
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),
        if (session.failure != null) ...[
          InlineNotice(session.failure!.displayMessage, isError: true),
          const SizedBox(height: 20),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('sign-out'),
            onPressed: session.busy || _saving
                ? null
                : () => ref.read(sessionProvider.notifier).signOut(),
            icon: session.busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded, size: 20),
            label: Text(session.busy ? 'Signing out…' : 'Sign out'),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Signing out does not erase products or bills stored on this device. Sign back into the same account to open this workspace again.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        SelectableText(value, style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );
}
