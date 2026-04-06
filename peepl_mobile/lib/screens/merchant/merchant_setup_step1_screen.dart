import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'merchant_step_indicator.dart';
import 'merchant_setup_step2_screen.dart';

class MerchantSetupStep1Screen extends StatefulWidget {
  const MerchantSetupStep1Screen({super.key});

  @override
  State<MerchantSetupStep1Screen> createState() =>
      _MerchantSetupStep1ScreenState();
}

class _MerchantSetupStep1ScreenState
    extends State<MerchantSetupStep1Screen> {
  static const _maxChars = 120;
  static const Color _blue = Color(0xFF1565C0);

  final _offerCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  final _venueFocus = FocusNode();

  List<String> _suggestions = [];
  Timer? _debounce;
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _offerCtrl.addListener(() => setState(() {}));
    _venueCtrl.addListener(_onVenueChanged);
    _venueFocus.addListener(() {
      if (!_venueFocus.hasFocus) {
        setState(() => _showSuggestions = false);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _offerCtrl.dispose();
    _venueCtrl.dispose();
    _venueFocus.dispose();
    super.dispose();
  }

  // ── Venue autocomplete ────────────────────────────────────────────────────

  void _onVenueChanged() {
    setState(() {});
    _debounce?.cancel();
    final term = _venueCtrl.text.trim();
    if (term.length < 2) {
      setState(() => _showSuggestions = false);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('location_posts')
            .where('locationName', isGreaterThanOrEqualTo: term)
            .where('locationName', isLessThanOrEqualTo: '$term\uf8ff')
            .limit(8)
            .get();
        final names = snap.docs
            .map((d) => (d.data()['locationName'] as String?) ?? '')
            .where((n) => n.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        if (mounted) {
          setState(() {
            _suggestions = names;
            _showSuggestions = names.isNotEmpty;
          });
        }
      } catch (_) {}
    });
  }

  void _selectVenue(String name) {
    _venueCtrl.text = name;
    setState(() => _showSuggestions = false);
    _venueFocus.unfocus();
  }

  // ── Validation & navigation ───────────────────────────────────────────────

  bool get _canProceed =>
      _offerCtrl.text.trim().isNotEmpty &&
      _venueCtrl.text.trim().isNotEmpty;

  void _next() {
    if (!_canProceed) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MerchantSetupStep2Screen(
          offerText: _offerCtrl.text.trim(),
          venueName: _venueCtrl.text.trim(),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Write Your Ad',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            // Step indicator
            Container(
              color: _blue,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: merchantStepIndicator(1),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionLabel('YOUR OFFER OR MESSAGE'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _offerCtrl,
                      maxLength: _maxChars,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _inputDeco(
                        hint:
                            'e.g. "Free dessert with every main today only!"',
                        counter: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _sectionLabel('VENUE NAME'),
                    const SizedBox(height: 8),
                    Stack(
                      children: [
                        TextField(
                          controller: _venueCtrl,
                          focusNode: _venueFocus,
                          textCapitalization: TextCapitalization.words,
                          decoration: _inputDeco(
                            hint: 'Search for your venue…',
                            prefixIcon: Icons.store_outlined,
                          ),
                        ),
                        if (_showSuggestions)
                          Positioned(
                            top: 56,
                            left: 0,
                            right: 0,
                            child: Material(
                              elevation: 8,
                              borderRadius: BorderRadius.circular(10),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: _suggestions
                                      .map(
                                        (name) => InkWell(
                                          onTap: () => _selectVenue(name),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.location_on_outlined,
                                                  size: 16,
                                                  color: Colors.grey,
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    name,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Can\'t find your venue? Type the exact name as it appears in Peepl.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _canProceed ? _blue : Colors.grey[300],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _canProceed ? _next : null,
                        child: const Text(
                          'Next: Choose Time Slot →',
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
          ],
        ),
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

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
    bool counter = false,
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
      counterText: counter ? null : '',
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
    );
  }
}

