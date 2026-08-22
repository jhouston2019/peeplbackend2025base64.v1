import 'dart:io';
import '../theme/peepl_app_tokens.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class AccountInfoScreen extends StatefulWidget {
  const AccountInfoScreen({super.key});

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  static const _kUsersCollection = 'CAASNAhaDbPrl0zH1yDn5qRqAtJ3';

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;
  final _imagePicker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  final _displayNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  String? _photoUrl;
  File? _pendingPhotoFile;
  bool _isVIPeep = false;

  bool _loading = true;
  bool _saving = false;
  bool _uploadingPhoto = false;

  String get _uid => _auth.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _bioCtrl.addListener(() => setState(() {}));
    _loadProfile();
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (_uid.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);
    try {
      final doc =
          await _db.collection(_kUsersCollection).doc(_uid).get();
      final data = doc.data() ?? {};
      final user = _auth.currentUser;

      _displayNameCtrl.text = (data['displayName'] as String?) ??
          (data['name'] as String?) ??
          user?.displayName ??
          '';
      _usernameCtrl.text = (data['username'] as String?) ?? '';
      _bioCtrl.text = (data['bio'] as String?) ?? '';
      _emailCtrl.text =
          (data['email'] as String?) ?? user?.email ?? '';

      if (mounted) {
        setState(() {
          _photoUrl = data['photoUrl'] as String?;
          _isVIPeep = data['isVIPeep'] as bool? ?? false;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('AccountInfoScreen._loadProfile: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      setState(() => _pendingPhotoFile = File(picked.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick image: $e')),
        );
      }
    }
  }

  Future<String?> _uploadProfilePhoto() async {
    if (_pendingPhotoFile == null) return _photoUrl;

    setState(() => _uploadingPhoto = true);
    try {
      final ref = _storage.ref('profile_photos/$_uid.jpg');
      await ref.putFile(_pendingPhotoFile!);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('[AccountInfoScreen] _uploadProfilePhoto error: $e');
      return _photoUrl;
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
  }

  String? _validateUsername(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Username is required';
    if (text.contains(' ')) return 'Username cannot contain spaces';
    if (text != text.toLowerCase()) {
      return 'Username must be lowercase only';
    }
    if (!RegExp(r'^[a-z0-9_\.]+$').hasMatch(text)) {
      return 'Use lowercase letters, numbers, underscores, or dots';
    }
    return null;
  }

  Future<void> _saveProfile() async {
    if (_uid.isEmpty || _saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final photoUrl = await _uploadProfilePhoto();
      final updates = <String, dynamic>{
        'displayName': _displayNameCtrl.text.trim(),
        'username': _usernameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
      };
      if (photoUrl != null) {
        updates['photoUrl'] = photoUrl;
      }

      await _db.collection(_kUsersCollection).doc(_uid).set(
            updates,
            SetOptions(merge: true),
          );

      final user = _auth.currentUser;
      if (user != null &&
          _displayNameCtrl.text.trim().isNotEmpty &&
          user.displayName != _displayNameCtrl.text.trim()) {
        await user.updateDisplayName(_displayNameCtrl.text.trim());
      }

      if (mounted) {
        setState(() {
          _photoUrl = photoUrl ?? _photoUrl;
          _pendingPhotoFile = null;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e')),
        );
      }
    }
  }

  Future<void> _changePassword() async {
    final email = _auth.currentUser?.email ?? _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email address on file')),
      );
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send reset email: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PeeplAppTokens.background,
      appBar: AppBar(
        backgroundColor: PeeplAppTokens.shellNavy,
        foregroundColor: PeeplAppTokens.textPrimary,
        title: const Text(
          'Account Info',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: (_saving || _uploadingPhoto || _loading)
                ? null
                : _saveProfile,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: PeeplAppTokens.textPrimary,
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: PeeplAppTokens.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _uid.isEmpty
              ? const Center(
                  child: Text('Please sign in to edit your profile.'),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildAvatarSection(),
                        if (_isVIPeep) ...[
                          const SizedBox(height: 16),
                          _buildVIPBadge(),
                        ],
                        const SizedBox(height: 28),
                        _buildTextField(
                          label: 'Display Name',
                          controller: _displayNameCtrl,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          label: 'Username',
                          controller: _usernameCtrl,
                          textInputAction: TextInputAction.next,
                          validator: _validateUsername,
                          inputFormatters: [
                            FilteringTextInputFormatter.deny(RegExp(r'\s')),
                            TextInputFormatter.withFunction(
                              (oldValue, newValue) => TextEditingValue(
                                text: newValue.text.toLowerCase(),
                                selection: newValue.selection,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          label: 'Bio',
                          controller: _bioCtrl,
                          maxLines: 4,
                          maxLength: 150,
                          textInputAction: TextInputAction.newline,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          label: 'Email',
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) return 'Email is required';
                            if (!_isValidEmail(text)) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _changePassword,
                            icon: const Icon(Icons.lock_outline),
                            label: const Text('Change Password'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: PeeplAppTokens.accentBlue,
                              side: const BorderSide(color: PeeplAppTokens.accentBlue),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildAvatarSection() {
    return GestureDetector(
      onTap: _uploadingPhoto ? null : _pickPhoto,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: 56,
            backgroundColor: PeeplAppTokens.shellNavy,
            backgroundImage: _pendingPhotoFile != null
                ? FileImage(_pendingPhotoFile!)
                : (_photoUrl != null && _photoUrl!.isNotEmpty
                    ? NetworkImage(_photoUrl!)
                    : null),
            child: (_pendingPhotoFile == null &&
                    (_photoUrl == null || _photoUrl!.isEmpty))
                ? Text(
                    _displayNameCtrl.text.isNotEmpty
                        ? _displayNameCtrl.text[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: PeeplAppTokens.textPrimary,
                    ),
                  )
                : null,
          ),
          if (_uploadingPhoto)
            const SizedBox(
              width: 112,
              height: 112,
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(
                  child: CircularProgressIndicator(color: PeeplAppTokens.textPrimary),
                ),
              ),
            ),
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: PeeplAppTokens.accentBlue,
                shape: BoxShape.circle,
                border: Border.all(color: PeeplAppTokens.textPrimary, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt,
                color: PeeplAppTokens.textPrimary,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVIPBadge() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/vip_peeps'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, color: PeeplAppTokens.textPrimary, size: 18),
            SizedBox(width: 6),
            Text(
              'VIPeep',
              style: TextStyle(
                color: PeeplAppTokens.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.chevron_right, color: PeeplAppTokens.textPrimary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    int maxLines = 1,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: PeeplAppTokens.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          inputFormatters: inputFormatters,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          maxLines: maxLines,
          maxLength: maxLength,
          buildCounter: maxLength != null
              ? (
                  context, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) =>
                  Text(
                    '$currentLength/$maxLength',
                    style: TextStyle(
                      fontSize: 12,
                      color: PeeplAppTokens.textSecondary,
                    ),
                  )
              : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: PeeplAppTokens.searchField,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: PeeplAppTokens.accentBlue, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}
