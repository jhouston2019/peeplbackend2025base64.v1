import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/feed_service.dart';

class QuickPeepSheet {
  QuickPeepSheet._();

  static Future<void> show(BuildContext context, {String? venueName}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QuickPeepSheetContent(venueName: venueName),
    );
  }
}

class _QuickPeepSheetContent extends StatefulWidget {
  const _QuickPeepSheetContent({this.venueName});

  final String? venueName;

  @override
  State<_QuickPeepSheetContent> createState() => _QuickPeepSheetContentState();
}

class _QuickPeepSheetContentState extends State<_QuickPeepSheetContent> {
  static const _vibeOptions = [
    'Dead quiet',
    'Moderate',
    'Buzzing',
    'Packed',
  ];

  final _placeController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  double _crowdLevel = 5;
  String? _selectedVibe;
  bool _isLoading = false;
  bool _fieldError = false;

  @override
  void initState() {
    super.initState();
    if (widget.venueName != null && widget.venueName!.isNotEmpty) {
      _placeController.text = widget.venueName!;
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
      await FeedService().addLocationPost(
        userId: user.uid,
        username: user.displayName ?? user.email?.split('@')[0] ?? 'Anonymous',
        locationName: _placeController.text.trim(),
        latitude: 0.0,
        longitude: 0.0,
        crowdingLevel: _crowdLevel.round(),
        imageFile: File(photo.path),
        description: _selectedVibe ?? '',
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final crowdInt = _crowdLevel.round();
    final crowdColor = _getCrowdingColor(crowdInt);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Quick Peep 👁️',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Where are you right now?',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _placeController,
                  decoration: InputDecoration(
                    hintText: 'Type a place name...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _fieldError ? Colors.red : Colors.grey.shade300,
                        width: _fieldError ? 2 : 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _fieldError ? Colors.red : Colors.grey.shade300,
                        width: _fieldError ? 2 : 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _fieldError ? Colors.red : Colors.blue,
                        width: _fieldError ? 2 : 1.5,
                      ),
                    ),
                  ),
                  onChanged: (_) {
                    if (_fieldError) setState(() => _fieldError = false);
                  },
                ),
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
                const SizedBox(height: 16),
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
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitPost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC107),
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
    );
  }
}
