import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
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
    'Teens',
    '20s',
    '30s',
    '40s',
    '50+',
    '20s-30s',
    '30s-40s',
    'Mixed',
    'All ages',
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
  final ImagePicker _picker = ImagePicker();

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
  bool _isGeolocating = false;

  XFile? _photoFile;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveLocationAndGeocode();
    });
  }

  /// Reverse-geocode [placemark] into a short place label for the location field.
  static String _formatPlacemark(Placemark p) {
    final street = p.street?.trim();
    final subLocal = p.subLocality?.trim();
    final line1 = <String>[
      if (street != null && street.isNotEmpty) street,
      if (subLocal != null && subLocal.isNotEmpty) subLocal,
    ].join(', ');
    final locality = p.locality?.trim();
    final admin = p.administrativeArea?.trim();
    final line2 = <String>[
      if (locality != null && locality.isNotEmpty) locality,
      if (admin != null && admin.isNotEmpty) admin,
    ].join(', ');
    if (line1.isNotEmpty && line2.isNotEmpty) return '$line1, $line2';
    if (line1.isNotEmpty) return line1;
    if (line2.isNotEmpty) return line2;
    final name = p.name?.trim();
    if (name != null && name.isNotEmpty) return name;
    return '';
  }

  Future<void> _resolveLocationAndGeocode() async {
    if (!mounted) return;
    setState(() => _isGeolocating = true);
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Turn on location services to detect your place.'),
            ),
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is needed to fill your place.'),
            ),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      if (!mounted) return;
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
      });

      final placemarks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (!mounted) return;
      if (placemarks.isNotEmpty) {
        final label = _formatPlacemark(placemarks.first);
        if (label.isNotEmpty) {
          _locationController.text = label;
        }
      }
    } catch (e, st) {
      debugPrint('Geolocation/geocoding failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not detect location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeolocating = false);
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
    setState(() => _photoFile = null);
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

  Future<void> _pickImage(ImageSource source) async {
    final XFile? file = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;
    setState(() => _photoFile = file);
  }

  Future<void> _pickVideo(ImageSource source) async {
    final XFile? file = await _picker.pickVideo(source: source);
    if (file == null || !mounted) return;
    setState(() => _videoFile = file);
    await _initVideoPreview(file.path);
  }

  void _showPhotoPickerSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose photo from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
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
    if (!_formKey.currentState!.validate()) return;
    if (_photoFile == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a photo before posting')),
      );
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    setState(() => _isLoading = true);
    try {
      String imageUrl = _defaultImageUrl;
      String? videoUrl;

      final photoPath = _photoFile!.path;
      final photoDisk = File(photoPath);
      if (!await photoDisk.exists()) {
        throw Exception('Selected photo is no longer available.');
      }
      final tsBase = DateTime.now().millisecondsSinceEpoch;
      final photoExt = _extensionForPath(photoPath, isVideo: false);
      final photoRef = FirebaseStorage.instance
          .ref('posts/${user.uid}/${tsBase}_photo$photoExt');
      await photoRef.putFile(photoDisk);
      imageUrl = await photoRef.getDownloadURL();

      if (_videoFile != null) {
        final videoPath = _videoFile!.path;
        final videoDisk = File(videoPath);
        if (!await videoDisk.exists()) {
          throw Exception('Selected video is no longer available.');
        }
        final videoExt = _extensionForPath(videoPath, isVideo: true);
        final videoRef = FirebaseStorage.instance
            .ref('posts/${user.uid}/${tsBase}_video$videoExt');
        await videoRef.putFile(videoDisk);
        videoUrl = await videoRef.getDownloadURL();
      }

      final Map<String, dynamic> data = {
        'userId': user.uid,
        'username': user.displayName ??
            user.email?.split('@').first ??
            'Anonymous',
        'locationName': _locationController.text.trim(),
        'latitude': _latitude ?? 0.0,
        'longitude': _longitude ?? 0.0,
        'crowdingLevel': _crowdingLevel,
        'imageUrl': imageUrl,
        'post_type': _postTypeFieldKey.currentState?.value,
        'timestamp': FieldValue.serverTimestamp(),
        'likesCount': 0,
        'commentsCount': 0,
        'isVerified': false,
        'hasMusic': _hasMusic,
        'wheelchairAccessible': _wheelchairAccessible,
        'strollerFriendly': _strollerFriendly,
        'hasDeals': _hasDeals,
        'noiseLevel': _noiseLevel.round(),
        'staffAvailability': _staffAvailability.round(),
        'maleFemaleRatio': _malePercent.round().clamp(0, 100),
        'adultKidRatio': _adultPercent.round().clamp(0, 100),
        'hasPets': _hasPets,
        'venueType': _venueType,
      };
      final ar = _ageRange?.trim();
      if (ar != null && ar.isNotEmpty) {
        data['ageRange'] = ar;
      }
      final vibeText = _vibe.text.trim();
      if (vibeText.isNotEmpty) data['vibe'] = vibeText;
      final waitText = _waitTime.text.trim();
      if (waitText.isNotEmpty) data['waitTime'] = waitText;
      final demoText = _demographics.text.trim();
      if (demoText.isNotEmpty) data['demographics'] = demoText;
      final dressText = _dressCode.text.trim();
      if (dressText.isNotEmpty) data['dressCode'] = dressText;
      if (videoUrl != null) {
        data['videoUrl'] = videoUrl;
      }

      await FirebaseFirestore.instance.collection('location_posts').add(data);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

  Widget _buildPhotoPreview() {
    if (_photoFile == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        File(_photoFile!.path),
        fit: BoxFit.cover,
        height: 220,
        width: double.infinity,
      ),
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
      backgroundColor: const Color(0xFF1565C0),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
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
                                          color: Colors.grey[600],
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
                                            selectedColor: const Color(0xFF1565C0)
                                                .withValues(alpha: 0.25),
                                            checkmarkColor:
                                                const Color(0xFF1565C0),
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
                            _buildLabel('Age range (optional)'),
                            const SizedBox(height: 8),
                            _buildAgeRangeDropdown(),
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
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isLoading
                                    ? null
                                    : _showPhotoPickerSheet,
                                icon: const Icon(Icons.add_a_photo_outlined),
                                label: const Text('Add photo'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF1565C0),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                            if (_photoFile != null) ...[
                              const SizedBox(width: 12),
                              IconButton.filledTonal(
                                onPressed: _isLoading ? null : _clearPhoto,
                                icon: const Icon(Icons.close),
                                tooltip: 'Remove photo',
                              ),
                            ],
                          ],
                        ),
                        if (_photoFile != null) ...[
                          const SizedBox(height: 16),
                          _buildPhotoPreview(),
                        ],
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
                                  foregroundColor: const Color(0xFF1565C0),
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
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitPost,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1565C0),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
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

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          const Text(
            'Post Update',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
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
        color: Color(0xFF1565C0),
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
        border: Border.all(color: Colors.grey[300]!),
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
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
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
          suffixIconConstraints: const BoxConstraints(
            minHeight: 48,
            minWidth: 88,
          ),
          suffixIcon: Padding(
            padding: const EdgeInsetsDirectional.only(end: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isGeolocating)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                IconButton(
                  tooltip: 'Use current location',
                  icon: const Icon(Icons.location_pin),
                  onPressed: (_isGeolocating || _isLoading)
                      ? null
                      : _resolveLocationAndGeocode,
                ),
              ],
            ),
          ),
        ),
      ),
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
                color: Colors.grey[800],
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
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              'More male',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                color: Colors.grey[800],
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
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              'More adults',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAgeRangeDropdown() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          hint: const Text('Optional'),
          value: _ageRange,
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('— None —'),
            ),
            ..._ageRangeOptions.map(
              (e) => DropdownMenuItem<String?>(value: e, child: Text(e)),
            ),
          ],
          onChanged: _isLoading
              ? null
              : (v) => setState(() => _ageRange = v),
        ),
      ),
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
                    color: Colors.white,
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
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            Text(
              '10\nPacked',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
            color: Colors.grey[800],
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
}
