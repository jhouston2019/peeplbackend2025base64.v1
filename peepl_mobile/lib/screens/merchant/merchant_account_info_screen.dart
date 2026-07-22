import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class MerchantAccountInfoScreen extends StatefulWidget {
  const MerchantAccountInfoScreen({super.key});

  @override
  State<MerchantAccountInfoScreen> createState() =>
      _MerchantAccountInfoScreenState();
}

class _MerchantAccountInfoScreenState extends State<MerchantAccountInfoScreen> {
  static const Color _blue = Color(0xFF1565C0);

  static const _businessTypes = [
    'Restaurant',
    'Bar',
    'Café',
    'Retail',
    'Gym',
    'Hotel',
    'Entertainment',
    'Services',
    'Other',
  ];

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;
  final _imagePicker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  final _businessNameCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  final _contactEmailCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();

  String? _logoUrl;
  File? _pendingLogoFile;
  String? _selectedBusinessType;

  bool _loading = true;
  bool _saving = false;
  bool _uploadingLogo = false;
  bool _deleting = false;

  String get _uid => _auth.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _streetCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _phoneCtrl.dispose();
    _websiteCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactEmailCtrl.dispose();
    _contactPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_uid.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);
    try {
      final doc = await _db.collection('merchants').doc(_uid).get();
      final data = doc.data() ?? {};
      final user = _auth.currentUser;

      _businessNameCtrl.text = (data['businessName'] as String?) ?? '';
      _streetCtrl.text = (data['streetAddress'] as String?) ?? '';
      _cityCtrl.text = (data['city'] as String?) ?? '';
      _stateCtrl.text = (data['state'] as String?) ?? '';
      _phoneCtrl.text = (data['phone'] as String?) ?? '';
      _websiteCtrl.text = (data['websiteUrl'] as String?) ?? '';
      _contactNameCtrl.text = (data['contactName'] as String?) ??
          user?.displayName ??
          '';
      _contactEmailCtrl.text =
          (data['contactEmail'] as String?) ?? user?.email ?? '';
      _contactPhoneCtrl.text = (data['contactPhone'] as String?) ?? '';

      if (mounted) {
        setState(() {
          _selectedBusinessType = data['businessType'] as String?;
          _logoUrl = data['logoUrl'] as String?;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('MerchantAccountInfo._load: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickLogo() async {
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
      if (picked != null && mounted) {
        setState(() => _pendingLogoFile = File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick image: $e')),
        );
      }
    }
  }

  Future<String?> _uploadLogo() async {
    if (_pendingLogoFile == null) return _logoUrl;

    setState(() => _uploadingLogo = true);
    try {
      final ref = _storage.ref('merchant_logos/$_uid.jpg');
      await ref.putFile(_pendingLogoFile!);
      return ref.getDownloadURL();
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
  }

  Future<void> _save() async {
    if (_uid.isEmpty || _saving) return;
    if (_selectedBusinessType == null || _selectedBusinessType!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a business type.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final logoUrl = await _uploadLogo();

      await _db.collection('merchants').doc(_uid).set({
        'businessName': _businessNameCtrl.text.trim(),
        'businessType': _selectedBusinessType,
        'streetAddress': _streetCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'state': _stateCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'websiteUrl': _websiteCtrl.text.trim(),
        'contactName': _contactNameCtrl.text.trim(),
        'contactEmail': _contactEmailCtrl.text.trim(),
        'contactPhone': _contactPhoneCtrl.text.trim(),
        'logoUrl': ?logoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _logoUrl = logoUrl ?? _logoUrl;
          _pendingLogoFile = null;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Business info updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your merchant account, business profile, '
          'and sign you out. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteAccount();
    }
  }

  Future<void> _deleteAccount() async {
    if (_uid.isEmpty || _deleting) return;

    setState(() => _deleting = true);
    try {
      await _db.collection('merchants').doc(_uid).delete();

      try {
        await _storage.ref('merchant_logos/$_uid.jpg').delete();
      } catch (_) {
        // Logo may not exist.
      }

      final user = _auth.currentUser;
      if (user != null) {
        try {
          await user.delete();
        } catch (_) {
          await _auth.signOut();
        }
      }

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete account: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        title: const Text(
          'Business Account',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: (_saving || _uploadingLogo || _loading || _deleting)
                ? null
                : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _blue))
          : _uid.isEmpty
              ? const Center(
                  child: Text('Please sign in to edit your business profile.'),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(child: _buildLogoSection()),
                        const SizedBox(height: 28),
                        _sectionTitle('Business Details'),
                        const SizedBox(height: 16),
                        _buildTextField(
                          label: 'Business name',
                          controller: _businessNameCtrl,
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Business name is required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        _buildBusinessTypeDropdown(),
                        const SizedBox(height: 16),
                        _buildTextField(
                          label: 'Street address',
                          controller: _streetCtrl,
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Street address is required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildTextField(
                                label: 'City',
                                controller: _cityCtrl,
                                validator: (v) =>
                                    v == null || v.trim().isEmpty
                                        ? 'City is required'
                                        : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                label: 'State',
                                controller: _stateCtrl,
                                validator: (v) =>
                                    v == null || v.trim().isEmpty
                                        ? 'State is required'
                                        : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          label: 'Phone',
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Phone is required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          label: 'Website URL',
                          controller: _websiteCtrl,
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 28),
                        _sectionTitle('Contact Person'),
                        const SizedBox(height: 16),
                        _buildTextField(
                          label: 'Contact name',
                          controller: _contactNameCtrl,
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Contact name is required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          label: 'Contact email',
                          controller: _contactEmailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            final text = v?.trim() ?? '';
                            if (text.isEmpty) return 'Contact email is required';
                            if (!_isValidEmail(text)) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          label: 'Contact phone',
                          controller: _contactPhoneCtrl,
                          keyboardType: TextInputType.phone,
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Contact phone is required'
                              : null,
                        ),
                        const SizedBox(height: 32),
                        _buildDangerZone(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildLogoSection() {
    final hasImage = _pendingLogoFile != null ||
        (_logoUrl != null && _logoUrl!.isNotEmpty);

    return GestureDetector(
      onTap: _uploadingLogo || _deleting ? null : _pickLogo,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 112,
              height: 112,
              child: _pendingLogoFile != null
                  ? Image.file(_pendingLogoFile!, fit: BoxFit.cover)
                  : hasImage
                      ? Image.network(
                          _logoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _logoPlaceholder(),
                        )
                      : _logoPlaceholder(),
            ),
          ),
          if (_uploadingLogo)
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoPlaceholder() {
    return ColoredBox(
      color: _blue.withValues(alpha: 0.12),
      child: Icon(Icons.store, size: 48, color: _blue.withValues(alpha: 0.7)),
    );
  }

  Widget _buildBusinessTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Business type',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        DropdownMenu<String>(
          key: ValueKey(_selectedBusinessType ?? 'unset'),
          enabled: !_deleting,
          width: MediaQuery.sizeOf(context).width - 40,
          initialSelection: _selectedBusinessType,
          hintText: 'Select business type',
          dropdownMenuEntries: _businessTypes
              .map(
                (type) => DropdownMenuEntry<String>(
                  value: type,
                  label: type,
                ),
              )
              .toList(),
          onSelected: (value) =>
              setState(() => _selectedBusinessType = value),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
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
              borderSide: const BorderSide(color: _blue, width: 2),
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

  Widget _buildDangerZone() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Danger Zone',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Permanently delete your merchant account and all associated data.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _deleting ? null : _confirmDeleteAccount,
              icon: _deleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
              label: const Text('Delete Account'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade300),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          enabled: !_deleting,
          decoration: _inputDecoration(),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
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
        borderSide: const BorderSide(color: _blue, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
    );
  }
}
