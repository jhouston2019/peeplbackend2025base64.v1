import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
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

  final _formKey = GlobalKey<FormState>();
  final GlobalKey<FormFieldState<String>> _postTypeFieldKey =
      GlobalKey<FormFieldState<String>>();
  final TextEditingController _locationName = TextEditingController();
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

  XFile? _pickedFile;
  bool _pickedIsVideo = false;
  VideoPlayerController? _videoController;

  @override
  void dispose() {
    _videoController?.dispose();
    _locationName.dispose();
    _vibe.dispose();
    _waitTime.dispose();
    _demographics.dispose();
    _dressCode.dispose();
    super.dispose();
  }

  void _clearPickedMedia() {
    _videoController?.dispose();
    _videoController = null;
    setState(() {
      _pickedFile = null;
      _pickedIsVideo = false;
    });
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
    await _disposeVideoOnly();
    setState(() {
      _pickedFile = file;
      _pickedIsVideo = false;
    });
  }

  Future<void> _pickVideo(ImageSource source) async {
    final XFile? file = await _picker.pickVideo(source: source);
    if (file == null || !mounted) return;
    setState(() {
      _pickedFile = file;
      _pickedIsVideo = true;
    });
    await _initVideoPreview(file.path);
  }

  void _showMediaPickerSheet() {
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

  String _extensionForUpload() {
    if (_pickedFile == null) return '.jpg';
    final path = _pickedFile!.path;
    final lower = path.toLowerCase();
    if (_pickedIsVideo) {
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    setState(() => _isLoading = true);
    try {
      String imageUrl = _defaultImageUrl;
      String? videoUrl;

      if (_pickedFile != null) {
        final file = File(_pickedFile!.path);
        if (!await file.exists()) {
          throw Exception('Selected file is no longer available.');
        }
        final ts = DateTime.now().millisecondsSinceEpoch;
        final ext = _extensionForUpload();
        final ref = FirebaseStorage.instance
            .ref('posts/${user.uid}/$ts$ext');
        await ref.putFile(file);
        final url = await ref.getDownloadURL();
        if (_pickedIsVideo) {
          videoUrl = url;
          imageUrl = _defaultImageUrl;
        } else {
          imageUrl = url;
        }
      }

      final Map<String, dynamic> data = {
        'userId': user.uid,
        'username': user.displayName ??
            user.email?.split('@').first ??
            'Anonymous',
        'locationName': _locationName.text.trim(),
        'latitude': 0.0,
        'longitude': 0.0,
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
      };
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

  Widget _buildMediaPreview() {
    if (_pickedFile == null) return const SizedBox.shrink();
    if (_pickedIsVideo) {
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        File(_pickedFile!.path),
        fit: BoxFit.cover,
        height: 220,
        width: double.infinity,
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
                        _buildTextField(
                          controller: _locationName,
                          hint: 'e.g. Central Park, Hyde Park',
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Please enter a location name'
                              : null,
                        ),
                        const SizedBox(height: 24),
                        _buildLabel('How Crowded Is It?'),
                        const SizedBox(height: 8),
                        _buildCrowdingSlider(),
                        const SizedBox(height: 24),
                        _buildLabel('Vibe'),
                        _buildTextField(
                          controller: _vibe,
                          hint: 'e.g. Cozy, Trendy, Casual',
                        ),
                        const SizedBox(height: 24),
                        _buildLabel('Wait time'),
                        _buildTextField(
                          controller: _waitTime,
                          hint: 'e.g. No wait, 5–10m, 30m+',
                        ),
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
                        const SizedBox(height: 8),
                        _buildLabel('Crowd / demographics'),
                        _buildTextField(
                          controller: _demographics,
                          hint: 'e.g. Locals, Tourists, Young',
                        ),
                        const SizedBox(height: 24),
                        _buildLabel('Dress code'),
                        _buildTextField(
                          controller: _dressCode,
                          hint: 'e.g. Casual, Smart casual',
                        ),
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
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Stroller friendly'),
                          value: _strollerFriendly,
                          onChanged: _isLoading
                              ? null
                              : (v) => setState(() => _strollerFriendly = v),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Has deals'),
                          value: _hasDeals,
                          onChanged: _isLoading
                              ? null
                              : (v) => setState(() => _hasDeals = v),
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Staff availability'),
                        const SizedBox(height: 8),
                        _buildLevelSlider(
                          value: _staffAvailability,
                          onChanged: (v) =>
                              setState(() => _staffAvailability = v),
                        ),
                        const SizedBox(height: 24),
                        _buildLabel('Photo or video (optional)'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isLoading
                                    ? null
                                    : _showMediaPickerSheet,
                                icon: const Icon(Icons.add_a_photo_outlined),
                                label: const Text('Add media'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF1565C0),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                            if (_pickedFile != null) ...[
                              const SizedBox(width: 12),
                              IconButton.filledTonal(
                                onPressed:
                                    _isLoading ? null : _clearPickedMedia,
                                icon: const Icon(Icons.close),
                                tooltip: 'Remove media',
                              ),
                            ],
                          ],
                        ),
                        if (_pickedFile != null) ...[
                          const SizedBox(height: 16),
                          _buildMediaPreview(),
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
