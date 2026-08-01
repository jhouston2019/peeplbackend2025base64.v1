import 'dart:convert';
import 'dart:io';
import '../theme/peepl_app_tokens.dart';

import '../services/feed_service.dart';
import '../services/notification_service.dart';
import '../widgets/quick_peep_sheet.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

class PostScreen extends StatefulWidget {
  const PostScreen({super.key});

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  static const String _defaultImageUrl =
      'https://images.unsplash.com/photo-1501854140801-50d01698950b?w=800';

  static const List<String> _postTypes = <String>[
    'Review',
    'Tip',
    'Photo',
    'Check-in',
    'Deal Alert',
    'Event',
    'Question',
    'Vibe Check',
  ];

  /// Grouped venue chips; flat list used for validation and visibility logic.
  static const List<(String label, List<String> types)> _venueTypeGroups =
      <(String, List<String>)>[
    (
      'Food & Drink',
      <String>[
        'Restaurant',
        'Bar',
        'Cafe',
        'Food Truck',
        'Brewery',
      ],
    ),
    (
      'Retail',
      <String>[
        'Grocery Store',
        'Mall',
        'Pharmacy',
        'Convenience Store',
      ],
    ),
    (
      'Health',
      <String>[
        'Hospital',
        'Clinic',
        'Gym',
        'Spa',
        'Urgent Care',
      ],
    ),
    (
      'Transport',
      <String>[
        'Airport',
        'Train Station',
        'Bus Terminal',
        'Gas Station',
      ],
    ),
    (
      'Services',
      <String>[
        'Bank',
        'DMV',
        'Courthouse',
        'Post Office',
        'Auto Shop',
      ],
    ),
    (
      'Entertainment',
      <String>[
        'Movie Theater',
        'Concert Venue',
        'Stadium',
        'Museum',
        'Park',
      ],
    ),
    (
      'Community',
      <String>[
        'Church',
        'Library',
        'Community Center',
        'School',
      ],
    ),
    (
      'Other',
      <String>[
        'Hotel',
        'Beach',
        'Event Space',
        'Other',
      ],
    ),
  ];

  static final Set<String> _transportVenueTypes = {
    for (final g in _venueTypeGroups)
      if (g.$1 == 'Transport') ...g.$2,
  };

  static final Set<String> _retailVenueTypes = {
    for (final g in _venueTypeGroups)
      if (g.$1 == 'Retail') ...g.$2,
  };

  /// Venues where “pets present” is shown (outdoor, hospitality, social).
  static const Set<String> _petsRelevantVenueTypes = {
    'Restaurant',
    'Bar',
    'Cafe',
    'Food Truck',
    'Brewery',
    'Park',
    'Beach',
    'Hotel',
    'Event Space',
    'Other',
    'Movie Theater',
    'Concert Venue',
    'Stadium',
    'Museum',
    'Church',
    'Library',
    'Community Center',
    'School',
    'Mall',
  };

  static const List<String> _ageRangeOptions = <String>[
    '18–24',
    '25–35',
    '35–50',
    '50+',
    'Mixed',
  ];

  final _formKey = GlobalKey<FormState>();
  final GlobalKey<FormFieldState<String>> _postTypeFieldKey =
      GlobalKey<FormFieldState<String>>();
  final GlobalKey<FormFieldState<String>> _venueFieldKey =
      GlobalKey<FormFieldState<String>>();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _vibe = TextEditingController();
  final TextEditingController _waitTime = TextEditingController();
  final TextEditingController _demographics = TextEditingController();
  final TextEditingController _dressCode = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final FeedService _feedService = FeedService();

  int _crowdingLevel = 5;
  double _noiseLevel = 5;
  double _staffAvailability = 5;
  bool _hasMusic = false;
  bool _wheelchairAccessible = false;
  bool _strollerFriendly = false;
  bool _hasDeals = false;
  bool _isLoading = false;

  String? _venueType;
  double _malePercent = 50;
  double _adultPercent = 50;
  String? _ageRange;
  bool _hasPets = false;

  double? _latitude;
  double? _longitude;
  bool _locationReady = false;
  bool _isGeolocating = false;
  bool _locationPreFilled = false;
  bool _hasNotificationLocation = false;

  double _kidsPercentage = 0;
  double _femalePercentage = 50;
  String? _criteriaVenueType;
  String? _parking;
  String? _queueTime;
  String? _safetyFeel;
  String? _weather;

  static const List<String> _criteriaVenueTypeOptions = <String>[
    'Restaurant',
    'Bar',
    'Café',
    'Park',
    'Beach',
    'Mall',
    'Museum',
    'Concert/Event',
    'Sports Event',
    'Airport',
    'Gym',
    'Grocery Store',
    'Hotel',
    'Hospital',
    'Club',
    'Other',
  ];

  static const List<String> _parkingOptions = <String>[
    'Easy',
    'Limited',
    'None',
  ];

  static const List<String> _queueOptions = <String>[
    'No Queue',
    'Under 5 min',
    '5-15 min',
    '15-30 min',
    '30+ min',
  ];

  static const List<String> _safetyOptions = <String>[
    'Safe',
    'Neutral',
    'Uncomfortable',
  ];

  static const List<String> _weatherOptions = <String>[
    'Hot',
    'Warm',
    'Cool',
    'Cold',
    'Rainy',
  ];

  bool get _showWeatherChips {
    const outdoor = {'Park', 'Beach', 'Concert/Event', 'Sports Event'};
    return _criteriaVenueType != null && outdoor.contains(_criteriaVenueType);
  }

  File? _selectedImage;
  XFile? _videoFile;
  VideoPlayerController? _videoController;

  bool get _hasVenue => _venueType != null && _venueType!.isNotEmpty;

  bool get _noWaitDressStaffContext =>
      _hasVenue &&
      (_transportVenueTypes.contains(_venueType) ||
          _venueType == 'Park' ||
          _venueType == 'Beach');

  bool get _showWaitTime => _hasVenue && !_noWaitDressStaffContext;

  bool get _showDressCode =>
      _hasVenue &&
      !_noWaitDressStaffContext &&
      !(_retailVenueTypes.contains(_venueType));

  bool get _showStaffAvailability => _hasVenue && !_noWaitDressStaffContext;

  bool get _showDemographics =>
      _hasVenue && !_transportVenueTypes.contains(_venueType);

  bool get _showAgeRange =>
      _hasVenue && !_transportVenueTypes.contains(_venueType);

  bool get _showHasPets =>
      _hasVenue &&
      _petsRelevantVenueTypes.contains(_venueType);

  bool get _showDeals => _hasVenue && !_noWaitDressStaffContext;

  bool get _showStrollerFriendly =>
      _hasVenue && !_transportVenueTypes.contains(_venueType);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_hasNotificationLocation &&
          _latitude != null &&
          _longitude != null) {
        if (mounted) setState(() => _locationReady = true);
        return;
      }
      final acquired = await _acquireLocation();
      if (mounted) {
        setState(() => _locationReady = acquired);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_locationPreFilled) {
      _locationPreFilled = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['locationName'] != null) {
        _hasNotificationLocation = true;
        _locationController.text = args['locationName'] as String;
        final lat = args['latitude'];
        final lng = args['longitude'];
        if (lat is num) _latitude = lat.toDouble();
        if (lng is num) _longitude = lng.toDouble();
        if (_latitude != null && _longitude != null) {
          _locationReady = true;
        }
      }
    }
  }

  Future<String?> _fetchVenueName(double lat, double lng) async {
    const apiKey = 'AIzaSyBkJayDy4YBldg0Y5Ux7sR5Qww8am59vV8';
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
      '?location=$lat,$lng&rankby=distance&type=establishment&key=$apiKey',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          return results.first['name'] as String?;
        }
      }
    } catch (e) {
      print('Places API error: $e');
    }
    return null;
  }

  Future<bool> _acquireLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
      });
      final venueName = await _fetchVenueName(pos.latitude, pos.longitude);
      if (venueName != null && venueName.isNotEmpty) {
        if (mounted) {
          setState(() => _locationController.text = venueName);
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _refreshLocationAndGeocode() async {
    if (!mounted || _hasNotificationLocation) return;
    setState(() => _isGeolocating = true);
    final acquired = await _acquireLocation();
    if (mounted) {
      setState(() {
        _locationReady = acquired;
        _isGeolocating = false;
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _locationController.dispose();
    _vibe.dispose();
    _waitTime.dispose();
    _demographics.dispose();
    _dressCode.dispose();
    super.dispose();
  }

  void _clearPhoto() {
    setState(() => _selectedImage = null);
  }

  Future<void> _clearVideo() async {
    await _videoController?.dispose();
    _videoController = null;
    if (mounted) setState(() => _videoFile = null);
  }

  Future<void> _disposeVideoOnly() async {
    await _videoController?.dispose();
    _videoController = null;
  }

  Future<void> _initVideoPreview(String path) async {
    await _disposeVideoOnly();
    final controller = VideoPlayerController.file(File(path));
    await controller.initialize();
    controller.setLooping(true);
    await controller.play();
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() => _videoController = controller);
  }

  Future<void> _selectImage() async {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: PeeplAppTokens.accentBlue),
              title: Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: PeeplAppTokens.accentBlue),
              title: Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not access image: $e')),
      );
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    final XFile? file = await _imagePicker.pickVideo(source: source);
    if (file == null || !mounted) return;
    setState(() => _videoFile = file);
    await _initVideoPreview(file.path);
  }

  void _showVideoPickerSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Record video'),
              onTap: () {
                Navigator.pop(ctx);
                _pickVideo(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: const Text('Choose video from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickVideo(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _extensionForPath(String path, {required bool isVideo}) {
    final lower = path.toLowerCase();
    if (isVideo) {
      if (lower.endsWith('.mov')) return '.mov';
      if (lower.endsWith('.webm')) return '.webm';
      return '.mp4';
    }
    if (lower.endsWith('.png')) return '.png';
    if (lower.endsWith('.gif')) return '.gif';
    if (lower.endsWith('.webp')) return '.webp';
    return '.jpg';
  }

  Future<void> _submitPost() async {
    if (_latitude == null || _longitude == null) {
      final acquired = await _acquireLocation();
      if (!acquired) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location access is required to post. '
              'Please enable location in Settings and try again.',
            ),
            duration: Duration(seconds: 4),
            backgroundColor: Colors.red[700],
          ),
        );
        return;
      }
      if (mounted) setState(() => _locationReady = true);
    }

    if (_locationController.text.trim().isEmpty || _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please add a location and photo')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final locationName = _locationController.text.trim();
      await _feedService.addLocationPost(
        userId: user.uid,
        username: user.displayName ?? user.email?.split('@')[0] ?? 'Anonymous',
        locationName: locationName,
        latitude: _latitude!,
        longitude: _longitude!,
        crowdingLevel: _crowdingLevel.round(),
        imageFile: _selectedImage!,
        description: _buildDescription(),
        vibe: _vibe.text.trim().isNotEmpty ? _vibe.text.trim() : null,
        waitTime:
            _waitTime.text.trim().isNotEmpty ? _waitTime.text.trim() : null,
        noiseLevel: _noiseLevel.round(),
        hasMusic: _hasMusic,
        demographics: _demographics.text.trim().isNotEmpty
            ? _demographics.text.trim()
            : null,
        dressCode: _dressCode.text.trim().isNotEmpty
            ? _dressCode.text.trim()
            : null,
        wheelchairAccessible: _wheelchairAccessible,
        strollerFriendly: _strollerFriendly,
        hasDeals: _hasDeals,
        staffAvailability: _staffAvailability.round(),
        maleFemaleRatio: _malePercent.round(),
        adultKidRatio: _adultPercent.round(),
        ageRange: _ageRange,
        hasPets: _hasPets,
        venueType: _venueType,
      );

      await NotificationService.instance.onPostSubmitted(
        userId: user.uid,
        username: user.displayName ?? user.email?.split('@')[0] ?? 'Anonymous',
        locationName: locationName,
        latitude: _latitude!,
        longitude: _longitude!,
        crowdingLevel: _crowdingLevel.round(),
      );

      final pioneerCount = await FirebaseFirestore.instance
          .collection('location_posts')
          .where('locationName', isEqualTo: locationName)
          .count()
          .get();

      if (mounted) {
        if ((pioneerCount.count ?? 0) == 1) {
          Navigator.pushReplacementNamed(
            context,
            '/pioneer_congrat',
            arguments: locationName,
          );
        } else {
          Navigator.pushReplacementNamed(
            context,
            '/peep_submitted',
            arguments: locationName,
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit post: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _buildDescription() {
    final parts = <String>[];
    final postType = _postTypeFieldKey.currentState?.value?.trim();
    if (postType != null && postType.isNotEmpty) parts.add(postType);
    if (_venueType != null && _venueType!.isNotEmpty) parts.add(_venueType!);
    final vibe = _vibe.text.trim();
    if (vibe.isNotEmpty) parts.add(vibe);
    parts.add('👶 ${_kidsPercentage.round()}% kids');
    parts.add('👩 ${_femalePercentage.round()}% female');
    if (_criteriaVenueType != null && _criteriaVenueType!.isNotEmpty) {
      parts.add(_criteriaVenueType!);
    }
    if (_parking != null) parts.add('Parking: $_parking');
    if (_queueTime != null) parts.add('Queue: $_queueTime');
    if (_safetyFeel != null) parts.add('Safety: $_safetyFeel');
    if (_weather != null) parts.add('Weather: $_weather');
    return parts.join(' · ');
  }

  Color _getCrowdingColor(int level) {
    if (level <= 4) return const Color(0xFF4CAF50);
    if (level <= 6) return const Color(0xFFFFA726);
    return const Color(0xFFFF5722);
  }

  String _getCrowdingLabel(int level) {
    if (level <= 3) return 'Not Crowded';
    if (level <= 5) return 'Moderate';
    if (level <= 7) return 'Quite Busy';
    return 'Very Crowded';
  }

  /// Photo row: shows "Add photo" button when empty; 80 px inline preview
  /// with overlay, "✓ Photo selected" label, "✎ Change" and "✕" badges
  /// when a file is selected.
  Widget _buildPhotoRow() {
    if (_selectedImage == null) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isLoading ? null : _selectImage,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: const Text('Add photo'),
          style: OutlinedButton.styleFrom(
            foregroundColor: PeeplAppTokens.accentBlue,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      );
    }

    return Stack(
      children: [
        // 80 px full-width image
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 80,
            width: double.infinity,
            child: Image.file(_selectedImage!, fit: BoxFit.cover),
          ),
        ),
        // Dark overlay
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: const ColoredBox(color: Color(0x66000000)),
          ),
        ),
        // Centre label
        const Positioned.fill(
          child: Center(
            child: Text(
              '✓ Photo selected',
              style: TextStyle(
                color: PeeplAppTokens.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                shadows: [Shadow(blurRadius: 4, color: PeeplAppTokens.textPrimary)],
              ),
            ),
          ),
        ),
        // "✎ Change" badge — bottom right
        Positioned(
          bottom: 7,
          right: 7,
          child: GestureDetector(
            onTap: _isLoading ? null : _selectImage,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, size: 11, color: PeeplAppTokens.accentBlue),
                  SizedBox(width: 3),
                  Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: PeeplAppTokens.accentBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // "✕" remove badge — top right
        Positioned(
          top: 6,
          right: 7,
          child: GestureDetector(
            onTap: _isLoading ? null : _clearPhoto,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: PeeplAppTokens.textPrimary.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: PeeplAppTokens.textPrimary, size: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoPreview() {
    if (_videoFile == null) return const SizedBox.shrink();
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const CircularProgressIndicator(),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: VideoPlayer(controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PeeplAppTokens.shellNavy,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: Container(
                decoration: PeeplAppTokens.shellBodyDecoration(),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        _buildQuickPeepBanner(),
                        const SizedBox(height: 24),
                        FormField<String>(
                          key: _venueFieldKey,
                          validator: (_) => !_hasVenue
                              ? 'Please select a venue type'
                              : null,
                          builder: (field) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Venue type *'),
                                const SizedBox(height: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (var i = 0;
                                        i < _venueTypeGroups.length;
                                        i++) ...[
                                      if (i > 0) const SizedBox(height: 12),
                                      Text(
                                        _venueTypeGroups[i].$1,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: PeeplAppTokens.textSecondary,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: _venueTypeGroups[i].$2.map((t) {
                                          final sel = _venueType == t;
                                          return FilterChip(
                                            label: Text(t),
                                            selected: sel,
                                            selectedColor: PeeplAppTokens.accentBlue
                                                .withValues(alpha: 0.25),
                                            checkmarkColor:
                                                PeeplAppTokens.accentBlue,
                                            onSelected: _isLoading
                                                ? null
                                                : (on) {
                                                    setState(() {
                                                      _venueType = on ? t : null;
                                                    });
                                                    field.didChange(_venueType);
                                                  },
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ],
                                ),
                                if (field.errorText != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      field.errorText!,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        _buildLabel('Post type *'),
                        const SizedBox(height: 8),
                        FormField<String>(
                          key: _postTypeFieldKey,
                          initialValue: null,
                          validator: (v) => v == null || v.isEmpty
                              ? 'Please select a post type'
                              : null,
                          builder: (field) {
                            return InputDecorator(
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                errorText: field.errorText,
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: field.value,
                                  hint: const Text('Select post type'),
                                  items: _postTypes
                                      .map(
                                        (t) => DropdownMenuItem<String>(
                                          value: t,
                                          child: Text(t),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) => field.didChange(v),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        _buildLabel('Location Name *'),
                        _buildLocationField(),
                        const SizedBox(height: 24),
                        _buildLabel('How Crowded Is It?'),
                        const SizedBox(height: 8),
                        _buildCrowdingSlider(),
                        if (_hasVenue) ...[
                          const SizedBox(height: 24),
                          _buildMaleFemaleRatioSlider(),
                          const SizedBox(height: 20),
                          _buildAdultKidRatioSlider(),
                          if (_showAgeRange) ...[
                            const SizedBox(height: 20),
                            _buildLabel('👤 Age Range'),
                            const SizedBox(height: 8),
                            _buildAgeRangeChips(),
                          ],
                          if (_showHasPets) ...[
                            const SizedBox(height: 8),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Pets present'),
                              value: _hasPets,
                              onChanged: _isLoading
                                  ? null
                                  : (v) => setState(() => _hasPets = v),
                            ),
                          ],
                          const SizedBox(height: 16),
                          _buildLabel('Vibe'),
                          _buildTextField(
                            controller: _vibe,
                            hint: 'e.g. Cozy, Trendy, Casual',
                          ),
                          if (_showWaitTime) ...[
                            const SizedBox(height: 24),
                            _buildLabel('Wait time'),
                            _buildTextField(
                              controller: _waitTime,
                              hint: 'e.g. No wait, 5–10m, 30m+',
                            ),
                          ],
                          const SizedBox(height: 24),
                          _buildLabel('Noise level'),
                          const SizedBox(height: 8),
                          _buildLevelSlider(
                            value: _noiseLevel,
                            onChanged: (v) => setState(() => _noiseLevel = v),
                          ),
                          const SizedBox(height: 24),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Music playing'),
                            value: _hasMusic,
                            onChanged: _isLoading
                                ? null
                                : (v) => setState(() => _hasMusic = v),
                          ),
                          if (_showDemographics) ...[
                            const SizedBox(height: 8),
                            _buildLabel('Crowd / demographics'),
                            _buildTextField(
                              controller: _demographics,
                              hint: 'e.g. Locals, Tourists, Young',
                            ),
                          ],
                          if (_showDressCode) ...[
                            const SizedBox(height: 24),
                            _buildLabel('Dress code'),
                            _buildTextField(
                              controller: _dressCode,
                              hint: 'e.g. Casual, Smart casual',
                            ),
                          ],
                          const SizedBox(height: 24),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Wheelchair accessible'),
                            value: _wheelchairAccessible,
                            onChanged: _isLoading
                                ? null
                                : (v) =>
                                    setState(() => _wheelchairAccessible = v),
                          ),
                          if (_showStrollerFriendly)
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Stroller friendly'),
                              value: _strollerFriendly,
                              onChanged: _isLoading
                                  ? null
                                  : (v) =>
                                      setState(() => _strollerFriendly = v),
                            ),
                          if (_showDeals)
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Has deals'),
                              value: _hasDeals,
                              onChanged: _isLoading
                                  ? null
                                  : (v) => setState(() => _hasDeals = v),
                            ),
                          if (_showStaffAvailability) ...[
                            const SizedBox(height: 16),
                            _buildLabel('Staff availability'),
                            const SizedBox(height: 8),
                            _buildLevelSlider(
                              value: _staffAvailability,
                              onChanged: (v) =>
                                  setState(() => _staffAvailability = v),
                            ),
                          ],
                        ],
                        const SizedBox(height: 24),
                        _buildLabel('Photo (required)'),
                        const SizedBox(height: 8),
                        _buildPhotoRow(),
                        const SizedBox(height: 20),
                        _buildLabel('Video (optional)'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isLoading
                                    ? null
                                    : _showVideoPickerSheet,
                                icon: const Icon(Icons.videocam_outlined),
                                label: const Text('Add video'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: PeeplAppTokens.accentBlue,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                            if (_videoFile != null) ...[
                              const SizedBox(width: 12),
                              IconButton.filledTonal(
                                onPressed: _isLoading ? null : _clearVideo,
                                icon: const Icon(Icons.close),
                                tooltip: 'Remove video',
                              ),
                            ],
                          ],
                        ),
                        if (_videoFile != null) ...[
                          const SizedBox(height: 16),
                          _buildVideoPreview(),
                        ],
                        const SizedBox(height: 24),
                        _buildCrowdCompositionCard(),
                        _buildVenueDetailsCard(),
                        _buildConditionsCard(),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitPost,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: PeeplAppTokens.shellNavy,
                              foregroundColor: PeeplAppTokens.textPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: PeeplAppTokens.textPrimary,
                                  )
                                : const Text(
                                    'Post Update',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickPeepBanner() {
    return Material(
      color: PeeplAppTokens.shellNavy,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _isLoading
            ? null
            : () {
                final args = <String, dynamic>{};
                final name = _locationController.text.trim();
                if (name.isNotEmpty) args['locationName'] = name;
                if (_latitude != null) args['latitude'] = _latitude;
                if (_longitude != null) args['longitude'] = _longitude;
                Navigator.pushNamed(
                  context,
                  '/create_peep',
                  arguments: args.isEmpty ? null : args,
                );
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.flash_on, color: PeeplAppTokens.textPrimary),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Peep',
                      style: TextStyle(
                        color: PeeplAppTokens.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Fast crowd report — tap level and go',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: PeeplAppTokens.textPrimary, size: 28),
          ),
          const SizedBox(width: 16),
          const Text(
            'Post Update',
            style: TextStyle(
              color: PeeplAppTokens.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              QuickPeepSheet.show(context);
            },
            child: const Text(
              'Quick Mode',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: PeeplAppTokens.accentBlue,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border.all(color: PeeplAppTokens.cardElevated!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildLocationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            border: Border.all(color: PeeplAppTokens.cardElevated!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextFormField(
            controller: _locationController,
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Please enter a location name'
                : null,
            decoration: InputDecoration(
              hintText: 'e.g. Central Park, Hyde Park',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              prefixIcon: _isGeolocating
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              suffixIconConstraints: const BoxConstraints(
                minHeight: 48,
                minWidth: 48,
              ),
              suffixIcon: IconButton(
                tooltip: 'Use current location',
                icon: const Icon(Icons.location_pin),
                onPressed:
                    (_isGeolocating || _isLoading || _hasNotificationLocation)
                        ? null
                        : _refreshLocationAndGeocode,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (_locationReady)
          Row(
            children: [
              Icon(Icons.gps_fixed, size: 12, color: Colors.green[700]),
              Text(
                ' Location acquired',
                style: TextStyle(fontSize: 11, color: Colors.green[700]),
              ),
            ],
          )
        else
          Row(
            children: [
              Icon(Icons.gps_off, size: 12, color: Colors.orange[700]),
              Text(
                ' Acquiring location...',
                style: TextStyle(fontSize: 11, color: Colors.orange[700]),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildMaleFemaleRatioSlider() {
    final m = _malePercent.round().clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildLabel('Male / female mix'),
            Text(
              'M/F: $m/${100 - m}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: PeeplAppTokens.textSecondary,
              ),
            ),
          ],
        ),
        Slider(
          value: _malePercent.clamp(0, 100),
          min: 0,
          max: 100,
          divisions: 20,
          label: 'M/F: $m/${100 - m}',
          onChanged: _isLoading
              ? null
              : (v) => setState(() => _malePercent = v),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'More female',
              style: TextStyle(fontSize: 12, color: PeeplAppTokens.textSecondary),
            ),
            Text(
              'More male',
              style: TextStyle(fontSize: 12, color: PeeplAppTokens.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdultKidRatioSlider() {
    final a = _adultPercent.round().clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildLabel('Adults / kids mix'),
            Text(
              'A/K: $a/${100 - a}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: PeeplAppTokens.textSecondary,
              ),
            ),
          ],
        ),
        Slider(
          value: _adultPercent.clamp(0, 100),
          min: 0,
          max: 100,
          divisions: 20,
          label: 'A/K: $a/${100 - a}',
          onChanged: _isLoading
              ? null
              : (v) => setState(() => _adultPercent = v),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'More kids',
              style: TextStyle(fontSize: 12, color: PeeplAppTokens.textSecondary),
            ),
            Text(
              'More adults',
              style: TextStyle(fontSize: 12, color: PeeplAppTokens.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  /// Radio-style chip row for age range. Tapping a selected chip deselects it.
  Widget _buildAgeRangeChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _ageRangeOptions.map((option) {
        final selected = _ageRange == option;
        return GestureDetector(
          onTap: _isLoading
              ? null
              : () => setState(
                    () => _ageRange = selected ? null : option,
                  ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? PeeplAppTokens.accentBlue
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? PeeplAppTokens.accentBlue
                    : Colors.grey.shade300,
                width: 1.5,
              ),
            ),
            child: Text(
              option,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.normal,
                color: selected
                    ? Colors.white
                    : Colors.grey.shade700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCrowdingSlider() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _getCrowdingLabel(_crowdingLevel),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _getCrowdingColor(_crowdingLevel),
              ),
            ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getCrowdingColor(_crowdingLevel),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _crowdingLevel.toString(),
                  style: const TextStyle(
                    color: PeeplAppTokens.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: _crowdingLevel.toDouble(),
          min: 1,
          max: 10,
          divisions: 9,
          activeColor: _getCrowdingColor(_crowdingLevel),
          label: _crowdingLevel.toString(),
          onChanged: (val) => setState(() => _crowdingLevel = val.round()),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '1\nEmpty',
              style: TextStyle(fontSize: 12, color: PeeplAppTokens.textSecondary),
              textAlign: TextAlign.center,
            ),
            Text(
              '10\nPacked',
              style: TextStyle(fontSize: 12, color: PeeplAppTokens.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLevelSlider({
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${value.round()}/10',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: PeeplAppTokens.textSecondary,
          ),
        ),
        Slider(
          value: value,
          min: 1,
          max: 10,
          divisions: 9,
          label: value.round().toString(),
          onChanged: _isLoading ? null : onChanged,
        ),
      ],
    );
  }

  Widget _buildCompactCard({
    required String emoji,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: PeeplAppTokens.cardElevated!),
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[50],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$emoji $title',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: PeeplAppTokens.accentBlue,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSingleSelectChips({
    required List<String> options,
    required String? selected,
    required ValueChanged<String?> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = selected == option;
        return GestureDetector(
          onTap: _isLoading
              ? null
              : () => onSelected(isSelected ? null : option),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? PeeplAppTokens.accentBlue
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? PeeplAppTokens.accentBlue
                    : Colors.grey.shade300,
                width: 1.5,
              ),
            ),
            child: Text(
              option,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPercentageSlider({
    required String emoji,
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    final pct = value.round().clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$emoji $label',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: PeeplAppTokens.accentBlue,
              ),
            ),
            Text(
              '$pct%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: PeeplAppTokens.textSecondary,
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(0, 100),
          min: 0,
          max: 100,
          divisions: 20,
          label: '$pct%',
          onChanged: _isLoading ? null : onChanged,
        ),
      ],
    );
  }

  Widget _buildCrowdCompositionCard() {
    return _buildCompactCard(
      emoji: '👥',
      title: 'Crowd Composition',
      children: [
        _buildPercentageSlider(
          emoji: '👶',
          label: '% Kids',
          value: _kidsPercentage,
          onChanged: (v) => setState(() => _kidsPercentage = v),
        ),
        const SizedBox(height: 8),
        _buildPercentageSlider(
          emoji: '👩',
          label: '% Female',
          value: _femalePercentage,
          onChanged: (v) => setState(() => _femalePercentage = v),
        ),
      ],
    );
  }

  Widget _buildVenueDetailsCard() {
    return _buildCompactCard(
      emoji: '📍',
      title: 'Venue Details',
      children: [
        const Text(
          'Venue type',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: PeeplAppTokens.accentBlue,
          ),
        ),
        const SizedBox(height: 8),
        _buildSingleSelectChips(
          options: _criteriaVenueTypeOptions,
          selected: _criteriaVenueType,
          onSelected: (v) => setState(() {
            _criteriaVenueType = v;
            const outdoor = {
              'Park',
              'Beach',
              'Concert/Event',
              'Sports Event',
            };
            if (v == null || !outdoor.contains(v)) _weather = null;
          }),
        ),
        const SizedBox(height: 16),
        const Text(
          '🅿️ Parking',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: PeeplAppTokens.accentBlue,
          ),
        ),
        const SizedBox(height: 8),
        _buildSingleSelectChips(
          options: _parkingOptions,
          selected: _parking,
          onSelected: (v) => setState(() => _parking = v),
        ),
        const SizedBox(height: 16),
        const Text(
          '⏱️ Queue / Wait',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: PeeplAppTokens.accentBlue,
          ),
        ),
        const SizedBox(height: 8),
        _buildSingleSelectChips(
          options: _queueOptions,
          selected: _queueTime,
          onSelected: (v) => setState(() => _queueTime = v),
        ),
      ],
    );
  }

  Widget _buildConditionsCard() {
    return _buildCompactCard(
      emoji: '🌡️',
      title: 'Conditions',
      children: [
        const Text(
          '🛡️ Safety feel',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: PeeplAppTokens.accentBlue,
          ),
        ),
        const SizedBox(height: 8),
        _buildSingleSelectChips(
          options: _safetyOptions,
          selected: _safetyFeel,
          onSelected: (v) => setState(() => _safetyFeel = v),
        ),
        if (_showWeatherChips) ...[
          const SizedBox(height: 16),
          const Text(
            '🌤️ Weather',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: PeeplAppTokens.accentBlue,
            ),
          ),
          const SizedBox(height: 8),
          _buildSingleSelectChips(
            options: _weatherOptions,
            selected: _weather,
            onSelected: (v) => setState(() => _weather = v),
          ),
        ],
      ],
    );
  }
}
