import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:geocoding/geocoding.dart';
import '../widgets/home/peepl_home_background.dart';
import '../widgets/home/peepl_home_tokens.dart';
import '../services/crowdsource_service.dart';

class RequestPeepScreen extends StatefulWidget {
  const RequestPeepScreen({Key? key}) : super(key: key);

  @override
  State<RequestPeepScreen> createState() => _RequestPeepScreenState();
}

class _RequestPeepScreenState extends State<RequestPeepScreen> {
  final TextEditingController _locationController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Map<String, dynamic>> _suggestions = [];
  Map<String, dynamic>? _selectedPlace;
  bool _isSearching = false;
  bool _isSubmitting = false;
  Timer? _debounceTimer;

  Future<void> _searchPlaces(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _isSearching = true);

    final results = <Map<String, dynamic>>[];
    final seen = <String>{};

    void addResult(String name, double lat, double lng) {
      final key = name.toLowerCase();
      if (seen.contains(key)) return;
      seen.add(key);
      results.add({'name': name, 'lat': lat, 'lng': lng});
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('locations')
          .limit(200)
          .get();
      final q = trimmed.toLowerCase();
      for (final doc in snap.docs) {
        final data = doc.data();
        final name = data['locationName'] as String? ?? '';
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();
        if (name.isEmpty || lat == null || lng == null) continue;
        if (name.toLowerCase().contains(q)) {
          addResult(name, lat, lng);
        }
      }
    } catch (_) {}

    if (results.length < 5) {
      try {
        final locations = await locationFromAddress(trimmed);
        if (locations.isNotEmpty) {
          final loc = locations.first;
          addResult(trimmed, loc.latitude, loc.longitude);
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() => _suggestions = results.take(5).toList());
      setState(() => _isSearching = false);
    }
  }

  void _selectPlace(Map<String, dynamic> place) {
    setState(() {
      _selectedPlace = place;
      _locationController.text = place['name'] as String;
      _suggestions = [];
    });
    _focusNode.unfocus();
  }

  Future<void> _submitRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final locationName = _locationController.text.trim();
    if (locationName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a location')),
      );
      return;
    }

    if (_selectedPlace == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location from the list')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final result = await CrowdsourceService.instance.createRequestAndAwaitDelivery(
        requestedBy: user.uid,
        locationName: locationName,
        latitude: (_selectedPlace!['lat'] as num).toDouble(),
        longitude: (_selectedPlace!['lng'] as num).toDouble(),
        source: 'request_peep_screen',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.userMessage),
            backgroundColor: result.delivered
                ? PeeplHomeTokens.shellNavy
                : Colors.orange.shade800,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
      }
    } on ArgumentError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Please enter a valid location')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send request. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  InputDecoration _fieldDecoration({
    required String hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: PeeplHomeTokens.headerMuted.withValues(alpha: 0.8)),
      prefixIcon: Icon(Icons.search, color: PeeplHomeTokens.brandBlue),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: PeeplHomeTokens.chipSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: PeeplHomeTokens.chipBorderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: PeeplHomeTokens.chipBorderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PeeplHomeTokens.brandBlue, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PeeplHomeBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: PeeplHomeTokens.headerForeground,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Request a Peep',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: PeeplHomeTokens.headerForeground,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Where do you want a peep?',
                  style: TextStyle(
                    color: PeeplHomeTokens.headerForeground,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'We\'ll notify anyone nearby to share current conditions.',
                  style: TextStyle(
                    color: PeeplHomeTokens.headerMuted,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _locationController,
                  focusNode: _focusNode,
                  style: const TextStyle(
                    fontSize: 16,
                    color: PeeplHomeTokens.headerForeground,
                  ),
                  decoration: _fieldDecoration(
                    hint: 'Search for a place...',
                    suffixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: PeeplHomeTokens.brandBlue,
                              ),
                            ),
                          )
                        : _locationController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: PeeplHomeTokens.headerMuted,
                                ),
                                onPressed: () {
                                  _locationController.clear();
                                  setState(() {
                                    _suggestions = [];
                                    _selectedPlace = null;
                                  });
                                },
                              )
                            : null,
                  ),
                  onChanged: (val) {
                    setState(() => _selectedPlace = null);
                    _debounceTimer?.cancel();
                    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
                      _searchPlaces(val);
                    });
                  },
                ),
                if (_suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: PeeplHomeTokens.chipSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: PeeplHomeTokens.chipBorderLight),
                    ),
                    child: Column(
                      children: _suggestions.map((place) {
                        return ListTile(
                          leading: const Icon(
                            Icons.location_on,
                            color: PeeplHomeTokens.brandBlue,
                            size: 20,
                          ),
                          title: Text(
                            place['name'] as String,
                            style: const TextStyle(
                              fontSize: 14,
                              color: PeeplHomeTokens.headerForeground,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _selectPlace(place),
                          dense: true,
                        );
                      }).toList(),
                    ),
                  ),
                if (_selectedPlace != null && _suggestions.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: PeeplHomeTokens.chipSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: PeeplHomeTokens.chipBorderLight),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: PeeplHomeTokens.dealsYellow,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedPlace!['name'] as String,
                            style: const TextStyle(
                              color: PeeplHomeTokens.headerForeground,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: PeeplHomeTokens.chipSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: PeeplHomeTokens.chipBorderLight),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_outlined,
                        color: PeeplHomeTokens.headerMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedPlace != null
                              ? 'Someone is curious about ${_selectedPlace!['name']}, would you mind sharing a peep?'
                              : 'Someone is curious about [location], would you mind sharing a peep?',
                          style: TextStyle(
                            color: PeeplHomeTokens.headerMuted,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isSubmitting || _selectedPlace == null
                        ? null
                        : _submitRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PeeplHomeTokens.actionGreen,
                      foregroundColor: PeeplHomeTokens.dealsForeground,
                      disabledBackgroundColor:
                          PeeplHomeTokens.headerMuted.withValues(alpha: 0.25),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: PeeplHomeTokens.dealsForeground,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cell_tower, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Send Request',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Notification expires after 1 hour',
                    style: TextStyle(
                      color: PeeplHomeTokens.headerMuted.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _locationController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
