import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class MerchantSetupStep2Screen extends StatefulWidget {
  const MerchantSetupStep2Screen({super.key});

  @override
  State<MerchantSetupStep2Screen> createState() =>
      _MerchantSetupStep2ScreenState();
}

class _MerchantSetupStep2ScreenState extends State<MerchantSetupStep2Screen> {
  static const Color _blue = Color(0xFF1565C0);

  static const _ctaPresets = ['Get Deal', 'Visit Us', 'Order Now'];

  static const _tierPrices = {
    'standard': 99,
    'prime': 299,
  };

  static const _durationMonths = {
    '1': 1,
    '3': 3,
    '6': 6,
  };

  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  final _headlineCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _customCtaCtrl = TextEditingController();
  final _ctaUrlCtrl = TextEditingController();
  final _targetLocationCtrl = TextEditingController();

  File? _adImageFile;
  String? _advertiserName;
  String _selectedCta = 'Get Deal';
  String _tier = 'standard';
  String _duration = '1';
  bool _loadingMerchant = true;
  bool _launching = false;

  @override
  void initState() {
    super.initState();
    _headlineCtrl.addListener(_onFieldsChanged);
    _bodyCtrl.addListener(_onFieldsChanged);
    _customCtaCtrl.addListener(_onFieldsChanged);
    _loadMerchantName();
  }

  @override
  void dispose() {
    _headlineCtrl.dispose();
    _bodyCtrl.dispose();
    _customCtaCtrl.dispose();
    _ctaUrlCtrl.dispose();
    _targetLocationCtrl.dispose();
    super.dispose();
  }

  void _onFieldsChanged() => setState(() {});

  String get _ctaText {
    final custom = _customCtaCtrl.text.trim();
    return custom.isNotEmpty ? custom : _selectedCta;
  }

  int get _monthlyPrice => _tierPrices[_tier] ?? 99;

  int get _totalCost => _monthlyPrice * (_durationMonths[_duration] ?? 1);

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : _blue,
      ),
    );
  }

  Future<void> _loadMerchantName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loadingMerchant = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('merchants')
          .doc(uid)
          .get();
      if (doc.exists && mounted) {
        _advertiserName = doc.data()?['businessName'] as String?;
      }
    } catch (_) {
      // Preview can still render without advertiser name.
    } finally {
      if (mounted) setState(() => _loadingMerchant = false);
    }
  }

  Future<void> _pickAdImage() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() => _adImageFile = File(picked.path));
      }
    } catch (_) {
      _showSnackBar('Could not select image. Please try again.');
    }
  }

  Future<String> _uploadAdImage(String uid) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref =
        FirebaseStorage.instance.ref('ad_images/$uid/$timestamp.jpg');
    await ref.putFile(_adImageFile!);
    return ref.getDownloadURL();
  }

  Future<void> _launchCampaign() async {
    if (_launching) return;

    if (_adImageFile == null) {
      _showSnackBar('Please upload an ad image.');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fill in all required fields.');
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showSnackBar('You must be signed in to launch a campaign.');
      return;
    }

    setState(() => _launching = true);
    try {
      final imageUrl = await _uploadAdImage(uid);
      final now = DateTime.now();
      final months = _durationMonths[_duration] ?? 1;
      final endDate = DateTime(now.year, now.month + months, now.day);

      final targetLocation = _targetLocationCtrl.text.trim();

      await FirebaseFirestore.instance.collection('native_ads').add({
        'advertiserId': uid,
        'advertiserName': _advertiserName ?? '',
        'imageUrl': imageUrl,
        'headline': _headlineCtrl.text.trim(),
        'bodyText': _bodyCtrl.text.trim(),
        'ctaText': _ctaText,
        'ctaUrl': _ctaUrlCtrl.text.trim(),
        'tier': _tier,
        'isActive': false,
        'impressions': 0,
        'clicks': 0,
        'startDate': Timestamp.fromDate(now),
        'endDate': Timestamp.fromDate(endDate),
        'priority': 1,
        if (targetLocation.isNotEmpty) 'targetLocation': targetLocation,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ad submitted for review!'),
            backgroundColor: _blue,
            duration: Duration(seconds: 3),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/merchant_portal',
            (_) => false,
          );
        }
      }
    } catch (_) {
      _showSnackBar('Could not launch campaign. Please try again.');
    } finally {
      if (mounted) setState(() => _launching = false);
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
          'Create Ad',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loadingMerchant
          ? const Center(child: CircularProgressIndicator(color: _blue))
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
                              'Create your first ad',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Preview how your ad will appear in the Peepl feed.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildAdPreview(),
                            const SizedBox(height: 24),
                            _sectionLabel('AD IMAGE'),
                            const SizedBox(height: 8),
                            _buildImagePicker(),
                            const SizedBox(height: 20),
                            _sectionLabel('HEADLINE'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _headlineCtrl,
                              maxLength: 50,
                              decoration: _inputDeco(
                                hint: 'Catchy headline for your ad',
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Headline is required'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            _sectionLabel('BODY TEXT'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _bodyCtrl,
                              maxLength: 100,
                              maxLines: 2,
                              decoration: _inputDeco(
                                hint: 'Short description of your offer',
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Body text is required'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            _sectionLabel('CTA BUTTON TEXT'),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _ctaPresets.map((cta) {
                                final selected =
                                    _customCtaCtrl.text.trim().isEmpty &&
                                        _selectedCta == cta;
                                return ChoiceChip(
                                  label: Text(cta),
                                  selected: selected,
                                  selectedColor: _blue.withValues(alpha: 0.15),
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
                                  onSelected: (_) {
                                    setState(() {
                                      _selectedCta = cta;
                                      _customCtaCtrl.clear();
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _customCtaCtrl,
                              decoration: _inputDeco(
                                hint: 'Or enter custom CTA text',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 12),
                            _sectionLabel('CTA URL'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _ctaUrlCtrl,
                              keyboardType: TextInputType.url,
                              decoration: _inputDeco(
                                hint: 'https://yourbusiness.com/deal',
                                prefixIcon: Icons.link,
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'CTA URL is required'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            _sectionLabel('TARGET LOCATION (OPTIONAL)'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _targetLocationCtrl,
                              textCapitalization: TextCapitalization.words,
                              decoration: _inputDeco(
                                hint: 'City or neighborhood to target',
                                prefixIcon: Icons.location_on_outlined,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _sectionLabel('AD TIER'),
                            const SizedBox(height: 10),
                            _buildTierCard(
                              value: 'standard',
                              label: 'Standard',
                              price: '\$99/mo',
                              description:
                                  'Appears every 3rd post in the feed',
                            ),
                            const SizedBox(height: 10),
                            _buildTierCard(
                              value: 'prime',
                              label: 'Prime',
                              price: '\$299/mo',
                              description:
                                  'First post every user sees — maximum visibility',
                            ),
                            const SizedBox(height: 20),
                            _sectionLabel('CAMPAIGN DURATION'),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _durationChip('1', '1 Month'),
                                const SizedBox(width: 8),
                                _durationChip('3', '3 Months'),
                                const SizedBox(width: 8),
                                _durationChip('6', '6 Months'),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildCostSummary(),
                            const SizedBox(height: 28),
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
                                onPressed:
                                    _launching ? null : _launchCampaign,
                                child: _launching
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Launch Campaign',
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
          'Step 2 of 2',
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdPreview() {
    final headline = _headlineCtrl.text.trim().isEmpty
        ? 'Your headline here'
        : _headlineCtrl.text.trim();
    final body = _bodyCtrl.text.trim().isEmpty
        ? 'Your ad description will appear here'
        : _bodyCtrl.text.trim();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Text(
              'Feed Preview',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade500,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: _adImageFile != null
                        ? Image.file(_adImageFile!, fit: BoxFit.cover)
                        : ColoredBox(
                            color: Colors.grey.shade200,
                            child: Icon(
                              Icons.campaign_outlined,
                              color: Colors.grey.shade400,
                              size: 32,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_advertiserName != null &&
                          _advertiserName!.isNotEmpty)
                        Text(
                          _advertiserName!,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (_advertiserName != null &&
                          _advertiserName!.isNotEmpty)
                        const SizedBox(height: 2),
                      Text(
                        headline,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _headlineCtrl.text.trim().isEmpty
                              ? Colors.grey.shade400
                              : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        style: TextStyle(
                          fontSize: 11,
                          color: _bodyCtrl.text.trim().isEmpty
                              ? Colors.grey.shade400
                              : Colors.grey.shade700,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _blue,
                    disabledForegroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _ctaText,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 10, bottom: 8),
              child: Text(
                'Sponsored',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    return InkWell(
      onTap: _pickAdImage,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _adImageFile == null
                ? Colors.red.shade200
                : Colors.grey.shade300,
          ),
        ),
        child: _adImageFile != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(_adImageFile!, fit: BoxFit.cover),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Change image',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 36, color: Colors.grey.shade500),
                  const SizedBox(height: 8),
                  Text(
                    'Upload ad image (required)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to select from gallery',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTierCard({
    required String value,
    required String label,
    required String price,
    required String description,
  }) {
    final selected = _tier == value;
    return GestureDetector(
      onTap: () => setState(() => _tier = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? _blue.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _blue : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: selected ? _blue : Colors.grey.shade500,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: selected ? _blue : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              price,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: selected ? _blue : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _durationChip(String value, String label) {
    final selected = _duration == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _duration = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? _blue : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? _blue : Colors.grey.shade300,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCostSummary() {
    final months = _durationMonths[_duration] ?? 1;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          _summaryRow(
            '\$$_monthlyPrice/mo × $months month${months > 1 ? 's' : ''}',
            '\$$_totalCost',
          ),
          const Divider(height: 20),
          _summaryRow('Total campaign cost', '\$$_totalCost', bold: true),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
            fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 18 : 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: bold ? _blue : Colors.black87,
          ),
        ),
      ],
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
