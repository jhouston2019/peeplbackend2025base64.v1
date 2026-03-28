import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PostScreen extends StatefulWidget {
  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _locationName = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _imageUrl = TextEditingController();
  int _crowdingLevel = 5;
  bool _isLoading = false;

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final imageUrl = _imageUrl.text.trim().isEmpty
          ? 'https://images.unsplash.com/photo-1501854140801-50d01698950b?w=800'
          : _imageUrl.text.trim();
      await FirebaseFirestore.instance.collection('location_posts').add({
        'userId': user.uid,
        'username': user.displayName ??
            user.email?.split('@').first ??
            'Anonymous',
        'locationName': _locationName.text.trim(),
        'latitude': 0.0,
        'longitude': 0.0,
        'crowdingLevel': _crowdingLevel,
        'imageUrl': imageUrl,
        'description': _description.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'likesCount': 0,
        'commentsCount': 0,
        'isVerified': false,
      });
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
                        _buildLabel('Description'),
                        _buildTextField(
                          controller: _description,
                          hint: "What's happening here?",
                          maxLines: 3,
                        ),
                        const SizedBox(height: 24),
                        _buildLabel('Image URL (optional)'),
                        _buildTextField(
                          controller: _imageUrl,
                          hint: 'https://...',
                          keyboardType: TextInputType.url,
                        ),
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
                                    color: Colors.white)
                                : const Text(
                                    'Post Update',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600),
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
                fontWeight: FontWeight.bold),
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
          color: Color(0xFF1565C0)),
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  color: _getCrowdingColor(_crowdingLevel)),
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
                      fontWeight: FontWeight.bold),
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
            Text('1\nEmpty',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center),
            Text('10\nPacked',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _locationName.dispose();
    _description.dispose();
    _imageUrl.dispose();
    super.dispose();
  }
}
