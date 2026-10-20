import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../app_state.dart';
import '../models.dart';
import '../strings.dart';
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
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      foregroundImage: path == null ? null : NetworkImage(serverUrl(path)),
      child: Text(initial, style: TextStyle(fontSize: radius * 0.8, fontWeight: FontWeight.w600)),
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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera), title: Text(s.takePhoto), onTap: () => Navigator.pop(context, 'camera')),
          ListTile(leading: const Icon(Icons.photo_library), title: Text(s.choosePhoto), onTap: () => Navigator.pop(context, 'gallery')),
          if (state.user?.avatarPath != null)
            ListTile(leading: const Icon(Icons.delete_outline), title: Text(s.removePhoto), onTap: () => Navigator.pop(context, 'remove')),
        ]),
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

    return Scaffold(
      appBar: AppBar(title: Text(s.profile)),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Center(
            child: Stack(children: [
              Avatar(user: user, radius: 52),
              Positioned(
                right: 0,
                bottom: 0,
                child: IconButton.filled(
                  icon: _uploading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.photo_camera, size: 20),
                  onPressed: _uploading ? null : _changePhoto,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Text(user.email, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor)),
          const SizedBox(height: 24),
          TextFormField(
            controller: _fullName,
            decoration: InputDecoration(labelText: s.fullName),
            textCapitalization: TextCapitalization.words,
            validator: required,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phone,
            decoration: InputDecoration(labelText: s.phone),
            keyboardType: TextInputType.phone,
            validator: required,
          ),
          const SizedBox(height: 24),
          Text(s.profileHint, style: TextStyle(color: Theme.of(context).hintColor)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _birthYear,
            decoration: InputDecoration(labelText: s.birthYear),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
            validator: (value) {
              if ((value ?? '').isEmpty) return null;
              final year = int.tryParse(value!);
              return year == null || year < 1900 || year > DateTime.now().year ? s.invalidYear : null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            initialValue: _gender,
            decoration: InputDecoration(labelText: s.gender),
            items: [
              DropdownMenuItem(value: null, child: Text(s.notSet)),
              for (final value in ['male', 'female', 'other']) DropdownMenuItem(value: value, child: Text(s.genderLabel(value))),
            ],
            onChanged: (value) => setState(() => _gender = value),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            initialValue: _skillLevel,
            decoration: InputDecoration(labelText: s.skillLevel),
            items: [
              DropdownMenuItem(value: null, child: Text(s.notSet)),
              for (final value in ['beginner', 'intermediate', 'advanced', 'expert'])
                DropdownMenuItem(value: value, child: Text(s.skillLabel(value))),
            ],
            onChanged: (value) => setState(() => _skillLevel = value),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(onPressed: _busy ? null : _save, child: Text(s.save)),
        ]),
      ),
    );
  }
}
