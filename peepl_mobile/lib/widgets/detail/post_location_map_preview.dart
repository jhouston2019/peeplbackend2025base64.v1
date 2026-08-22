import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/peepl_app_tokens.dart';

/// Compact map preview for peep detail screens. Opens the device maps app on tap.
class PostLocationMapPreview extends StatelessWidget {
  const PostLocationMapPreview({
    super.key,
    required this.latitude,
    required this.longitude,
    this.locationName,
    this.height = 96,
    this.width = 96,
    this.fullWidth = false,
  });

  final double latitude;
  final double longitude;
  final String? locationName;
  final double height;
  final double width;
  final bool fullWidth;

  static bool hasValidCoords(Map<String, dynamic> post) {
    final lat = (post['latitude'] as num?)?.toDouble();
    final lng = (post['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return false;
    if (lat == 0 && lng == 0) return false;
    return lat.abs() <= 90 && lng.abs() <= 180;
  }

  static Future<bool> openInMaps(
    BuildContext context,
    double lat,
    double lng, {
    String? label,
  }) async {
    final encodedLabel =
        label != null && label.trim().isNotEmpty ? Uri.encodeComponent(label) : null;
    final geoUri = encodedLabel != null
        ? Uri.parse('geo:$lat,$lng?q=$lat,$lng($encodedLabel)')
        : Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    final webUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    try {
      if (!kIsWeb && await canLaunchUrl(geoUri)) {
        final launched =
            await launchUrl(geoUri, mode: LaunchMode.externalApplication);
        if (launched) return true;
      }
      final launched =
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps app.')),
        );
      }
      return launched;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open maps: $e')),
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(fullWidth ? 12 : 10);

    return GestureDetector(
      onTap: () => openInMaps(
        context,
        latitude,
        longitude,
        label: locationName,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: SizedBox(
          height: height,
          width: fullWidth ? double.infinity : width,
          child: kIsWeb
              ? _buildFallback(context)
              : _GoogleMapWithFallback(
                  latitude: latitude,
                  longitude: longitude,
                  fallback: _buildFallback(context),
                ),
        ),
      ),
    );
  }

  Widget _buildFallback(BuildContext context) {
    return Container(
      color: PeeplAppTokens.shellNavy.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.map_outlined,
            size: fullWidth ? 40 : 28,
            color: PeeplAppTokens.accentBlue,
          ),
          if (fullWidth) ...[
            const SizedBox(height: 8),
            Text(
              'Tap to open in Maps',
              style: TextStyle(
                fontSize: 13,
                color: PeeplAppTokens.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GoogleMapWithFallback extends StatefulWidget {
  const _GoogleMapWithFallback({
    required this.latitude,
    required this.longitude,
    required this.fallback,
  });

  final double latitude;
  final double longitude;
  final Widget fallback;

  @override
  State<_GoogleMapWithFallback> createState() => _GoogleMapWithFallbackState();
}

class _GoogleMapWithFallbackState extends State<_GoogleMapWithFallback> {
  bool _failed = false;

  @override
  Widget build(BuildContext context) {
    if (_failed) return widget.fallback;

    final target = LatLng(widget.latitude, widget.longitude);
    try {
      return GoogleMap(
        key: ValueKey<String>('map_${widget.latitude}_${widget.longitude}'),
        initialCameraPosition: CameraPosition(target: target, zoom: 15),
        markers: {
          Marker(
            markerId: const MarkerId('post_location'),
            position: target,
          ),
        },
        liteModeEnabled: !kIsWeb && Platform.isAndroid,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        myLocationButtonEnabled: false,
        compassEnabled: false,
        scrollGesturesEnabled: false,
        zoomGesturesEnabled: false,
        rotateGesturesEnabled: false,
        tiltGesturesEnabled: false,
        onMapCreated: (_) {},
      );
    } catch (e) {
      debugPrint('[PostLocationMapPreview] GoogleMap error: $e');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _failed = true);
      });
      return widget.fallback;
    }
  }
}
