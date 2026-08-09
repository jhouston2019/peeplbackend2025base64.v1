import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../theme/peepl_app_tokens.dart';
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

  static const _mapsKey = 'AIzaSyBkJayDy4YBldg0Y5Ux7sR5Qww8am59vV8';

  Future<void> _searchPlaces(String query) async {
    if (query.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final encoded = Uri.encodeComponent(query);
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?address=$encoded&key=$_mapsKey',
      );
      final response = await http.get(url);
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        final results = (data['results'] as List).take(5).map((r) {
          return {
            'name': r['formatted_address'] as String,
            'lat': (r['geometry']['location']['lat'] as num).toDouble(),
            'lng': (r['geometry']['location']['lng'] as num).toDouble(),
          };
        }).toList();
        setState(() =>
            _suggestions = List<Map<String, dynamic>>.from(results));
      } else {
        setState(() => _suggestions = []);
      }
    } catch (_) {
      setState(() => _suggestions = []);
    } finally {
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
        SnackBar(content: Text('Please enter a location')),
      );
      return;
    }

    if (_selectedPlace == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a location from the list')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await CrowdsourceService.instance.createRequest(
        requestedBy: user.uid,
        locationName: locationName,
        latitude: (_selectedPlace!['lat'] as num).toDouble(),
        longitude: (_selectedPlace!['lng'] as num).toDouble(),
        source: 'request_peep_screen',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Request sent! Nearby users will be notified for 1 hour.'),
            backgroundColor: PeeplAppTokens.shellNavy,
            duration: Duration(seconds: 3),
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
          SnackBar(
            content: Text('Failed to send request. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PeeplAppTokens.shellNavy,
      appBar: AppBar(
        backgroundColor: PeeplAppTokens.shellNavy,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: PeeplAppTokens.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Request a Peep',
          style: TextStyle(
              color: PeeplAppTokens.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 16),
              Text(
                'Where do you want a peep?',
                style: TextStyle(
                    color: PeeplAppTokens.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'We\'ll notify anyone nearby to share current conditions.',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.8), fontSize: 15),
              ),
              SizedBox(height: 32),

              // Search field
              Container(
                decoration: BoxDecoration(
                  color: PeeplAppTokens.textPrimary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: PeeplAppTokens.textPrimary.withOpacity(0.1),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _locationController,
                  focusNode: _focusNode,
                  style: TextStyle(fontSize: 16, color: PeeplAppTokens.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search for a place...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon:
                        Icon(Icons.search, color: PeeplAppTokens.accentBlue),
                    suffixIcon: _isSearching
                        ? Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: PeeplAppTokens.accentBlue),
                            ),
                          )
                        : _locationController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear,
                                    color: Colors.grey),
                                onPressed: () {
                                  _locationController.clear();
                                  setState(() {
                                    _suggestions = [];
                                    _selectedPlace = null;
                                  });
                                },
                              )
                            : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                  ),
                  onChanged: (val) {
                    setState(() => _selectedPlace = null);
                    _debounceTimer?.cancel();
                    _debounceTimer = Timer(Duration(milliseconds: 400), () {
                      _searchPlaces(val);
                    });
                  },
                ),
              ),

              // Suggestions
              if (_suggestions.isNotEmpty)
                Container(
                  margin: EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: PeeplAppTokens.textPrimary,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: PeeplAppTokens.textPrimary.withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: _suggestions.map((place) {
                      return ListTile(
                        leading: Icon(Icons.location_on,
                            color: PeeplAppTokens.accentBlue, size: 20),
                        title: Text(
                          place['name'] as String,
                          style: TextStyle(
                              fontSize: 14, color: PeeplAppTokens.textPrimary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _selectPlace(place),
                        dense: true,
                      );
                    }).toList(),
                  ),
                ),

              // Selected place confirmation
              if (_selectedPlace != null && _suggestions.isEmpty)
                Container(
                  margin: EdgeInsets.only(top: 16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle,
                          color: Color(0xFFFFC107), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedPlace!['name'] as String,
                          style: TextStyle(
                              color: PeeplAppTokens.textPrimary, fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

              Spacer(),

              // Notification preview
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.notifications_outlined,
                        color: Colors.white.withOpacity(0.7), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selectedPlace != null
                            ? 'Someone is curious about ${_selectedPlace!['name']}, would you mind sharing a peep?'
                            : 'Someone is curious about [location], would you mind sharing a peep?',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16),

              // Send button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed:
                      _isSubmitting || _selectedPlace == null
                          ? null
                          : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFFC107),
                    foregroundColor: Colors.black,
                    disabledBackgroundColor:
                        Colors.white.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: PeeplAppTokens.textPrimary),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cell_tower, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Send Request',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                ),
              ),
              SizedBox(height: 8),
              Center(
                child: Text(
                  'Notification expires after 1 hour',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12),
                ),
              ),
            ],
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
