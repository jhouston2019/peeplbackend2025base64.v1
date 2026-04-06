import 'package:flutter/material.dart';

class PeepDetailScreen extends StatelessWidget {
  const PeepDetailScreen({super.key});

  Color _crowdColor(int level) {
    if (level <= 3) return const Color(0xFF2E7D32);
    if (level <= 6) return const Color(0xFFE65100);
    return const Color(0xFFC62828);
  }

  String _relativeTime(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime? dt;
    if (timestamp is DateTime) {
      dt = timestamp;
    } else {
      try {
        // Firestore Timestamp exposes .toDate()
        dt = (timestamp as dynamic).toDate() as DateTime;
      } catch (_) {
        return '';
      }
    }
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final post = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (post == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          title: const Text('Post'),
        ),
        body: const Center(child: Text('Post not found')),
      );
    }

    final locationName = post['locationName'] as String? ?? 'Unknown';
    final username = post['username'] as String? ?? 'Anonymous';
    final crowdLevel = (post['crowdingLevel'] as num?)?.toInt() ?? 0;
    final imageUrl = post['imageUrl'] as String? ?? '';
    final vibeTag = post['vibeTag'] as String?;
    final waitTime = post['waitTime'] as String?;
    final mfRatio = post['mfRatio'] as String?;
    final akRatio = post['akRatio'] as String?;
    final ageRange = post['ageRange'] as String?;
    final timeStr = _relativeTime(post['timestamp']);

    final crowdColor = _crowdColor(crowdLevel);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        title: Text(locationName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image
            if (imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),

            // Crowd + meta card
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location name + crowd indicator
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            locationName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1565C0),
                            ),
                          ),
                        ),
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: crowdColor.withValues(alpha: 0.15),
                            border: Border.all(color: crowdColor, width: 2.5),
                          ),
                          child: Center(
                            child: Text(
                              '$crowdLevel',
                              style: TextStyle(
                                color: crowdColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Crowd level',
                      style: TextStyle(
                          fontSize: 12,
                          color: crowdColor,
                          fontWeight: FontWeight.w600),
                    ),
                    const Divider(height: 24),

                    // Posted by + time
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFF1565C0),
                          child: Text(
                            username.isNotEmpty
                                ? username[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(username,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15)),
                        ),
                        if (timeStr.isNotEmpty)
                          Text(timeStr,
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Extra fields card
            if ([vibeTag, waitTime, mfRatio, akRatio, ageRange]
                .any((v) => v != null && v.isNotEmpty))
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Details',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF1565C0))),
                      const SizedBox(height: 10),
                      if (vibeTag != null && vibeTag.isNotEmpty)
                        _detailRow(Icons.local_bar, 'Vibe', vibeTag),
                      if (waitTime != null && waitTime.isNotEmpty)
                        _detailRow(Icons.schedule, 'Wait time', waitTime),
                      if (mfRatio != null && mfRatio.isNotEmpty)
                        _detailRow(Icons.people, 'M/F ratio', mfRatio),
                      if (akRatio != null && akRatio.isNotEmpty)
                        _detailRow(Icons.group, 'A/K ratio', akRatio),
                      if (ageRange != null && ageRange.isNotEmpty)
                        _detailRow(Icons.cake, 'Age range', ageRange),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1565C0)),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 14, color: Colors.black87))),
        ],
      ),
    );
  }
}
