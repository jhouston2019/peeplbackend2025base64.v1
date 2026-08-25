import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'home/peepl_home_tokens.dart';
import 'package:image_picker/image_picker.dart';

import '../services/feed_service.dart';
import '../services/location_service.dart';
import '../services/venue_name_service.dart';
import '../utils/composer_launch.dart';

class QuickPeepSheet {
  QuickPeepSheet._();

  static void show(
    BuildContext context, {
    String? venueName,
    String? placeId,
    double? latitude,
    double? longitude,
    String? composerSource,
  }) {
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
        child: _QuickPeepContent(
          launch: ComposerLaunch(
            composerSource: composerSource ??
                ((venueName != null && venueName.isNotEmpty)
                    ? 'venue_tap'
                    : 'direct'),
            locationName: venueName,
            placeId: placeId,
            latitude: latitude,
            longitude: longitude,
            fromVenueEntry: composerSource == 'walk_in',
          ),
        ),
      ),
    );
  }
}

class _QuickPeepContent extends StatefulWidget {
  const _QuickPeepContent({required this.launch});

  final ComposerLaunch launch;

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

  final _picker = ImagePicker();
  final _locationController = TextEditingController();

  double _crowdLevel = 5;
  double _malePercent = 50;
  double _adultPercent = 50;
  String? _selectedVibe;
  String? _venueType;
  String? _selectedWaitTime;
  bool _isLoading = false;
  bool _isLocating = false;
  String? _locationError;
  bool _locationEditedByUser = false;
  bool _placesAttempted = false;
  String? _placeId;

  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    try {
      _applyLaunch(widget.launch);
      if (widget.launch.hasPrefilledCoords) {
        _detectVenueOnce().catchError((Object e) {
          debugPrint('[QuickPeepSheet] initState _detectVenueOnce error: $e');
        });
      } else {
        _detectLocation().catchError((Object e) {
          debugPrint('[QuickPeepSheet] initState _detectLocation error: $e');
        });
      }
    } catch (e) {
      debugPrint('[QuickPeepSheet] initState error: $e');
    }
  }

  void _applyLaunch(ComposerLaunch launch) {
    _composerSource = launch.composerSource ?? 'direct';
    final name = launch.locationName?.trim();
    if (name != null &&
        name.isNotEmpty &&
        !VenueNameService.isWeakVenueName(name)) {
      _locationController.text = name;
    }
    if (launch.latitude != null && launch.longitude != null) {
      _latitude = launch.latitude;
      _longitude = launch.longitude;
    }
    final placeId = launch.placeId;
    if (placeId != null && placeId.isNotEmpty) {
      _placeId = placeId;
    }
    if (launch.shouldSkipPlaces()) {
      _placesAttempted = true;
    }
  }

  bool _shouldCallPlaces() {
    return widget.launch
        .shouldCallPlaces(placesAttempted: _placesAttempted);
  }

  String? _composerSource;

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  void _applyDetectedLabel(String label) {
    if (_locationEditedByUser) return;
    _locationController.text = label;
  }

  Color _getCrowdingColor(int level) {
    if (level <= 3) return const Color(0xFF4CAF50);
    if (level <= 6) return const Color(0xFFFFA726);
    return const Color(0xFFFF5722);
  }

  Future<void> _onRedetectLocationTap() async {
    if (_isLocating) return;
    setState(() => _locationEditedByUser = false);
    try {
      await _acquireCoordinates();
    } catch (e) {
      debugPrint('[QuickPeepSheet] _onRedetectLocationTap error: $e');
    }
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

  Future<void> _detectVenueOnce() async {
    if (_placesAttempted) return;
    if (!_shouldCallPlaces()) {
      _placesAttempted = true;
      return;
    }

    final lat = _latitude;
    final lng = _longitude;
    if (lat == null || lng == null) return;

    _placesAttempted = true;
    try {
      final result = await VenueNameService.searchNearbyTop(
        latitude: lat,
        longitude: lng,
      );
      if (!mounted) return;
      if (result != null) {
        _placeId = result.placeId;
        if (!_locationEditedByUser) {
          setState(() => _applyDetectedLabel(result.name));
        }
      }
    } catch (e) {
      debugPrint('[QuickPeep] _detectVenueOnce error: $e');
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

      _latitude = position.latitude;
      _longitude = position.longitude;
      await _detectVenueOnce();
    } catch (e) {
      debugPrint('[QuickPeep] _detectLocation error: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isLocating = false;
      });
    }
  }

  Future<bool> _ensureLocationReady() async {
    if (_latitude == null || _longitude == null) {
      await _detectLocation();
    } else if (!_placesAttempted && _shouldCallPlaces()) {
      await _detectVenueOnce();
    }

    final readyLabel = _locationController.text.trim();
    return _latitude != null &&
        _longitude != null &&
        !(_latitude == 0 && _longitude == 0) &&
        readyLabel.isNotEmpty &&
        readyLabel != 'Current location';
  }

  Future<void> _submitPost() async {
    setState(() => _locationError = null);

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
      final ready = await _ensureLocationReady();
      if (!ready) {
        if (context.mounted) {
          final missingGps = _latitude == null || _longitude == null;
          setState(() {
            _locationError = missingGps
                ? 'Could not detect your location'
                : 'Enter a venue name';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                missingGps
                    ? 'Turn on location and try again'
                    : 'Enter a venue name to post',
              ),
            ),
          );
        }
        return;
      }

      final imageFile = File(photo.path);
      if (!await imageFile.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo file not found')),
          );
        }
        return;
      }

      final locationName = _locationController.text.trim();
      final postId = await FeedService().addLocationPost(
        userId: user.uid,
        username: user.displayName ?? user.email?.split('@')[0] ?? 'Anonymous',
        locationName: locationName,
        latitude: _latitude!,
        longitude: _longitude!,
        crowdingLevel: _crowdLevel.round(),
        imageFile: imageFile,
        vibe: _selectedVibe,
        waitTime: _venueType == 'Restaurant' ? _selectedWaitTime : null,
        maleFemaleRatio: _malePercent.round(),
        adultKidRatio: _adultPercent.round(),
        venueType: _venueType,
        placeId: _placeId,
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
                    'Your location',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _locationController,
                          enabled: !_isLocating && !_isLoading,
                          decoration: InputDecoration(
                            hintText: _isLocating
                                ? 'Detecting your location…'
                                : (_placesAttempted
                                    ? 'Enter venue name'
                                    : 'Waiting for GPS…'),
                            prefixIcon: _isLocating
                                ? const Padding(
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
                                : const Icon(
                                    Icons.location_on,
                                    color: Color(0xFF1565C0),
                                  ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            suffixIcon: !_isLocating &&
                                    _locationController.text.isNotEmpty
                                ? Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                    color: Colors.grey[600],
                                  )
                                : null,
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          onChanged: (_) {
                            setState(() {
                              _locationEditedByUser = true;
                              _locationError = null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _onRedetectLocationTap,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1565C0).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.my_location,
                            color: _isLocating
                                ? Colors.grey
                                : const Color(0xFF1565C0),
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_locationError != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _locationError!,
                      style: const TextStyle(color: Colors.red, fontSize: 11),
                    ),
                  ] else if (!_isLocating &&
                      _locationController.text.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Confirm this venue, or tap to edit.',
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
