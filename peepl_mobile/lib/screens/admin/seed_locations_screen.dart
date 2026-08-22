import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/peepl_app_tokens.dart';

const _kUsersCollection = 'CAASNAhaDbPrl0zH1yDn5qRqAtJ3';
const _kAdminUid = 'CAASNAhaDbPrl0zH1yDn5qRqAtJ3';

/// Admin-only screen to seed and inspect Firestore `locations` documents
/// used by [PeeplGeofenceService].
class SeedLocationsScreen extends StatefulWidget {
  const SeedLocationsScreen({super.key});

  @override
  State<SeedLocationsScreen> createState() => _SeedLocationsScreenState();
}

class _SeedLocationsScreenState extends State<SeedLocationsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _radiusController = TextEditingController(text: '150');
  final _venueTypeController = TextEditingController();

  bool _gateResolved = false;
  bool _allowed = false;
  bool _isActive = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkAdminGate();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    _venueTypeController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminGate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      return;
    }

    if (user.uid == _kAdminUid) {
      if (!mounted) return;
      setState(() {
        _allowed = true;
        _gateResolved = true;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection(_kUsersCollection)
          .doc(user.uid)
          .get();
      final isAdmin = doc.data()?['isAdmin'] == true;
      if (!mounted) return;
      if (!isAdmin) {
        Navigator.of(context).pushReplacementNamed('/home');
        return;
      }
      setState(() {
        _allowed = true;
        _gateResolved = true;
      });
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  Future<void> _submitLocation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final radius =
          double.tryParse(_radiusController.text.trim()) ?? 150.0;
      final venueType = _venueTypeController.text.trim();

      final callable = FirebaseFunctions.instance.httpsCallable('seedLocation');
      await callable.call<Map<String, dynamic>>({
        'locationName': _nameController.text.trim(),
        'latitude': double.parse(_latController.text.trim()),
        'longitude': double.parse(_lngController.text.trim()),
        'crowdingLevel': 0,
        'geofenceRadiusMeters': radius,
        'isActive': _isActive,
        if (venueType.isNotEmpty) 'venueType': venueType,
      });

      _nameController.clear();
      _latController.clear();
      _lngController.clear();
      _radiusController.text = '150';
      _venueTypeController.clear();
      if (mounted) setState(() => _isActive = true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location added to geofence registry')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_gateResolved) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_allowed) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: PeeplAppTokens.shellNavy,
      appBar: AppBar(
        backgroundColor: PeeplAppTokens.shellNavy,
        foregroundColor: Colors.white,
        title: const Text('Seed Locations'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFormCard(),
              const SizedBox(height: 24),
              const Text(
                'Existing locations',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildLocationsList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Add geofence location',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Location name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            TextFormField(
              controller: _latController,
              decoration: const InputDecoration(labelText: 'Latitude'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || double.tryParse(v.trim()) == null) {
                  return 'Enter a valid latitude';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _lngController,
              decoration: const InputDecoration(labelText: 'Longitude'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || double.tryParse(v.trim()) == null) {
                  return 'Enter a valid longitude';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _radiusController,
              decoration: const InputDecoration(
                labelText: 'Geofence radius (meters)',
                helperText: 'App registers 150m today; stored for reference',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            TextFormField(
              controller: _venueTypeController,
              decoration: const InputDecoration(
                labelText: 'Venue type (optional)',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _submitting ? null : _submitLocation,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add location'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationsList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('locations').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Failed to load locations: ${snapshot.error}',
            style: const TextStyle(color: Colors.white70),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final aName =
                a.data()['locationName'] as String? ?? a.id;
            final bName =
                b.data()['locationName'] as String? ?? b.id;
            return aName.compareTo(bName);
          });
        if (docs.isEmpty) {
          return const Text(
            'No locations seeded yet. Geofencing will not fire until at least one active location exists.',
            style: TextStyle(color: Colors.white70),
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data();
            final name = data['locationName'] as String? ?? doc.id;
            final lat = data['latitude'];
            final lng = data['longitude'];
            final active = data['isActive'] as bool? ?? true;
            final radius = data['geofenceRadiusMeters'];

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(name),
                subtitle: Text(
                  'ID: ${doc.id}\n'
                  'Lat/Lng: $lat, $lng\n'
                  'Radius: ${radius ?? 150}m · Active: $active',
                ),
                isThreeLine: true,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
