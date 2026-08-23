import 'dart:io';
import '../theme/peepl_app_tokens.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../services/feed_service.dart';
import '../services/location_service.dart';
import '../services/venue_name_service.dart';
import '../widgets/crowd_meter.dart';

class CreatePeepScreen extends StatefulWidget {
  const CreatePeepScreen({super.key});

  @override
  State<CreatePeepScreen> createState() => _CreatePeepScreenState();
}

class _CreatePeepScreenState extends State<CreatePeepScreen> {
  static const _defaultImageUrl =
      'https://images.unsplash.com/photo-1501854140801-50d01698950b?w=800';

  final _locationController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _feedService = FeedService();

  int _crowdingLevel = 5;
  bool _isLoading = false;
  bool _isGeolocating = false;
  bool _locationPreFilled = false;
  bool _hasNotificationLocation = false;
  bool _fromVenueEntry = false;
  bool _locationPermissionDenied = false;
  bool _isResolvingVenueName = false;
  bool _locationEditedByUser = false;

  double? _latitude;
  double? _longitude;
  File? _selectedImage;

  late final List<_QuickCriterion> _criteria = [
    _QuickCriterion(
      emoji: '🚗',
      label: 'Parking',
      values: const ['Easy', 'Limited', 'None'],
    ),
    _QuickCriterion(
      emoji: '👶',
      label: 'Kids',
      values: const ['Few', 'Some', 'Many'],
    ),
    _QuickCriterion(
      emoji: '🔊',
      label: 'Noise',
      values: const ['Quiet', 'Moderate', 'Loud'],
    ),
    _QuickCriterion(
      emoji: '⏱',
      label: 'Wait',
      values: const ['No wait', '5–15 min', '15–30 min', '30+ min'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveLocationAndGeocode();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_locationPreFilled) return;
    _locationPreFilled = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['locationName'] != null) {
      _hasNotificationLocation = true;
      _fromVenueEntry =
          args['fromVenueEntry'] == true || _hasNotificationLocation;
      _locationController.text = args['locationName'] as String;
      final lat = args['latitude'];
      final lng = args['longitude'];
      if (lat is num) _latitude = lat.toDouble();
      if (lng is num) _longitude = lng.toDouble();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resolveNotificationVenueName();
      });
    }
  }

  Future<void> _resolveNotificationVenueName() async {
    if (!mounted) return;

    final raw = _locationController.text.trim();
    if (raw.isEmpty) return;
    if (!VenueNameService.looksLikeAddress(raw)) return;

    final lat = _latitude;
    final lng = _longitude;
    if (lat == null || lng == null) return;

    setState(() => _isResolvingVenueName = true);
    try {
      final resolved = await VenueNameService.resolveVenueName(lat, lng);
      if (!mounted) return;
      if (resolved != null && resolved.isNotEmpty && !_locationEditedByUser) {
        setState(() => _locationController.text = resolved);
      }
    } finally {
      if (mounted) setState(() => _isResolvingVenueName = false);
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _resolveLocationAndGeocode() async {
    if (!mounted || _hasNotificationLocation) return;
    setState(() => _isGeolocating = true);
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        if (mounted) setState(() => _locationPermissionDenied = true);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locationPermissionDenied = true);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      if (!mounted) return;
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _locationPermissionDenied = false;
      });

      final name = await VenueNameService.resolveLabelAtPin(
        pos.latitude,
        pos.longitude,
      );
      if (!mounted) return;
      if (name.isNotEmpty && !_locationEditedByUser) {
        _locationController.text = name;
      }
    } catch (e, st) {
      debugPrint('Geolocation/geocoding failed: $e\n$st');
    } finally {
      if (mounted) setState(() => _isGeolocating = false);
    }
  }

  void _cycleCrowdingLevel() {
    setState(() {
      _crowdingLevel = _crowdingLevel >= 10 ? 1 : _crowdingLevel + 1;
    });
  }

  Future<void> _pickPhotoFromCamera() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() => _selectedImage = File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not access camera: $e')),
        );
      }
    }
  }

  Future<File> _resolveImageFile() async {
    if (_selectedImage != null) return _selectedImage!;
    try {
      final response = await http.get(Uri.parse(_defaultImageUrl));
      if (response.statusCode != 200) {
        throw Exception('Could not load default image');
      }
      final file = File(
        '${Directory.systemTemp.path}/peepl_quick_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(response.bodyBytes);
      return file;
    } catch (e) {
      throw Exception('Could not load default image: $e');
    }
  }

  String _buildDescription() {
    final parts = <String>['Quick Peep'];
    for (final c in _criteria) {
      final value = c.value;
      if (value != null) {
        parts.add('${c.label}: $value');
      }
    }
    return parts.join(' · ');
  }

  int? _noiseLevel() {
    final noise = _criteria[2].value;
    return switch (noise) {
      'Quiet' => 3,
      'Moderate' => 5,
      'Loud' => 8,
      _ => null,
    };
  }

  int _adultKidRatio() {
    return switch (_criteria[1].value) {
      'Few' => 85,
      'Some' => 65,
      'Many' => 35,
      _ => 50,
    };
  }

  String? _waitTime() => _criteria[3].value;

  Future<void> _submitPost() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      if (!_fromVenueEntry) {
        final position =
            await LocationService.getCurrentLocation(forceRefresh: true);
        if (position != null) {
          _latitude = position.latitude;
          _longitude = position.longitude;
          if (!_locationEditedByUser) {
            _locationController.text = await VenueNameService.resolveLabelAtPin(
              _latitude!,
              _longitude!,
            );
          }
        }
      }

      if (_latitude == null ||
          _longitude == null ||
          (_latitude == 0 && _longitude == 0)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Waiting for location…')),
          );
        }
        return;
      }

      final locationName = _locationController.text.trim();
      if (locationName.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter a location name')),
          );
        }
        return;
      }

      final imageFile = await _resolveImageFile();

      final postId = await _feedService.addLocationPost(
        userId: user.uid,
        username: user.displayName ?? user.email?.split('@')[0] ?? 'Anonymous',
        locationName: locationName,
        latitude: _latitude!,
        longitude: _longitude!,
        crowdingLevel: _crowdingLevel,
        imageFile: imageFile,
        description: _buildDescription(),
        waitTime: _waitTime(),
        noiseLevel: _noiseLevel(),
        adultKidRatio: _adultKidRatio(),
        preserveLocationName: _locationEditedByUser,
      );

      final pioneerCount = await FirebaseFirestore.instance
          .collection('location_posts')
          .where('locationName', isEqualTo: locationName)
          .count()
          .get();

      if (mounted) {
        final successArgs = {
          'postId': postId,
          'locationName': locationName,
          'crowdingLevel': _crowdingLevel,
          'fromVenueEntry': _fromVenueEntry,
        };
        if ((pioneerCount.count ?? 0) == 1) {
          Navigator.pushReplacementNamed(
            context,
            '/pioneer_congrat',
            arguments: successArgs,
          );
        } else {
          Navigator.pushReplacementNamed(
            context,
            '/peep_submitted',
            arguments: successArgs,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit post: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Stack(
          children: [
            if (_selectedImage != null)
              Positioned.fill(
                child: Opacity(
                  opacity: 0.22,
                  child: Image.file(_selectedImage!, fit: BoxFit.cover),
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(),
                _buildLocationRow(),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _isLoading ? null : _cycleCrowdingLevel,
                        child: Column(
                          children: [
                            CrowdMeter(level: _crowdingLevel, size: 180),
                            const SizedBox(height: 12),
                            Text(
                              'Tap to set crowd level',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      _buildCriteriaChips(),
                    ],
                  ),
                ),
                _buildPhotoButton(),
                _buildSubmitButton(),
                const SizedBox(height: 16),
              ],
            ),
            if (_isLoading)
              Container(
                color: PeeplAppTokens.textPrimary.withValues(alpha: 0.45),
                child: const Center(
                  child: CircularProgressIndicator(color: PeeplAppTokens.textPrimary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
          const Spacer(),
          const Text(
            'Quick Peep',
            style: TextStyle(
              color: PeeplAppTokens.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 72),
        ],
      ),
    );
  }

  Widget _buildLocationRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: (_isGeolocating || _isResolvingVenueName)
                    ? Text(
                        _isResolvingVenueName
                            ? 'Finding venue name…'
                            : 'Finding your location…',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 15,
                        ),
                      )
                    : TextField(
                        controller: _locationController,
                        enabled: !_isLoading,
                        style: const TextStyle(
                          color: PeeplAppTokens.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: _locationPermissionDenied
                              ? 'Location unavailable'
                              : 'Detecting location…',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 15,
                          ),
                          prefixIcon: Icon(
                            Icons.location_on,
                            color: Colors.white.withValues(alpha: 0.85),
                            size: 20,
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 24,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                          suffixIcon: _locationController.text.isNotEmpty
                              ? Icon(
                                  Icons.edit_outlined,
                                  size: 16,
                                  color: Colors.white.withValues(alpha: 0.5),
                                )
                              : null,
                        ),
                        onChanged: (_) {
                          setState(() => _locationEditedByUser = true);
                        },
                      ),
              ),
              if (!_isGeolocating && !_hasNotificationLocation)
                IconButton(
                  tooltip: 'Refresh location',
                  icon: Icon(
                    Icons.my_location,
                    color: Colors.white.withValues(alpha: 0.75),
                    size: 20,
                  ),
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() => _locationEditedByUser = false);
                          _resolveLocationAndGeocode();
                        },
                ),
            ],
          ),
          if (!_isGeolocating &&
              !_isResolvingVenueName &&
              _locationController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 2),
              child: Text(
                'Wrong place? Tap to edit, or refresh GPS.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCriteriaChips() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _criteria.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final c = _criteria[index];
          final isSet = c.isSet;
          final display = isSet ? '${c.emoji} ${c.value}' : '${c.emoji} ${c.label}';
          return GestureDetector(
            onTap: _isLoading
                ? null
                : () => setState(() => c.cycle()),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSet
                    ? PeeplAppTokens.accentBlue
                    : Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isSet
                      ? PeeplAppTokens.accentBlue
                      : Colors.white.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                display,
                style: TextStyle(
                  color: isSet ? Colors.white : Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                  fontWeight: isSet ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPhotoButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _pickPhotoFromCamera,
        icon: Icon(
          _selectedImage != null ? Icons.check_circle : Icons.camera_alt_outlined,
          color: _selectedImage != null ? Colors.greenAccent : Colors.white70,
        ),
        label: Text(
          _selectedImage != null ? 'Photo added' : 'Add photo (optional)',
          style: TextStyle(
            color: _selectedImage != null ? Colors.greenAccent : Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: _selectedImage != null
                ? Colors.greenAccent.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.35),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _submitPost,
          style: ElevatedButton.styleFrom(
            backgroundColor: PeeplAppTokens.shellNavy,
            foregroundColor: PeeplAppTokens.textPrimary,
            disabledBackgroundColor: PeeplAppTokens.accentBlue.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Peep It!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _QuickCriterion {
  _QuickCriterion({
    required this.emoji,
    required this.label,
    required this.values,
  });

  final String emoji;
  final String label;
  final List<String> values;
  int _index = -1;

  bool get isSet => _index >= 0;
  String? get value => isSet ? values[_index] : null;

  void cycle() {
    if (_index < values.length - 1) {
      _index++;
    } else {
      _index = -1;
    }
  }
}
