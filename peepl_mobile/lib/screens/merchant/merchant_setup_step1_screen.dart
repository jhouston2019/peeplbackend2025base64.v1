import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class MerchantSetupStep1Screen extends StatefulWidget {
  const MerchantSetupStep1Screen({super.key});

  @override
  State<MerchantSetupStep1Screen> createState() =>
      _MerchantSetupStep1ScreenState();
}

class _MerchantSetupStep1ScreenState extends State<MerchantSetupStep1Screen> {
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

  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  final _businessNameCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();

  String? _selectedBusinessType;
  File? _logoFile;
  String? _existingLogoUrl;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadMerchantData();
  }

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _streetCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _phoneCtrl.dispose();
    _websiteCtrl.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  Future<void> _loadMerchantData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        setState(() => _loading = false);
        _showSnackBar('You must be signed in to continue.');
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('merchants')
          .doc(uid)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data() ?? {};
        _businessNameCtrl.text = (data['businessName'] as String?) ?? '';
        _streetCtrl.text = (data['streetAddress'] as String?) ?? '';
        _cityCtrl.text = (data['city'] as String?) ?? '';
        _stateCtrl.text = (data['state'] as String?) ?? '';
        _phoneCtrl.text = (data['phone'] as String?) ?? '';
        _websiteCtrl.text = (data['websiteUrl'] as String?) ?? '';
        _selectedBusinessType = data['businessType'] as String?;
        _existingLogoUrl = data['logoUrl'] as String?;
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('Could not load your business profile.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickLogo() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() => _logoFile = File(picked.path));
      }
    } catch (_) {
      _showSnackBar('Could not select image. Please try again.');
    }
  }

  Future<String?> _uploadLogo(String uid) async {
    if (_logoFile == null) return _existingLogoUrl;

    final ref = FirebaseStorage.instance.ref('merchant_logos/$uid.jpg');
    await ref.putFile(_logoFile!);
    return ref.getDownloadURL();
  }

  Future<void> _saveAndContinue() async {
    if (_saving) return;

    if (_selectedBusinessType == null) {
      _showSnackBar('Please select a business type.');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fill in all required fields.');
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showSnackBar('You must be signed in to continue.');
      return;
    }

    setState(() => _saving = true);
    try {
      final logoUrl = await _uploadLogo(uid);

      await FirebaseFirestore.instance.collection('merchants').doc(uid).set({
        'businessName': _businessNameCtrl.text.trim(),
        'businessType': _selectedBusinessType,
        'streetAddress': _streetCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'state': _stateCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'websiteUrl': _websiteCtrl.text.trim(),
        'logoUrl': ?logoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pushNamed(context, '/merchant_setup_step2');
      }
    } catch (_) {
      _showSnackBar('Could not save your information. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Business Setup',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _blue),
            )
          : GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Column(
                children: [
                  Container(
                    color: _blue,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: _buildProgressIndicator(),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Tell us about your business',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'This information helps Peepl match your ads to the right audience.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _sectionLabel('BUSINESS NAME'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _businessNameCtrl,
                              textCapitalization: TextCapitalization.words,
                              decoration: _inputDeco(
                                hint: 'Your business name',
                                prefixIcon: Icons.store_outlined,
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Business name is required'
                                  : null,
                            ),
                            const SizedBox(height: 20),
                            _sectionLabel('BUSINESS TYPE'),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _businessTypes.map((type) {
                                final selected = _selectedBusinessType == type;
                                return FilterChip(
                                  label: Text(type),
                                  selected: selected,
                                  selectedColor: _blue.withValues(alpha: 0.15),
                                  checkmarkColor: _blue,
                                  labelStyle: TextStyle(
                                    color: selected ? _blue : Colors.black87,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                  side: BorderSide(
                                    color: selected
                                        ? _blue
                                        : Colors.grey.shade300,
                                  ),
                                  onSelected: (_) => setState(
                                      () => _selectedBusinessType = type),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                            _sectionLabel('STREET ADDRESS'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _streetCtrl,
                              textCapitalization: TextCapitalization.words,
                              decoration: _inputDeco(
                                hint: '123 Main Street',
                                prefixIcon: Icons.location_on_outlined,
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Street address is required'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _cityCtrl,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: _inputDeco(hint: 'City'),
                                    validator: (v) =>
                                        v == null || v.trim().isEmpty
                                            ? 'City is required'
                                            : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _stateCtrl,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    decoration: _inputDeco(hint: 'State'),
                                    validator: (v) =>
                                        v == null || v.trim().isEmpty
                                            ? 'State is required'
                                            : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _sectionLabel('PHONE NUMBER'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: _inputDeco(
                                hint: '(555) 123-4567',
                                prefixIcon: Icons.phone_outlined,
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Phone number is required'
                                  : null,
                            ),
                            const SizedBox(height: 20),
                            _sectionLabel('WEBSITE URL (OPTIONAL)'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _websiteCtrl,
                              keyboardType: TextInputType.url,
                              decoration: _inputDeco(
                                hint: 'https://yourbusiness.com',
                                prefixIcon: Icons.language_outlined,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _sectionLabel('BUSINESS LOGO'),
                            const SizedBox(height: 10),
                            _buildLogoPicker(),
                            const SizedBox(height: 32),
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _blue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: _saving ? null : _saveAndContinue,
                                child: _saving
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Save and Continue',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        const Text(
          'Step 1 of 2',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLogoPicker() {
    final hasLogo = _logoFile != null ||
        (_existingLogoUrl != null && _existingLogoUrl!.isNotEmpty);

    return InkWell(
      onTap: _pickLogo,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
                image: _logoFile != null
                    ? DecorationImage(
                        image: FileImage(_logoFile!),
                        fit: BoxFit.cover,
                      )
                    : _existingLogoUrl != null &&
                            _existingLogoUrl!.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(_existingLogoUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
              ),
              child: !hasLogo
                  ? Icon(Icons.add_a_photo_outlined,
                      color: Colors.grey.shade500, size: 28)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasLogo ? 'Change logo' : 'Upload business logo',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to select an image from your gallery',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.grey[500],
        letterSpacing: 1.2,
      ),
    );
  }

  InputDecoration _inputDeco({
    required String hint,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: Colors.grey[500])
          : null,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _blue, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
    );
  }
}
