import 'package:flutter/material.dart';

class DealsScreen extends StatelessWidget {
  const DealsScreen({super.key});

  static const List<Map<String, String>> _deals = [
    {'merchant': "Lupe's Tacos", 'deal': '20% off lunch', 'expires': 'Until 3pm', 'distance': '0.3 mi'},
    {'merchant': 'Brew & Co', 'deal': 'Buy 1 get 1 coffee', 'expires': '8–10am only', 'distance': '0.5 mi'},
    {'merchant': "Sanford's Junkyard", 'deal': 'Happy Hour drinks', 'expires': '4–7pm', 'distance': '1.1 mi'},
    {'merchant': "Lamont's Lounge", 'deal': 'No cover charge tonight', 'expires': 'Tonight only', 'distance': '1.4 mi'},
    {'merchant': 'Perimeter Eats', 'deal': 'Free dessert with entree', 'expires': 'All day', 'distance': '2.0 mi'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Current Deals',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _deals.length,
        itemBuilder: (context, index) {
          final deal = _deals[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.local_offer, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deal['merchant']!,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        deal['deal']!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${deal['expires']} • ${deal['distance']}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Claim',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
