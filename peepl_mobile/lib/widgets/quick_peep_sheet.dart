import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'home/peepl_home_tokens.dart';
import 'package:image_picker/image_picker.dart';

import '../services/feed_service.dart';
import '../services/location_label_service.dart';
import '../services/location_service.dart';

class QuickPeepSheet {
  QuickPeepSheet._();

  static void show(BuildContext context, {String? venueName}) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width * 0.175,
          vertical: 0,
        ),
        child: _QuickPeepContent(venueName: venueName),
      ),
    );
  }
}

class _QuickPeepContent extends StatefulWidget {
  const _QuickPeepContent({this.venueName});

  final String? venueName;

  @override
  State<_QuickPeepContent> createState() => _QuickPeepContentState();
}

class _QuickPeepContentState extends State<_QuickPeepContent> {
  static const _vibeOptions = [
    'Dead quiet',
    'Moderate',
    'Buzzing',
    'Packed',
  ];

  static const _venueTypes = [
    'Restaurant',
    'Bar',
    'Cafe',
    'Other',
  ];

  static const _waitTimeOptions = [
    'No wait',
    '5–15 min',
    '15–30 min',
    '30+ min',
  ];

  final _placeController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  double _crowdLevel = 5;
  double _malePercent = 50;
  double _adultPercent = 50;
  String? _selectedVibe;
  String? _venueType;
  String? _selectedWaitTime;
  bool _isLoading = false;
  bool _fieldError = false;
  bool _isLocating = false;
  String? _locationError;

  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    if (widget.venueName != null) {
      _placeController.text = widget.venueName!;
      _acquireCoordinates();
    } else {
      _detectLocation();
    }
  }

  @override
  void dispose() {
    _placeController.dispose();
    super.dispose();
  }

  Color _getCrowdingColor(int level) {
    if (level <= 3) return const Color(0xFF4CAF50);
    if (level <= 6) return const Color(0xFFFFA726);
    return const Color(0xFFFF5722);
  }

  Future<void> _acquireCoordinates() async {
    try {
      final position =
          await LocationService.getCurrentLocation(forceRefresh: true);
      if (!mounted || position == null) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      debugPrint('QuickPeepSheet: coordinate acquisition failed: $e');
    }
  }

  Future<void> _detectLocation() async {
    setState(() {
      _isLocating = true;
      _locationError = null;
    });

    try {
      final position =
          await LocationService.getCurrentLocation(forceRefresh: true);
      if (position == null) {
        if (!mounted) return;
        setState(() {
          _locationError = 'Could not detect location';
          _isLocating = false;
        });
        return;
      }

      final lat = position.latitude;
      final lng = position.longitude;
      _latitude = lat;
      _longitude = lng;

      final label = await LocationLabelService.resolve(lat, lng);

      if (!mounted) return;
      setState(() {
        _placeController.text = label;
      });
    } catch (e) {
      debugPrint('[QuickPeep] _detectLocation error: $e');
      if (!mounted) return;
      if (_latitude != null && _longitude != null) {
        final fallback = await LocationLabelService.resolve(
          _latitude!,
          _longitude!,
        );
        setState(() {
          _placeController.text = fallback;
        });
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _isLocating = false;
      });
    }
  }

  Future<void> _submitPost() async {
    if (_placeController.text.trim().isEmpty) {
      setState(() => _fieldError = true);
      return;
    }
    setState(() => _fieldError = false);

    XFile? photo;
    try {
      photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1200,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera unavailable: $e')),
      );
      return;
    }

    if (photo == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      if (_latitude == null || _longitude == null) {
        await _acquireCoordinates();
      }

      final postId = await FeedService().addLocationPost(
        userId: user.uid,
        username: user.displayName ?? user.email?.split('@')[0] ?? 'Anonymous',
        locationName: _placeController.text.trim(),
        latitude: _latitude ?? 0.0,
        longitude: _longitude ?? 0.0,
        crowdingLevel: _crowdLevel.round(),
        imageFile: File(photo.path),
        vibe: _selectedVibe,
        waitTime: _venueType == 'Restaurant' ? _selectedWaitTime : null,
        maleFemaleRatio: _malePercent.round(),
        adultKidRatio: _adultPercent.round(),
        venueType: _venueType,
      );

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Peeped! 👁️')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crowdInt = _crowdLevel.round();
    final crowdColor = _getCrowdingColor(crowdInt);

    return SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Quick Peep 👁️',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Where are you right now?',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _placeController,
                          decoration: InputDecoration(
                            hintText: _isLocating
                                ? 'Detecting your location...'
                                : 'Type a place name...',
                            prefixIcon: _isLocating
                                ? Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF1565C0),
                                      ),
                                    ),
                                  )
                                : Icon(Icons.location_on,
                                    color: Color(0xFF1565C0)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: _fieldError
                                    ? Colors.red
                                    : Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: _fieldError
                                    ? Colors.red
                                    : Colors.grey.shade300,
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            suffixIcon: !_isLocating &&
                                    _placeController.text.isNotEmpty
                                ? Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                    color: Colors.grey[600],
                                  )
                                : null,
                          ),
                          onChanged: (_) =>
                              setState(() => _fieldError = false),
                        ),
                      ),
                      SizedBox(width: 8),
                      GestureDetector(
                        onTap: _isLocating ? null : _detectLocation,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Color(0xFF1565C0).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.my_location,
                            color: _isLocating
                                ? Colors.grey
                                : Color(0xFF1565C0),
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_locationError != null) ...[
                    SizedBox(height: 4),
                    Text(
                      _locationError!,
                      style: TextStyle(color: Colors.red, fontSize: 11),
                    ),
                  ] else if (!_isLocating &&
                      _placeController.text.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text(
                      'Wrong place? Tap the field to edit.',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'How crowded?',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$crowdInt',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: crowdColor,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _crowdLevel,
                    min: 0,
                    max: 10,
                    divisions: 10,
                    activeColor: crowdColor,
                    onChanged: _isLoading
                        ? null
                        : (v) => setState(() => _crowdLevel = v),
                  ),
                  const SizedBox(height: 8),
                  _buildRatioSlider(
                    label: 'Male / female mix',
                    value: _malePercent,
                    display: 'M/F: ${_malePercent.round()}/${100 - _malePercent.round()}',
                    leftHint: 'More female',
                    rightHint: 'More male',
                    onChanged: (v) => setState(() => _malePercent = v),
                  ),
                  const SizedBox(height: 12),
                  _buildRatioSlider(
                    label: 'Adults / kids mix',
                    value: _adultPercent,
                    display: 'A/K: ${_adultPercent.round()}/${100 - _adultPercent.round()}',
                    leftHint: 'More kids',
                    rightHint: 'More adults',
                    onChanged: (v) => setState(() => _adultPercent = v),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Vibe',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _vibeOptions.map((vibe) {
                        final selected = _selectedVibe == vibe;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(vibe),
                            selected: selected,
                            onSelected: _isLoading
                                ? null
                                : (_) {
                                    setState(() {
                                      _selectedVibe = selected ? null : vibe;
                                    });
                                  },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Place type',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _venueTypes.map((type) {
                        final selected = _venueType == type;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(type),
                            selected: selected,
                            onSelected: _isLoading
                                ? null
                                : (_) {
                                    setState(() {
                                      _venueType = selected ? null : type;
                                      if (_venueType != 'Restaurant') {
                                        _selectedWaitTime = null;
                                      }
                                    });
                                  },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  if (_venueType == 'Restaurant') ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Wait time',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _waitTimeOptions.map((wait) {
                          final selected = _selectedWaitTime == wait;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(wait),
                              selected: selected,
                              onSelected: _isLoading
                                  ? null
                                  : (_) {
                                      setState(() {
                                        _selectedWaitTime =
                                            selected ? null : wait;
                                      });
                                    },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitPost,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PeeplHomeTokens.actionGreen,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt, size: 18, color: Colors.black),
                                SizedBox(width: 8),
                                Text(
                                  'Take Photo & Peep 👁️',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatioSlider({
    required String label,
    required double value,
    required String display,
    required String leftHint,
    required String rightHint,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              display,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(0, 100),
          min: 0,
          max: 100,
          divisions: 20,
          label: display,
          onChanged: _isLoading ? null : onChanged,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              leftHint,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            Text(
              rightHint,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }
}
