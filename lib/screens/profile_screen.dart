import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../app_state.dart';
import '../models.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';

/// The round profile photo, or the initial of the name without one.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.user, this.radius = 28});

  final User user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final path = user.avatarPath;
    final initial = user.fullName.trim().isEmpty ? '?' : user.fullName.trim().characters.first.toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.mint,
      foregroundImage: path == null ? null : NetworkImage(serverUrl(path)),
      child: Text(
        initial,
        style: TextStyle(fontSize: radius * 0.8, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
      ),
    );
  }
}

/// Name, phone, photo and the optional profile (TK-10).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final User _user = AppScope.read(context).user!;
  late final _fullName = TextEditingController(text: _user.fullName);
  late final _phone = TextEditingController(text: _user.phone);
  late final _birthYear = TextEditingController(text: _user.birthYear?.toString() ?? '');
  late String? _gender = _user.gender;
  late String? _skillLevel = _user.skillLevel;
  bool _busy = false;
  bool _uploading = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_fullName, _phone, _birthYear]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final s = S.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.read(context).updateProfile(
        fullName: _fullName.text,
        phone: _phone.text,
        birthYear: int.tryParse(_birthYear.text.trim()),
        gender: _gender,
        skillLevel: _skillLevel,
      );
      if (!mounted) return;
      showMessage(context, s.saved);
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _error = s.error(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePhoto() async {
    final s = S.of(context);
    final state = AppScope.read(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: Text(s.takePhoto),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(s.choosePhoto),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            if (state.user?.avatarPath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(s.removePhoto),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      if (choice == 'remove') {
        await state.removeAvatar();
      } else {
        // Shrunk on the phone: a profile photo needs no more, and the server takes at most 2 MB.
        final file = await ImagePicker().pickImage(
          source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 512,
          maxHeight: 512,
          imageQuality: 85,
        );
        if (file == null) return;
        await state.uploadAvatar(file.path);
        if (mounted) showMessage(context, s.photoSaved);
      }
    } catch (error) {
      if (mounted) showMessage(context, s.error(error));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final user = AppScope.of(context).user;
    if (user == null) return const SizedBox.shrink();
    String? required(String? value) => (value ?? '').trim().isEmpty ? s.required : null;

    Widget choices(
      String label,
      List<String> values,
      String? selected,
      String Function(String) text,
      Color Function(String) color,
      ValueChanged<String?> onSelected,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in [null, ...values])
              ChoiceChip(
                label: Text(value == null ? s.notSet : text(value)),
                selected: selected == value,
                showCheckmark: false,
                selectedColor: value == null ? AppColors.muted : color(value),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected == value ? Colors.white : AppColors.ink,
                ),
                side: selected == value ? BorderSide.none : null,
                onSelected: (_) => onSelected(value),
              ),
          ],
        ),
      ],
    );

    return Scaffold(
      body: Form(
        key: _form,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            GradientHeader(
              title: s.profile,
              child: Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.5)),
                          child: Avatar(user: user, radius: 52),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.lime,
                              foregroundColor: AppColors.ink,
                            ),
                            icon: _uploading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink),
                                  )
                                : const Icon(Icons.photo_camera_rounded, size: 20),
                            onPressed: _uploading ? null : _changePhoto,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(user.email, style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _fullName,
                    decoration: InputDecoration(labelText: s.fullName, prefixIcon: const Icon(Icons.person_rounded)),
                    textCapitalization: TextCapitalization.words,
                    validator: required,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phone,
                    decoration: InputDecoration(labelText: s.phone, prefixIcon: const Icon(Icons.phone_rounded)),
                    keyboardType: TextInputType.phone,
                    validator: required,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.mint, borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline_rounded, color: AppColors.primaryDark, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.profileHint,
                            style: const TextStyle(color: AppColors.primaryDark, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _birthYear,
                    decoration: InputDecoration(labelText: s.birthYear, prefixIcon: const Icon(Icons.cake_rounded)),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                    validator: (value) {
                      if ((value ?? '').isEmpty) return null;
                      final year = int.tryParse(value!);
                      return year == null || year < 1900 || year > DateTime.now().year ? s.invalidYear : null;
                    },
                  ),
                  const SizedBox(height: 20),
                  choices(
                    s.gender,
                    const ['male', 'female', 'other'],
                    _gender,
                    s.genderLabel,
                    (_) => AppColors.primary,
                    (value) => setState(() => _gender = value),
                  ),
                  const SizedBox(height: 20),
                  choices(
                    s.skillLevel,
                    const ['beginner', 'intermediate', 'advanced', 'expert'],
                    _skillLevel,
                    s.skillLabel,
                    AppColors.skill,
                    (value) => setState(() => _skillLevel = value),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 28),
                  GradientButton(label: s.save, icon: Icons.check_rounded, busy: _busy, onPressed: _save),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
